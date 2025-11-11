import ctypes
import pathlib
import base64
import json
import sys
import threading
import uuid
from fastapi import FastAPI, Body, Response, HTTPException, Query
from pydantic import BaseModel, Field
from typing import Literal, Union, List, Dict

# --- Paso 1: Encontrar y cargar la biblioteca compartida C++ ---

def find_library_path():
    """Encuentra la ruta a la biblioteca C++ compilada (.dll o .so)."""
    isWindows=sys.platform == "win32"
    if isWindows:
        lib_name = "simulator.dll"
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
    else:
        return "/usr/local/lib/libsimulator.so"

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
    _fields_ = [("value", ctypes.c_uint32), ("ready_at", ctypes.c_uint32), ("is_active", ctypes.c_ubyte)]

class Signal_u16(ctypes.Structure):
    _fields_ = [("value", ctypes.c_uint16), ("ready_at", ctypes.c_uint32), ("is_active", ctypes.c_ubyte)]

class Signal_u8(ctypes.Structure):
    _fields_ = [("value", ctypes.c_ubyte), ("ready_at", ctypes.c_uint32), ("is_active", ctypes.c_ubyte)]

class Signal_bool(ctypes.Structure):
    _fields_ = [("value", ctypes.c_ubyte), ("ready_at", ctypes.c_uint32), ("is_active", ctypes.c_ubyte)]


# El orden debe coincidir exactamente con el orden de los campos en la estructura C++
class DatapathState(ctypes.Structure):
    _fields_ = [
        ("PC", Signal_u32),
        ("Instr", Signal_u32),
        ("opcode", Signal_u8),
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
        ("ALUsrc", Signal_u8),
        ("ResSrc", Signal_u8),
        ("ALUctr", Signal_u8),
        ("ImmSrc", Signal_u8),
        ("BRwr", Signal_u8),
        ("MemWr", Signal_u8),
        ("Mem_address", Signal_u32),
        ("Mem_write_data", Signal_u32),
        ("Mem_read_data", Signal_u32),
        ("C", Signal_u32),
        ("PC_plus4", Signal_u32),
        ("PC_dest", Signal_u32),
        ("PC_next", Signal_u32),
        ("branch_taken", Signal_bool),
        ("criticalTime", ctypes.c_uint32),
        ("totalMicroCycles", ctypes.c_uint32),
        # ("instruction", ctypes.c_wchar_p),
        ("instruction_cptr", ctypes.c_char * 256), # Usar un buffer de tamaño fijo para evitar punteros colgantes
        ("Pipe_IF_instruction_cptr", ctypes.c_char * 256),
        ("Pipe_ID_instruction_cptr", ctypes.c_char * 256),
        ("Pipe_EX_instruction_cptr", ctypes.c_char * 256),
        ("Pipe_MEM_instruction_cptr", ctypes.c_char * 256),
        ("Pipe_WB_instruction_cptr", ctypes.c_char * 256),
        ("Pipe_IF_instruction", ctypes.c_uint32),
        ("Pipe_ID_instruction", ctypes.c_uint32),
        ("Pipe_EX_instruction", ctypes.c_uint32),
        ("Pipe_MEM_instruction", ctypes.c_uint32),
        ("Pipe_WB_instruction", ctypes.c_uint32),
        # --- Pipeline Registers (EL ORDEN DEBE SER IDÉNTICO A Api.cpp) ---
        ("Pipe_IF_ID_NPC", Signal_u32),
        ("Pipe_IF_ID_NPC_out", Signal_u32),
        ("Pipe_IF_ID_Instr", Signal_u32),
        ("Pipe_IF_ID_Instr_out", Signal_u32),
        ("Pipe_IF_ID_PC", Signal_u32),
        ("Pipe_IF_ID_PC_out", Signal_u32),

        ("Pipe_ID_EX_Control", Signal_u16),
        ("Pipe_ID_EX_Control_out", Signal_u16),
        ("Pipe_ID_EX_NPC", Signal_u32),
        ("Pipe_ID_EX_NPC_out", Signal_u32),
        ("Pipe_ID_EX_A", Signal_u32),
        ("Pipe_ID_EX_A_out", Signal_u32),
        ("Pipe_ID_EX_B", Signal_u32),
        ("Pipe_ID_EX_B_out", Signal_u32),
        ("Pipe_ID_EX_RD", Signal_u8),
        ("Pipe_ID_EX_RD_out", Signal_u8),
        ("Pipe_ID_EX_RS1", Signal_u8),
        ("Pipe_ID_EX_RS1_out", Signal_u8),
        ("Pipe_ID_EX_RS2", Signal_u8),
        ("Pipe_ID_EX_RS2_out", Signal_u8),
        ("Pipe_ID_EX_Imm", Signal_u32),
        ("Pipe_ID_EX_Imm_out", Signal_u32),
        ("Pipe_ID_EX_PC", Signal_u32),
        ("Pipe_ID_EX_PC_out", Signal_u32),

        ("Pipe_EX_MEM_Control", Signal_u16),
        ("Pipe_EX_MEM_Control_out", Signal_u16),
        ("Pipe_EX_MEM_NPC", Signal_u32),
        ("Pipe_EX_MEM_NPC_out", Signal_u32),
        ("Pipe_EX_MEM_ALU_result", Signal_u32),
        ("Pipe_EX_MEM_ALU_result_out", Signal_u32),
        ("Pipe_EX_MEM_B", Signal_u32),
        ("Pipe_EX_MEM_B_out", Signal_u32),
        ("Pipe_EX_MEM_RD", Signal_u8),
        ("Pipe_EX_MEM_RD_out", Signal_u8),

        
        ("Pipe_MEM_WB_Control", Signal_u16),
        ("Pipe_MEM_WB_Control_out", Signal_u16),
        ("Pipe_MEM_WB_NPC", Signal_u32),
        ("Pipe_MEM_WB_NPC_out", Signal_u32),
        ("Pipe_MEM_WB_ALU_result", Signal_u32),
        ("Pipe_MEM_WB_ALU_result_out", Signal_u32),
        ("Pipe_MEM_WB_RM", Signal_u32),
        ("Pipe_MEM_WB_RM_out", Signal_u32),
        ("Pipe_MEM_WB_RD", Signal_u8),
        ("Pipe_MEM_WB_RD_out", Signal_u8),

        # --- Señales de Riesgo ---
        ("bus_stall", Signal_bool),
        ("bus_flush", Signal_bool),
        # --- Señales para Cortocircuitos (Forwarding) --- (EL ORDEN IMPORTA)
        ("bus_ControlForwardA", Signal_u8),
        ("bus_ControlForwardB", Signal_u8),
        ("bus_ControlForwardM", Signal_u8),
        ("bus_ForwardA", Signal_u32),
        ("bus_ForwardB", Signal_u32),
        ("bus_ForwardM", Signal_u32),
    ]

