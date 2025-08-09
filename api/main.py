import ctypes
import pathlib
import json
import sys
import threading
from fastapi import FastAPI, Body
from pydantic import BaseModel, Field
from typing import Literal, Union

# --- Paso 1: Encontrar y cargar la biblioteca compartida C++ ---

def find_library_path():
    """Encuentra la ruta a la biblioteca C++ compilada (.dll o .so)."""
    lib_name = "simulator.dll" if sys.platform == "win32" else "libsimulator.so"
    
    # Buscar en las carpetas de compilación comunes relativas a este script
    script_dir = pathlib.Path(__file__).parent.resolve()
    root_dir = script_dir.parent # Sube un nivel desde /api a la raíz del proyecto
    
    search_paths = [
        # Rutas de compilación comunes para Visual Studio y otros generadores
        root_dir / "build" / "core" / "Debug",
        root_dir / "build" / "core" / "Release",
        root_dir / "build" / "Debug", # Si el target está en la raíz de build
        root_dir / "build" / "Release",
    ]
    
    for path in search_paths:
        lib_path = path / lib_name
        if lib_path.exists():
            print(f"Biblioteca encontrada en: {lib_path}")
            return lib_path
            
    raise FileNotFoundError(f"No se pudo encontrar '{lib_name}' en las rutas de búsqueda: {search_paths}")

# Cargar la biblioteca
try:
    lib_path = find_library_path()
    core_lib = ctypes.CDLL(str(lib_path))
except FileNotFoundError as e:
    print(f"ERROR: {e}", file=sys.stderr)
    print("Asegúrate de haber compilado el núcleo C++ primero.", file=sys.stderr)
    sys.exit(1)

# --- Paso 2: Definir las estructuras de datos C++ en Python ---

# Replicas de las estructuras Signal<T> y DatapathState de C++
class Signal_u32(ctypes.Structure):
    _fields_ = [("value", ctypes.c_uint32), ("ready_at", ctypes.c_uint32), ("is_active", ctypes.c_bool)]

class Signal_u16(ctypes.Structure):
    _fields_ = [("value", ctypes.c_uint16), ("ready_at", ctypes.c_uint32), ("is_active", ctypes.c_bool)]

class Signal_u8(ctypes.Structure):
    _fields_ = [("value", ctypes.c_ubyte), ("ready_at", ctypes.c_uint32), ("is_active", ctypes.c_bool)]

class Signal_bool(ctypes.Structure):
    _fields_ = [("value", ctypes.c_bool), ("ready_at", ctypes.c_uint32), ("is_active", ctypes.c_bool)]

class DatapathState(ctypes.Structure):
    _fields_ = [
        ("PC", Signal_u32),
        ("Instr", Signal_u32),
        ("Opcode", Signal_u8),
        ("funct3", Signal_u8),
        ("funct7", Signal_u8),
        ("DA", Signal_u8),
        ("DB", Signal_u8),
        ("DC", Signal_u8),
        ("A", Signal_u32),
        ("B", Signal_u32),
        ("imm", Signal_u32),
        ("immExt", Signal_u32),
        ("ALU_A", Signal_u32),
        ("ALU_B", Signal_u32),
        ("ALU_result", Signal_u32),
        ("ALU_zero", Signal_bool),
        ("Control", Signal_u16),
        ("PCsrc", Signal_u8),
        # --- Campos que faltaban ---
        ("Mem_address", Signal_u32),
        ("Mem_write_data", Signal_u32),
        ("Mem_read_data", Signal_u32),

        ("C", Signal_u32),
        ("PC_plus4", Signal_u32),
        ("PC_dest", Signal_u32),
        ("PC_next", Signal_u32),
        ("branch_taken", Signal_bool),
        ("criticaltime", ctypes.c_uint32),
        ("instruction", ctypes.c_wchar_p),
        ("instruction_cptr", ctypes.c_char * 256), # Usar un buffer de tamaño fijo para evitar punteros colgantes
    ]

# --- Paso 3: Definir los prototipos de las funciones C ---

core_lib.Simulator_new.argtypes = [ctypes.c_size_t, ctypes.c_int]
core_lib.Simulator_new.restype = ctypes.c_void_p

