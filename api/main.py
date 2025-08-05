import ctypes
import pathlib
import sys
from fastapi import FastAPI, Body
from pydantic import BaseModel
from typing import Literal

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
    _fields_ = [("value", ctypes.c_uint32), ("ready_at", ctypes.c_uint32)]

class Signal_u16(ctypes.Structure):
    _fields_ = [("value", ctypes.c_uint16), ("ready_at", ctypes.c_uint32)]

class Signal_u8(ctypes.Structure):
    _fields_ = [("value", ctypes.c_uint8), ("ready_at", ctypes.c_uint32)]

class Signal_bool(ctypes.Structure):
    _fields_ = [("value", ctypes.c_bool), ("ready_at", ctypes.c_uint32)]

class DatapathState(ctypes.Structure):
    _fields_ = [
        ("bus_PC", Signal_u32),
        ("bus_Instr", Signal_u32),
        ("bus_Opcode", Signal_u8),
        ("bus_funct3", Signal_u8),
        ("bus_funct7", Signal_u8),
        ("bus_DA", Signal_u8),
        ("bus_DB", Signal_u8),
        ("bus_DC", Signal_u8),
        ("bus_A", Signal_u32),
        ("bus_B", Signal_u32),
        ("bus_imm", Signal_u32),
        ("bus_immExt", Signal_u32),
        ("bus_ALU_A", Signal_u32),
        ("bus_ALU_B", Signal_u32),
        ("bus_ALU_result", Signal_u32),
        ("bus_ALU_zero", Signal_bool),
        ("bus_Control", Signal_u16),
        # --- Campos que faltaban ---
        ("bus_Mem_address", Signal_u32),
        ("bus_Mem_write_data", Signal_u32),
        ("bus_Mem_read_data", Signal_u32),
        ("bus_C", Signal_u32),
        ("bus_PC_plus4", Signal_u32),
        ("bus_PC_dest", Signal_u32),
        ("bus_PC_next", Signal_u32),
        ("bus_branch_taken", Signal_bool),
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

core_lib.Simulator_get_instruction_string.argtypes = [ctypes.c_void_p]
core_lib.Simulator_get_instruction_string.restype = ctypes.c_char_p



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
        return core_lib.Simulator_step(self.obj)

    def get_pc(self) -> int:
        return core_lib.Simulator_get_pc(self.obj)

    def get_status_register(self) -> int:
        return core_lib.Simulator_get_status_register(self.obj)
    

    def get_registers(self) -> list[int]:
        reg_array = (ctypes.c_uint32 * 32)()
        core_lib.Simulator_get_all_registers(self.obj, reg_array)
        return list(reg_array)
    
    def get_datapath_state(self) -> DatapathState:
        return core_lib.Simulator_get_datapath_state(self.obj)

    def get_instruction_string(self) -> str:
        return core_lib.Simulator_get_instruction_string(self.obj).decode('utf-8')

    def __del__(self):
        if hasattr(self, 'obj') and self.obj:
            core_lib.Simulator_delete(self.obj)

# --- Paso 5: Crear la aplicación FastAPI ---

app = FastAPI(title="RISC-V Simulator API")

# Creamos una instancia global del simulador dentro de un diccionario
# para que pueda ser reemplazada por los endpoints.
simulator_instance = {"sim": Simulator(model=0)} # General por defecto

# Cargamos un pequeño programa de prueba para demostrar la funcionalidad
# ADDI x5, x0, 10  (0x00A00293)
# ADDI x6, x0, 20  (0x01400313)
# ADD  x7, x5, x6  (0x006283B3) -> x7 debería ser 30
program_bytes = bytes([
    0x93, 0x02, 0xA0, 0x00, # Little-endian
    0x13, 0x03, 0x40, 0x01,
    0xB3, 0x83, 0x62, 0x00,
])
simulator_instance["sim"].load_program(program_bytes)

# Modelo para la petición de reset
class ResetConfig(BaseModel):
    model: Literal['SingleCycle','MultiCycle','PipeLined','General'] = 'SingleCycle'
    load_test_program: bool = True

@app.post("/reset", summary="Reinicia el simulador a un estado inicial")
def reset_simulator(config: ResetConfig = Body(...)):
    """
    Reinicia el simulador. Permite cambiar el modelo de pipeline.
    - **model**: 'SingleCycle' (didáctico), 'MultiCycle', 'PipeLined', 'General'.
    - **load_test_program**: Si es true, carga el programa de prueba inicial.
    """
    model_map = {'SingleCycle': 0,'MultiCycle': 1,'PipeLined': 2, 'General': 3, }
    model_id = model_map[config.model]
    
    # Al reemplazar la instancia en el diccionario, el objeto Simulator anterior
    # pierde su única referencia. El recolector de basura de Python lo detectará
    # y llamará a su método __del__, que a su vez invoca a la función C++
    # Simulator_delete para liberar la memoria. Por lo tanto, no hay fuga de memoria.
    simulator_instance["sim"] = Simulator(model=model_id)
    
    if config.load_test_program:
        simulator_instance["sim"].load_program(program_bytes)
        
    return {"message": f"Simulador reiniciado en modo {config.model}."}

@app.get("/state", summary="Obtener el estado actual del simulador")
def get_state():
    """Devuelve el modelo, PC, registro de estado, el valor de los 32 registros y el estado del datapath."""
    sim = simulator_instance["sim"]
    pc = sim.get_pc()
    status = sim.get_status_register()
    registers = sim.get_registers()
    datapath_c_struct = sim.get_datapath_state()
    instruction_string = sim.get_instruction_string()
    
    abi_names = [
        "zero", "ra", "sp", "gp", "tp", "t0", "t1", "t2", "s0", "s1", "a0", 
        "a1", "a2", "a3", "a4", "a5", "a6", "a7", "s2", "s3", "s4", "s5", 
        "s6", "s7", "s8", "s9", "s10", "s11", "t3", "t4", "t5", "t6"
    ]
    reg_map = {f"x{i} ({abi_names[i]})": f"0x{val:08x}" for i, val in enumerate(registers)}

    # --- Desempaquetado de las señales de control ---
    # Extraemos la palabra de control empaquetada y la procesamos en Python
    packed_word = datapath_c_struct.bus_Control.value
    unpacked_control_signals = {
        "ALUctr":   (packed_word >> 13) & 0x7,
        "ResSrc":   (packed_word >> 11) & 0x3,
        "ImmSrc":   (packed_word >> 9)  & 0x3,
        "PCsrc":    (packed_word >> 7)  & 0x2,
        "BRwr":     (packed_word >> 6)  & 0x1,
        "ALUsrc":   (packed_word >> 5)  & 0x1,
        "MemWr":    (packed_word >> 4)  & 0x1,
        "ready_at": datapath_c_struct.bus_Control.ready_at
    }
    
    datapath_dict = {}
    for field_name, _ in datapath_c_struct._fields_:
        signal = getattr(datapath_c_struct, field_name)
        value = signal.value
        
        # Formatear valores numéricos a hexadecimal para consistencia
        if isinstance(value, int) and not isinstance(value, bool):
            formatted_value = f"0x{value:08x}"
        else:
            formatted_value = value

        datapath_dict[field_name] = {
            "value": formatted_value,
            "ready_at": signal.ready_at
        }

    return {
        "model": "SingleCycle", # Placeholder, necesita get_model()
        "pc": f"0x{pc:08x}",
        "instruction": instruction_string,
        "status_register": f"0x{status:08x}",
        "control_signals": unpacked_control_signals,
        "registers": reg_map,
        "datapath": datapath_dict
    }

@app.post("/step", summary="Ejecutar un ciclo de instrucción")
def execute_step():
    """Ejecuta un paso y devuelve el nuevo estado de los registros."""
    simulator_instance["sim"].step()
    return get_state()