# --- Paso 3: Definir los prototipos de las funciones C ---

core_lib.Simulator_new.argtypes = [ctypes.c_size_t, ctypes.c_int]
core_lib.Simulator_new.restype = ctypes.c_void_p

core_lib.Simulator_delete.argtypes = [ctypes.c_void_p]
core_lib.Simulator_delete.restype = None

core_lib.Simulator_load_program.argtypes = [ctypes.c_void_p, ctypes.POINTER(ctypes.c_uint8), ctypes.c_size_t, ctypes.c_int]
core_lib.Simulator_load_program.restype = None

core_lib.Simulator_load_program_from_assembly.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_int]
core_lib.Simulator_load_program_from_assembly.restype = None

core_lib.Simulator_assemble.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.POINTER(ctypes.c_uint8), ctypes.c_size_t]
core_lib.Simulator_assemble.restype = ctypes.c_size_t

core_lib.Simulator_step.argtypes = [ctypes.c_void_p]
core_lib.Simulator_step.restype = ctypes.c_char_p


core_lib.Simulator_step_back.argtypes = [ctypes.c_void_p]
core_lib.Simulator_step_back.restype = ctypes.c_char_p

core_lib.Simulator_steps_until.argtypes = [ctypes.c_void_p, ctypes.POINTER(ctypes.c_uint32), ctypes.c_size_t]
core_lib.Simulator_steps_until.restype = ctypes.c_char_p

core_lib.Simulator_reset_with_model.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_uint]
core_lib.Simulator_reset_with_model.restype = ctypes.c_char_p

core_lib.Simulator_set_hazard_options.argtypes = [ctypes.c_void_p, ctypes.c_bool, ctypes.c_bool, ctypes.c_bool]
core_lib.Simulator_set_hazard_options.restype = None

core_lib.Simulator_get_pc.argtypes = [ctypes.c_void_p]
core_lib.Simulator_get_pc.restype = ctypes.c_uint32

core_lib.Simulator_get_status_register.argtypes = [ctypes.c_void_p]
core_lib.Simulator_get_status_register.restype = ctypes.c_uint32

core_lib.Simulator_get_all_registers.argtypes = [ctypes.c_void_p, ctypes.POINTER(ctypes.c_uint32)]
core_lib.Simulator_get_all_registers.restype = None

core_lib.Simulator_get_datapath_state.argtypes = [ctypes.c_void_p]
core_lib.Simulator_get_datapath_state.restype = DatapathState

core_lib.Simulator_get_d_mem.argtypes = [ctypes.c_void_p, ctypes.POINTER(ctypes.c_uint8), ctypes.c_size_t]
core_lib.Simulator_get_d_mem.restype = None