core_lib.Simulator_delete.argtypes = [ctypes.c_void_p]
core_lib.Simulator_delete.restype = None

core_lib.Simulator_load_program.argtypes = [ctypes.c_void_p, ctypes.POINTER(ctypes.c_uint8), ctypes.c_size_t]
core_lib.Simulator_load_program.restype = None

core_lib.Simulator_step.argtypes = [ctypes.c_void_p]
core_lib.Simulator_step.restype = ctypes.c_char_p

core_lib.Simulator_reset.argtypes = [ctypes.c_void_p]
core_lib.Simulator_reset.restype = ctypes.c_char_p

core_lib.Simulator_get_pc.argtypes = [ctypes.c_void_p]
core_lib.Simulator_get_pc.restype = ctypes.c_uint32

core_lib.Simulator_get_status_register.argtypes = [ctypes.c_void_p]
core_lib.Simulator_get_status_register.restype = ctypes.c_uint32

core_lib.Simulator_get_all_registers.argtypes = [ctypes.c_void_p, ctypes.POINTER(ctypes.c_uint32)]
core_lib.Simulator_get_all_registers.restype = None

core_lib.Simulator_get_datapath_state.argtypes = [ctypes.c_void_p]
core_lib.Simulator_get_datapath_state.restype = DatapathState

# --- Paso 4: Crear una clase Python que envuelva la lógica C++ ---

class Simulator:
    """Wrapper de Python para el simulador C++."""
    def __init__(self, mem_size: int = 1024 * 1024, model: int = 0):
        # model: 3=General, 0=SingleCycle, etc. Ver Simulator.h
        self.obj = core_lib.Simulator_new(mem_size, model)
        if not self.obj:
            raise MemoryError("No se pudo crear el objeto Simulator en C++.")

    def load_program(self, program: bytes):
        prog_array = (ctypes.c_uint8 * len(program))(*program)
        core_lib.Simulator_load_program(self.obj, prog_array, len(program))

    def step(self):
        print("Llamando al step de la dll...")
        return core_lib.Simulator_step(self.obj).decode('utf-8')

    def reset(self):
        print("Llamando al reset de la dll...")
        return core_lib.Simulator_reset(self.obj).decode('utf-8')

    def get_pc(self) -> int:
        return core_lib.Simulator_get_pc(self.obj)

    def get_status_register(self) -> int:
        return core_lib.Simulator_get_status_register(self.obj)
    

    def get_registers(self) -> list[int]:
        reg_array = (ctypes.c_uint32 * 32)()
        core_lib.Simulator_get_all_registers(self.obj, reg_array)
        return list(reg_array)
    
    def get_datapath_state(self) -> DatapathState:
        print("Llamando al get_datapath_state de la dll...")
        return core_lib.Simulator_get_datapath_state(self.obj)

    def __del__(self):
        if hasattr(self, 'obj') and self.obj:
            core_lib.Simulator_delete(self.obj)

# --- Paso 5: Crear la aplicación FastAPI ---

app = FastAPI(title="RISC-V Simulator API")
from fastapi.middleware.cors import CORSMiddleware

# --- Lock para proteger el acceso concurrente al simulador ---
# FastAPI maneja las peticiones en hilos separados. Como solo tenemos una
# instancia del simulador, debemos protegerla para evitar condiciones de carrera.
simulator_lock = threading.Lock()

# --- Configuración de CORS ---
# Esto es CRUCIAL para que las aplicaciones web (como Flutter Web)
# que se ejecutan en un origen diferente (ej. localhost:5000)
# puedan comunicarse con esta API (ej. localhost:8000).
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Permite todos los orígenes (ideal para desarrollo)
    allow_credentials=True,
    allow_methods=["*"],  # Permite todos los métodos (GET, POST, etc.)
    allow_headers=["*"],  # Permite todas las cabeceras
)


# --- Modelos de Pydantic para la respuesta de la API ---
# Usar modelos de Pydantic mejora la validación, documentación (Swagger/OpenAPI) y claridad del código.

class SignalModel(BaseModel):
    value: Union[str, bool, int] = Field(..., description="Valor de la señal, formateado si es numérico.")
    ready_at: int = Field(..., description="Ciclo de reloj en el que la señal está lista.")
    is_active: bool = Field(..., description="Indica si la señal está activa en el ciclo actual.")