# Nueva estructura para la memoria de instrucciones
class InstructionEntry(ctypes.Structure):
    _fields_ = [
        ("value", ctypes.c_uint32),
        ("instruction", ctypes.c_char * 256)
    ]

core_lib.Simulator_get_i_mem.argtypes = [ctypes.c_void_p, ctypes.POINTER(InstructionEntry), ctypes.c_size_t]
core_lib.Simulator_get_i_mem.restype = ctypes.c_size_t


# --- Paso 4: Crear una clase Python que envuelva la lógica C++ ---

class Simulator:
    """Wrapper de Python para el simulador C++."""
    def __init__(self, mem_size: int = 1024 * 1024, model: int = 0):
        # model: 3=General, 0=SingleCycle, etc. Ver Simulator.h
        self.model = model
        self.obj = core_lib.Simulator_new(mem_size, model)
        if not self.obj:
            raise MemoryError("No se pudo crear el objeto Simulator en C++.")

    def load_program(self, program: bytes):
        prog_array = (ctypes.c_uint8 * len(program))(*program)
        core_lib.Simulator_load_program(self.obj, prog_array, len(program), self.model)

    def load_program_from_assembly(self, assembly: str):
        assembly_bytes = assembly.encode('utf-8')
        core_lib.Simulator_load_program_from_assembly(self.obj, assembly_bytes, self.model)

    def assemble(self, assembly: str) -> bytes:
        """Ensambla código ensamblador y devuelve el código máquina como bytes."""
        assembly_bytes = assembly.encode('utf-8')
        
        # Primera llamada para obtener el tamaño necesario del buffer
        required_size = core_lib.Simulator_assemble(self.obj, assembly_bytes, None, 0)
        if required_size == 0:
            return b''

        # Crear un buffer del tamaño adecuado
        buffer = (ctypes.c_uint8 * required_size)()
        
        # Segunda llamada para llenar el buffer
        core_lib.Simulator_assemble(self.obj, assembly_bytes, buffer, required_size)

        return bytes(buffer)

    def step(self):
        print("Llamando al step de la dll...")
        return core_lib.Simulator_step(self.obj).decode('utf-8')

    def step_back(self):
        print("Llamando al step back de la dll...")
        return core_lib.Simulator_step_back(self.obj).decode('utf-8')

    def steps_until(self, breakpoints: List[int]):
        num_breakpoints = len(breakpoints)
        print(f"Llamando a steps_until de la dll con {num_breakpoints} breakpoints...")

        if num_breakpoints == 0:
            # Si no hay breakpoints, llamamos a la función con un puntero nulo y tamaño 0.
            return core_lib.Simulator_steps_until(self.obj, None, 0).decode('utf-8')

        breakpoints_array = (ctypes.c_uint32 * num_breakpoints)(*breakpoints)
        return core_lib.Simulator_steps_until(self.obj, breakpoints_array, num_breakpoints).decode('utf-8')


    def reset_with_model(self, model: int, initial_pc: int = 0):
        print("Llamando al reset de la dll...")
        return core_lib.Simulator_reset_with_model(self.obj, model, initial_pc).decode('utf-8')


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

    def get_d_mem(self) -> list[int]:
        """Obtiene el contenido de la memoria de datos (256 bytes)."""
        buffer = (ctypes.c_uint8 * 256)()
        core_lib.Simulator_get_d_mem(self.obj, buffer, 256)
        return bytes(buffer)

    def get_i_memBorrar(self) -> list[dict]:
        """Obtiene la memoria de instrucciones desensamblada como JSON."""
        json_str = core_lib.Simulator_get_i_mem(self.obj).decode('utf-8')
        return json.loads(json_str)
    
    def get_i_mem(self) -> List[dict]:
        """Obtiene la memoria de instrucciones desensamblada."""
        # Primera llamada para obtener el número de instrucciones
        num_instructions = core_lib.Simulator_get_i_mem(self.obj, None, 0)
        if num_instructions == 0:
            return []

        # Crear un buffer del tamaño adecuado
        BufferType = InstructionEntry * num_instructions
        buffer = BufferType()

        # Segunda llamada para llenar el buffer
        core_lib.Simulator_get_i_mem(self.obj, buffer, num_instructions)

        # Convertir el buffer a una lista de diccionarios de Python
        result = []
        for i in range(num_instructions):
            entry = buffer[i]   
            result.append({
                "value": entry.value,
                "instruction": entry.instruction.decode('utf-8', errors='ignore')
            })
        return result

    def __del__(self):
        if hasattr(self, 'obj') and self.obj:
            core_lib.Simulator_delete(self.obj)

    def set_hazard_options(self, stalls: bool, flushes: bool, forwarding: bool):
        """Configura las opciones de detección de riesgos en el núcleo C++."""
        if not self.obj:
            return
        core_lib.Simulator_set_hazard_options(self.obj, stalls, flushes, forwarding)

# --- Paso 5: Crear la aplicación FastAPI ---

app = FastAPI(title="RISC-V Simulator API")
from fastapi.middleware.cors import CORSMiddleware

# --- Lock para proteger el acceso concurrente al simulador ---
# FastAPI maneja las peticiones en hilos separados. Como solo tenemos una
# instancia del simulador, debemos protegerla para evitar condiciones de carrera.
simulators_lock = threading.Lock()

# --- Configuración de CORS ---
# Esto es CRUCIAL para que las aplicaciones web (como Flutter Web)
# que se ejecutan en un origen diferente (ej. localhost:5000)
# puedan comunicarse con esta API (ej. localhost:8070).
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Permite todos los orígenes (ideal para desarrollo)
    allow_credentials=True,
    allow_methods=["*"],  # Permite todos los métodos (GET, POST, etc.)
    allow_headers=["*"],  # Permite todas las cabeceras
)

# Importar la definición del layout de la palabra de control
try:
    from control_table_data import CONTROL_WORD_LAYOUT
    from program_data import DEFAULT_PROGRAM_A, DEFAULT_PROGRAM_B, DEFAULT_PROGRAM_C, DEFAULT_PROGRAM_D, DEFAULT_PROGRAM
except ImportError:
    print("ERROR: No se pudo encontrar 'control_table_data.py' o 'program_data.py'.", file=sys.stderr)
    print("Asegúrate de haber ejecutado los scripts de generación en 'resources/' primero.", file=sys.stderr)
    # Crear un layout por defecto para que la API no falle al arrancar
    CONTROL_WORD_LAYOUT = {
        "fields": {
            "ALUctr": {"position": 13, "width": 3}, "ResSrc": {"position": 11, "width": 2},
            "ImmSrc": {"position": 8, "width": 3}, "PCsrc": {"position": 6, "width": 2},
            "ALUsrc": {"position": 4, "width": 1}, "BRwr": {"position": 3, "width": 1},
            "MemWr": {"position": 2, "width": 1}
        }
    }
    # Programa vacío para evitar fallos
    DEFAULT_PROGRAM_A = b''
    DEFAULT_PROGRAM_B = b''
    DEFAULT_PROGRAM_C = b''
    DEFAULT_PROGRAM_D = b''
    DEFAULT_PROGRAM   = b''

# --- Funciones de ayuda para la API ---


def _get_signal_value(control_word: int, signal_name: str) -> int:
    """Extrae el valor de una señal de control de la palabra de control."""
    field_info = CONTROL_WORD_LAYOUT["fields"][signal_name]
    pos = field_info["position"]
    width = field_info["width"]
    mask = (1 << width) - 1
    return (control_word >> pos) & mask

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
    ALUsrc: int
    MemWr: bool
    ready_at: int
    is_active: bool

class SimulatorStateModel(BaseModel):
    # model: str = Field(..., description="Modelo de pipeline actual (ej. 'SingleCycle').")
    pc: int = Field(..., description="Contador de programa actual (en hexadecimal).")
    instruction: str = Field(..., description="Instrucción actual desensamblada.")
    status_register: int = Field(..., description="Registro de estado (ej. 'mstatus').")
    registers: dict[str, int] = Field(..., description="Estado de los 32 registros generales (con nombres ABI).")
    datapath: dict[str, SignalModel] = Field(..., description="Estado de todas las señales del datapath.")

    # --- Campos adicionales en la raíz del JSON ---
    # Pydantic usará estos campos para validar y construir el objeto final.
    # El `default=None` permite que no estén siempre presentes.
    criticalTime: Union[int, None] = Field(default=None)
    totalMicroCycles: Union[int, None] = Field(default=None)
    instruction_cptr: Union[str, None] = Field(default=None)
    Pipe_IF_instruction_cptr: Union[str, None] = Field(default=None)
    Pipe_ID_instruction_cptr: Union[str, None] = Field(default=None)
    Pipe_EX_instruction_cptr: Union[str, None] = Field(default=None)
    Pipe_MEM_instruction_cptr: Union[str, None] = Field(default=None)
    Pipe_WB_instruction_cptr: Union[str, None] = Field(default=None)
    Pipe_IF_instruction: Union[int, None] = Field(default=None)
    Pipe_ID_instruction: Union[int, None] = Field(default=None)
    Pipe_EX_instruction: Union[int, None] = Field(default=None)
    Pipe_MEM_instruction: Union[int, None] = Field(default=None)
    Pipe_WB_instruction: Union[int, None] = Field(default=None)

class InstructionMemoryItem(BaseModel):
    value: int
    instruction: str

# --- Constantes ---
ABI_NAMES = [
    "zero", "ra", "sp", "gp", "tp", "t0", "t1", "t2", "s0", "s1", "a0",
    "a1", "a2", "a3", "a4", "a5", "a6", "a7", "s2", "s3", "s4", "s5",
    "s6", "s7", "s8", "s9", "s10", "s11", "t3", "t4", "t5", "t6"
]