class ControlSignalsModel(BaseModel):
    ALUctr: int
    ResSrc: int
    ImmSrc: int
    PCsrc: int
    BRwr: bool
    ALUsrc: bool
    MemWr: bool
    ready_at: int
    is_active: bool

class SimulatorStateModel(BaseModel):
    model: str = Field(..., description="Modelo de pipeline actual (ej. 'SingleCycle').")
    pc: int = Field(..., description="Contador de programa actual (en hexadecimal).")
    instruction: str = Field(..., description="Instrucción actual desensamblada.")
    status_register: int = Field(..., description="Registro de estado (ej. 'mstatus').")
    critical_time: int = Field(..., description="Ruta crítica en nanosegundos para el ciclo actual.")
    criticaltime: int = Field(..., description="Ruta crítica en nanosegundos para el ciclo actual.")
    control_signals: ControlSignalsModel = Field(..., description="Señales de control generadas.")
    registers: dict[str, int] = Field(..., description="Estado de los 32 registros generales (con nombres ABI).")
    datapath: dict[str, SignalModel] = Field(..., description="Estado de todas las señales del datapath.")

# --- Constantes ---
ABI_NAMES = [
    "zero", "ra", "sp", "gp", "tp", "t0", "t1", "t2", "s0", "s1", "a0",
    "a1", "a2", "a3", "a4", "a5", "a6", "a7", "s2", "s3", "s4", "s5",
    "s6", "s7", "s8", "s9", "s10", "s11", "t3", "t4", "t5", "t6"
]

# --- Funciones de ayuda para la API ---

def _get_full_state_data(sim: Simulator, model_name: str) -> SimulatorStateModel:
    """Construye y devuelve el estado completo actual del simulador."""
    print("Construyendo estado completo...")
    pc = sim.get_pc()
    status = sim.get_status_register()
    registers = sim.get_registers()
    datapath_c_struct = sim.get_datapath_state()
    instruction_string = datapath_c_struct.instruction_cptr.decode('utf-8').strip('\x00')
    critical_time = datapath_c_struct.criticaltime
    criticaltime = datapath_c_struct.criticaltime

    reg_map = {f"x{i} ({ABI_NAMES[i]})": val for i, val in enumerate(registers)}

    # --- Conversión de estructuras C a modelos Pydantic ---
    # Decodificar las señales de control desde el entero de 16 bits.
    # NOTA: El orden y tamaño de los bits es una suposición.
    # Se debe ajustar para que coincida con la implementación C++.
    # Suposición (de LSB a MSB):
    # [0]    MemWr  (1 bit)
    # [1]    ALUsrc (1 bit)
    # [2]    BRwr   (1 bit)
    # [4:3]  PCsrc  (2 bits)
    # [6:5]  ImmSrc (2 bits)
    # [8:7]  ResSrc (2 bits)
    # [12:9] ALUctr (4 bits)
    control_signal = datapath_c_struct.Control
    control_value = control_signal.value

    control_signals_model = ControlSignalsModel(
        ALUctr=(control_value >> 13) & 0x7,
        ResSrc=(control_value >> 11) & 0x3,
        ImmSrc=(control_value >> 8) & 0x7,
        PCsrc=(control_value >> 6) & 0x3,
        BRwr=bool((control_value >> 5) & 0x1),
        ALUsrc=bool((control_value >> 4) & 0x1),
        MemWr=bool((control_value >> 3) & 0x1),
        ready_at=control_signal.ready_at,
        is_active=control_signal.is_active
    )

    datapath_model = {}
    signal_types = (Signal_u32, Signal_u16, Signal_u8, Signal_bool)

    for field_name, field_type in datapath_c_struct._fields_:
        if not issubclass(field_type, signal_types):
            continue

        signal = getattr(datapath_c_struct, field_name)
        #   value = signal.value

        # if isinstance(value, int) and not isinstance(value, bool):
        #     formatted_value = f"0x{value:08x}"
        # else:
        #     formatted_value = value

        datapath_model[field_name] = SignalModel(
            # value=formatted_value,
            value=signal.value,
            ready_at=signal.ready_at,
            is_active=signal.is_active
        )

    return SimulatorStateModel(
        model=model_name,
        # pc=f"0x{pc:08x}",
        pc = pc,
        instruction=instruction_string,
        # status_register=f"0x{status:08x}",
        status_register = status,
        critical_time=critical_time,
        criticaltime=critical_time,
        control_signals=control_signals_model,
        registers=reg_map,
        datapath=datapath_model
    )