# --- Funciones de ayuda para la API ---

def _get_full_state_data(sim: Simulator, model_name: str) -> SimulatorStateModel:
    """Construye y devuelve el estado completo actual del simulador."""
    print("Reconstruyendo estado completo...")
    pc = sim.get_pc()
    status = sim.get_status_register()
    registers = sim.get_registers()
    datapath_c_struct = sim.get_datapath_state()

    reg_map = {f"x{i} ({ABI_NAMES[i]})": val for i, val in enumerate(registers)}

    # --- Conversión de estructuras C a modelos Pydantic ---
    # Decodificar las señales de control desde el entero de 16 bits.
    # NOTA: El orden y tamaño de los bits es una suposición.
    # Se debe ajustar para que coincida con la implementación C++.

    # control_signal = datapath_c_struct.Control
    # control_value = control_signal.value if control_signal else 0

    # control_signals_model = ControlSignalsModel(
    #     ALUctr=(control_value >> 13) & 0x7,
    #     ResSrc=(control_value >> 11) & 0x3,
    #     ImmSrc=(control_value >> 8) & 0x7,
    #     PCsrc=(control_value >> 6) & 0x3,
    #     ALUsrc=int((control_value >> 4) & 0x1), # dejo un bit posible ampliacion
    #     BRwr=bool((control_value >> 3) & 0x1),        
    #     MemWr=bool((control_value >> 2) & 0x1),
    #     ready_at=control_signal.ready_at,
    #     is_active=control_signal.is_active
    # )
    # control_signals_model = ControlSignalsModel(
    #     ALUctr=_get_signal_value(control_value, "ALUctr"),
    #     ResSrc=_get_signal_value(control_value, "ResSrc"),
    #     ImmSrc=_get_signal_value(control_value, "ImmSrc"),
    #     PCsrc=_get_signal_value(control_value, "PCsrc"),
    #     ALUsrc=_get_signal_value(control_value, "ALUsrc"),
    #     BRwr=bool(_get_signal_value(control_value, "BRwr")),
    #     MemWr=bool(_get_signal_value(control_value, "MemWr")),
    #     ready_at=control_signal.ready_at,
    #     is_active=control_signal.is_active
    # )

    datapath_model = {}
    extra_fields_model = {}
    signal_types = (Signal_u32, Signal_u16, Signal_u8, Signal_bool)    

    # Iteramos sobre TODOS los campos definidos en la estructura ctypes
    for field_name, field_type in datapath_c_struct._fields_:
        # Obtenemos el valor del campo desde la instancia de la estructura C
        value = getattr(datapath_c_struct, field_name)
        # Caso 1: El campo es una de nuestras estructuras 'Signal_*'
        if isinstance(value, signal_types):
            # print(field_name)
            # print(value.value)
            datapath_model[field_name] = {
                "value": value.value,
                "ready_at": value.ready_at,
                "is_active": bool(value.is_active)
            }
        # Caso 2: El campo es un array de bytes (proviene de char[] en C)
        elif isinstance(value, bytes):
            # Lo decodificamos a una cadena de Python, eliminando caracteres nulos
            extra_fields_model[field_name] = value.decode('utf-8', errors='ignore').strip('\x00')
        # Caso 3: Es un tipo primitivo (int, etc.) que no es una señal
        else:
            # Para los tipos primitivos, simplemente los añadimos al diccionario principal.
            # El frontend los buscará en el nivel superior del JSON.
            extra_fields_model[field_name] = value

# Esto es al final lo importante

    return SimulatorStateModel(
        # model=model_name,
        # pc=f"0x{pc:08x}",
        pc = pc,
        instruction=extra_fields_model.get("instruction_cptr", ""),
        # status_register=f"0x{status:08x}",
        status_register = status,
        # Creo que lo de abajo no se usa
        # control_signals=control_signals_model,
        registers=reg_map,

        datapath=datapath_model,
        **extra_fields_model
    )

# --- Gestión de Sesiones y Estado ---

# Usaremos un diccionario para almacenar una instancia de simulador por sesión.
simulators: Dict[str, Dict[str, Union[Simulator, str]]] = {}

class SessionResponse(BaseModel):
    session_id: str

@app.post("/session/start", response_model=SessionResponse, summary="Inicia una nueva sesión de simulación")
def start_session():
    """Crea una nueva instancia del simulador y devuelve un ID de sesión único."""
    with simulators_lock:
        session_id = str(uuid.uuid4())
        simulators[session_id] = {
            "sim": Simulator(model=3),
            "model_name": "General"
        }
        print(f"Nueva sesión iniciada: {session_id}")
        return SessionResponse(session_id=session_id)

def get_simulator_for_session(session_id: str) -> Dict[str, Union[Simulator, str]]:
    """Obtiene el simulador para un ID de sesión, o lanza una excepción si no se encuentra."""
    sim_instance = simulators.get(session_id)
    if not sim_instance:
        raise HTTPException(status_code=404, detail="Session ID not found. Please start a new session.")
    return sim_instance


@app.get("/state", response_model=SimulatorStateModel, summary="Obtener el estado actual del simulador")
def get_state_endpoint(session_id: str = Query(..., description="ID de la sesión")) -> SimulatorStateModel:
    with simulators_lock:
        sim_instance = get_simulator_for_session(session_id)
        sim = sim_instance["sim"]
        model_name = sim_instance["model_name"]
        return _get_full_state_data(sim, model_name)

# Modelo para la petición de reset
class ResetConfig(BaseModel):
    model: Literal['SingleCycle','PipeLined','MultiCycle','General'] = 'SingleCycle'
    initial_pc: int = 0
    load_test_program: bool = True
    bin_code: str | None = None  # Base64 encoded binary
    assembly_code: str | None = None
    hazards_enabled: bool = True # Nuevo campo para controlar los riesgos



@app.post("/reset", response_model=SimulatorStateModel, summary="Reinicia el simulador para una sesión")
def reset_simulator(
    session_id: str = Query(..., description="ID de la sesión a reiniciar"),
    config: ResetConfig = Body(...)
) -> SimulatorStateModel:
    """
    Reinicia el simulador. Permite cambiar el modelo de pipeline y cargar un programa.
    - **model**: 'SingleCycle' (didáctico), 'MultiCycle', 'PipeLined', 'General'.
    - **initial_pc**: Dirección de inicio para el contador de programa.
    - **load_test_program**: Si es true, carga el programa de prueba inicial (ignorado si se provee bin_code o assembly_code).
    - **bin_code**: Código binario del programa, codificado en Base64.
    - **assembly_code**: Código ensamblador del programa (aún no implementado).
    - **hazards_enabled**: Si es true, activa la detección de riesgos de datos y de control, y los cortocircuitos.
    """
    with simulators_lock:
        # Obtenemos la instancia existente para asegurarnos de que la sesión es válida
        get_simulator_for_session(session_id)

        model_map = {'SingleCycle': 0,'PipeLined': 1,'MultiCycle': 2, 'General': 3, }
        model_id = model_map[config.model]
        print("Llamando a Simulator_reset...")

        # Al reemplazar la instancia, el __del__ del objeto antiguo se llama, liberando la memoria C++.
        simulators[session_id] = {
            "sim": Simulator(model=model_id),
            "model_name": config.model
        }
        sim = simulators[session_id]["sim"]

        # Configuramos las opciones de riesgo en el núcleo C++
        sim.set_hazard_options(stalls=config.hazards_enabled, 
                               flushes=config.hazards_enabled, 
                               forwarding=config.hazards_enabled)
        print("Creada nueva instancia del simulador...")

        if config.bin_code:
            try:
                program_bytes = base64.b64decode(config.bin_code)
                sim.load_program(program_bytes)
                print(f"Cargado programa binario personalizado ({len(program_bytes)} bytes)...")
            except Exception as e:
                sim.load_program(DEFAULT_PROGRAM)
                # raise HTTPException(status_code=400, detail=f"Error decodificando o cargando bin_code: {e}")
        elif config.assembly_code:
            try:
                sim.load_program_from_assembly(config.assembly_code)
                print(f"Cargado programa desde ensamblador...")
            except Exception as e:
                raise HTTPException(status_code=400, detail=f"Error cargando assembly_code: {e}")
        elif config.load_test_program:
            sim.load_program(DEFAULT_PROGRAM)
            print("Cargado programa por defecto:")
            print(DEFAULT_PROGRAM)
            
        # Ejecuta el primer paso para tener un estado inicial y luego lo devuelve completo
        simulators[session_id]["sim"].reset_with_model(model_id, config.initial_pc)
        print();
        sim_instance = simulators[session_id]
        sim = sim_instance["sim"]
        model_name = sim_instance["model_name"]
        print("Ejecutado reset (incluye step)...")
        return _get_full_state_data(sim, model_name)

@app.post("/step", response_model=SimulatorStateModel, summary="Ejecutar un ciclo de instrucción")
def execute_step(session_id: str = Query(..., description="ID de la sesión")) -> SimulatorStateModel:
    """Ejecuta un paso y devuelve el nuevo estado de los registros."""
    with simulators_lock:
        sim_instance = get_simulator_for_session(session_id)
        sim_instance["sim"].step()
        sim = sim_instance["sim"]
        model_name = sim_instance["model_name"]
        return _get_full_state_data(sim, model_name)
    