@app.get("/state", response_model=SimulatorStateModel, summary="Obtener el estado actual del simulador")
def get_state_endpoint() -> SimulatorStateModel:
    with simulator_lock:
        sim = simulator_instance["sim"]
        model_name = simulator_instance["model_name"]
        return _get_full_state_data(sim, model_name)

# Creamos una instancia global del simulador dentro de un diccionario
# para que pueda ser reemplazada por los endpoints.
simulator_instance = {"sim": Simulator(model=3), "model_name": "General"} # General por defecto

# Cargamos un programa de prueba más completo, similar al de la UI de Flutter.
# Este programa calcula la suma de los números del 1 al 9.
# El resultado (45) se almacena en el registro x5.
#
# main:
#   addi x5, x0, 0      # sum = 0
#   addi x6, x0, 9      # i = 9
#   addi x7, x0, 0      # limit = 0
# loop:
#   add x5, x5, x6      # sum = sum + i
#   addi x6, x6, -1     # i = i - 1
#   bne x6, x7, loop    # if i != 0, go to loop
# end:
#   j end               # infinite loop
program_bytes = bytes([
    0x93, 0x02, 0x00, 0x00,  # addi x5, x0, 0
    0x13, 0x03, 0x90, 0x00,  # addi x6, x0, 9
    0x93, 0x03, 0x00, 0x00,  # addi x7, x0, 0
    0xb3, 0x82, 0x62, 0x00,  # loop: add x5, x5, x6
    0x13, 0x03, 0xf3, 0xff,  # addi x6, x6, -1
    0xe3, 0x1c, 0x73, 0xfe,  # bne x6, x7, loop
    0x6f, 0x00, 0x00, 0x00,  # end: j end
])
simulator_instance["sim"].load_program(program_bytes)

# Modelo para la petición de reset
class ResetConfig(BaseModel):
    model: Literal['SingleCycle','MultiCycle','PipeLined','General'] = 'SingleCycle'
    load_test_program: bool = True

@app.post("/reset", response_model=SimulatorStateModel, summary="Reinicia el simulador a un estado inicial")
def reset_simulator(config: ResetConfig = ResetConfig()) -> SimulatorStateModel:
    """
    Reinicia el simulador. Permite cambiar el modelo de pipeline.
    - **model**: 'SingleCycle' (didáctico), 'MultiCycle', 'PipeLined', 'General'.
    - **load_test_program**: Si es true, carga el programa de prueba inicial.
    """
    with simulator_lock:
        model_map = {'SingleCycle': 0,'MultiCycle': 1,'PipeLined': 2, 'General': 3, }
        model_id = model_map[config.model]
        print("Llamando a Simulator_reset...")

        # Al reemplazar la instancia, el __del__ del objeto antiguo se llama, liberando la memoria C++.
        simulator_instance["sim"] = Simulator(model=model_id)
        simulator_instance["model_name"] = config.model
        print("Creada nueva instancia del simulador...")
        
        if config.load_test_program:
            simulator_instance["sim"].load_program(program_bytes)
            print("Cargado programa por defecto...")
            
        # Ejecuta el primer paso para tener un estado inicial y luego lo devuelve completo
        simulator_instance["sim"].reset()
        sim = simulator_instance["sim"]
        model_name = simulator_instance["model_name"]
        print("Ejecutado reset (incluye step)...")
        return _get_full_state_data(sim, model_name)

@app.get("/step", response_model=SimulatorStateModel, summary="Ejecutar un ciclo de instrucción")
def execute_step() -> SimulatorStateModel:
    """Ejecuta un paso y devuelve el nuevo estado de los registros."""
    with simulator_lock:
        simulator_instance["sim"].step()
        sim = simulator_instance["sim"]
        model_name = simulator_instance["model_name"]
        return _get_full_state_data(sim, model_name)