@app.post("/step_back", response_model=SimulatorStateModel, summary="Ejecutar un ciclo de instrucción")
def execute_step_back(session_id: str = Query(..., description="ID de la sesión")) -> SimulatorStateModel:
    """Ejecuta un paso y devuelve el nuevo estado de los registros."""
    with simulators_lock:
        sim_instance = get_simulator_for_session(session_id)
        sim_instance["sim"].step_back()
        sim = sim_instance["sim"]
        model_name = sim_instance["model_name"]
        return _get_full_state_data(sim, model_name)    

class RunConfig(BaseModel):
    breakpoints: List[int]

@app.post("/run", response_model=SimulatorStateModel, summary="Ejecutar hasta el siguiente breakpoint")
def run_until(
    session_id: str = Query(..., description="ID de la sesión"),
    config: RunConfig = Body(...)
) -> SimulatorStateModel:
    """
    Ejecuta la simulación hasta que el PC alcanza una de las direcciones en la lista de 'breakpoints',
    se detecta un bucle o se alcanza el número máximo de pasos.
    """
    with simulators_lock:
        sim_instance = get_simulator_for_session(session_id)
        sim = sim_instance["sim"]
        model_name = sim_instance["model_name"]
        sim.steps_until(config.breakpoints)
        return _get_full_state_data(sim, model_name)

@app.get("/memory/data", 
         summary="Obtener el contenido de la memoria de datos",
         # Indicamos que la respuesta será de tipo 'application/octet-stream'
         responses={
             200: {
                 "content": {"application/octet-stream": {}}
             }
         })
def get_data_memory(session_id: str = Query(..., description="ID de la sesión")):
    """Devuelve los 256 bytes de la memoria de datos del modo didáctico como binario crudo."""
    with simulators_lock:
        sim_instance = get_simulator_for_session(session_id)
        sim = sim_instance["sim"]
        # 1. Obtenemos los datos como un objeto de bytes
        memory_bytes = sim.get_d_mem()
        
        # 2. Creamos y devolvemos un objeto Response con los bytes y el tipo de medio correcto
        return Response(content=memory_bytes, media_type="application/octet-stream")


@app.get("/memory/instructions", response_model=List[InstructionMemoryItem], summary="Obtener la memoria de instrucciones desensamblada")
def get_instruction_memory(session_id: str = Query(..., description="ID de la sesión")):
    """Devuelve el contenido de la memoria de instrucciones, con cada instrucción desensamblada."""
    with simulators_lock:
        sim_instance = get_simulator_for_session(session_id)
        sim = sim_instance["sim"]
        return sim.get_i_mem()

@app.post("/assemble", summary="Ensambla código RISC-V")
def assemble_code(
    session_id: str = Query(..., description="ID de la sesión"),
    assembly_code: str = Body(..., embed=True, description="Código ensamblador a compilar")
):
    """
    Toma una cadena de código ensamblador, la compila usando el núcleo C++
    y devuelve el código máquina resultante codificado en Base64.
    """
    with simulators_lock:
        sim_instance = get_simulator_for_session(session_id)
        sim = sim_instance["sim"]
        try:
            machine_code = sim.assemble(assembly_code)
            machine_code_b64 = base64.b64encode(machine_code).decode('utf-8')
            return {
                "machine_code_b64": machine_code_b64,
                "size_bytes": len(machine_code)
            }
        except Exception as e:
            raise HTTPException(status_code=400, detail=f"Error durante el ensamblado: {e}")

# --- Endpoint para el Generador de Preguntas ---

class FingerprintModel(BaseModel):
    fingerprint: str
    question_type: int = Field(default=1, description="Tipo de pregunta a generar (1: Estado final, 2: Valor de registro, 3: Bits de un valor, 4: Señal de control).")

@app.post("/questions/q&a1", summary="Genera un par de pregunta y respuesta para un examen")
def generate_question_endpoint(config: FingerprintModel = Body(...)):
    """
    Genera una pregunta de examen determinista a partir de un 'fingerprint'.
    Este endpoint es autocontenido y gestiona su propia sesión de simulador.
    """
    # Importamos el generador aquí para mantenerlo aislado del resto de la API.
    try:
        # Como 'generator.py' está ahora en la misma carpeta 'api', se puede importar directamente.
        import generator
    except ImportError:
        raise HTTPException(status_code=500, detail="No se pudo encontrar el módulo 'generator.py'.")

    # Usamos un lock para asegurar que la generación es atómica, aunque
    # este endpoint gestiona su propia instancia de simulador.
    with simulators_lock:
        try:
            # 1. Generar el código y ejecutar la simulación (esto no cambia)
            assembly_code, code_info, initial_pc = generator.generate_test_case(config.fingerprint)

            # 2. Crear una instancia temporal del simulador
            sim = Simulator(model=0) # Modelo 0 = SingleCycle
            
            # 3. Cargar el programa y establecer el PC (sin llamar a reset_with_model)
            sim.load_program_from_assembly(assembly_code)
            # Esta es la clave: evitamos el `step()` automático de `reset_with_model`
            # que causa el crash. ¡CORRECCIÓN! El reset es necesario.
            sim.reset_with_model(model=0, initial_pc=initial_pc)
            
            # 4. Ejecutar el programa hasta el final
            sim.steps_until(breakpoints=[]) # Se detendrá por bucle infinito

            # 5. Formatear la pregunta y la respuesta SEGÚN EL TIPO SOLICITADO
            if config.question_type == 1:
                # Comportamiento original: preguntar por el estado final completo.
                qa_pair = generator.format_question_answer(
                    assembly_code=assembly_code,
                    initial_pc=initial_pc,
                    sim=sim,
                    code_info=code_info
                )
            elif config.question_type == 2:
                # Nueva pregunta: Valor de un registro específico.
                # Reutilizamos el generador para elegir un registro de forma determinista.
                reg_to_ask_idx = code_info['reg_to_ask']
                reg_name = f"x{reg_to_ask_idx} ({generator.ABI_NAMES[reg_to_ask_idx]})"
                
                question_text = f"""
Considerando el estado final del procesador tras ejecutar el siguiente código (iniciando en {hex(initial_pc)}):

```assembly
{assembly_code}
```

¿Cuál es el valor final contenido en el registro **{reg_name}**?
"""
                final_registers = sim.get_registers()
                final_value = final_registers[reg_to_ask_idx]

                qa_pair = {
                    "question": question_text.strip(),
                    "answer": {
                        "register_queried": reg_name,
                        "final_value_decimal": final_value,
                        "final_value_hex": f"0x{final_value:08x}"
                    }
                }
            elif config.question_type == 3:
                # Implementación para "cuáles son los bits tal a tal"
                reg_to_ask_idx = code_info['reg_to_ask']
                reg_name = f"x{reg_to_ask_idx} ({generator.ABI_NAMES[reg_to_ask_idx]})"
                bit_start = code_info['bit_start']
                bit_end = code_info['bit_end']

                question_text = f"""
Considerando el estado final del procesador tras la ejecución del código anterior, ¿cuál es el valor binario de los bits `{bit_end}:{bit_start}` del registro **{reg_name}**?
"""
                final_registers = sim.get_registers()
                final_value = final_registers[reg_to_ask_idx]

                # Lógica para extraer los bits
                bit_length = bit_end - bit_start + 1
                mask = (1 << bit_length) - 1
                extracted_bits_value = (final_value >> bit_start) & mask
                
                # Formatear el valor binario con ceros a la izquierda
                binary_representation = f"{extracted_bits_value:0{bit_length}b}"

                qa_pair = {
                    "question": question_text.strip(),
                    "answer": {
                        "register_queried": reg_name,
                        "bit_range": f"{bit_end}:{bit_start}",
                        "value_binary": binary_representation,
                        "value_decimal": extracted_bits_value
                    }
                }
            elif config.question_type == 4:
                # Pregunta sobre el valor de una señal de control en la última instrucción
                signal_to_ask = code_info['signal_to_ask']

                question_text = f"""
Siguiendo con el mismo caso, ¿qué valor tomó la señal de control **{signal_to_ask}** durante la ejecución de la última instrucción del programa (`lw`)?
"""
                # El estado del datapath corresponde al último ciclo, que es el de la instrucción 'lw'
                datapath_state = sim.get_datapath_state()
                signal_value = getattr(datapath_state, signal_to_ask).value

                qa_pair = {
                    "question": question_text.strip(),
                    "answer": {
                        "signal_queried": signal_to_ask,
                        "value": signal_value
                    }
                }
            else:
                raise HTTPException(status_code=400, detail=f"Invalid question_type: {config.question_type}")

            return qa_pair

        except Exception as e:
            # Capturamos cualquier error durante la generación.
            raise HTTPException(status_code=500, detail=f"Error generando la pregunta: {e}")

@app.post("/assemble", summary="Ensambla código RISC-V")
def assemble_code(
    session_id: str = Query(..., description="ID de la sesión"),
    assembly_code: str = Body(..., embed=True, description="Código ensamblador a compilar")
):
    """
    Toma una cadena de código ensamblador, la compila usando el núcleo C++
    y devuelve el código máquina resultante codificado en Base64.
    """
    with simulators_lock:
        sim_instance = get_simulator_for_session(session_id)
        sim = sim_instance["sim"]
        try:
            machine_code = sim.assemble(assembly_code)
            machine_code_b64 = base64.b64encode(machine_code).decode('utf-8')
            return {
                "machine_code_b64": machine_code_b64,
                "size_bytes": len(machine_code)
            }
        except Exception as e:
            raise HTTPException(status_code=400, detail=f"Error durante el ensamblado: {e}")
