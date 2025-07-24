import ctypes
import pathlib
import sys
from fastapi import FastAPI

# --- Paso 1: Encontrar y cargar la biblioteca compartida C++ ---

def find_library_path():
    """Encuentra la ruta a la biblioteca C++ compilada (.dll o .so)."""
    lib_name = "simulator.dll" if sys.platform == "win32" else "libsimulator.so"
    
    # Buscar en las carpetas de compilación comunes relativas a este script
    script_dir = pathlib.Path(__file__).parent
    root_dir = script_dir.parent
    
    search_paths = [
        root_dir / "build",
        root_dir / "build" / "Debug",
        root_dir / "build" / "Release",
    ]
    
    for path in search_paths:
        lib_path = path / lib_name
        if lib_path.exists():
            print(f"Biblioteca encontrada en: {lib_path}")
            return lib_path
            
    raise FileNotFoundError(f"No se pudo encontrar {lib_name} en {search_paths}")

# Cargar la biblioteca
try:
    lib_path = find_library_path()
    core_lib = ctypes.CDLL(str(lib_path))
except FileNotFoundError as e:
    print(f"ERROR: {e}", file=sys.stderr)
    print("Asegúrate de haber compilado el núcleo C++ primero.", file=sys.stderr)
    sys.exit(1)

# --- Paso 2: Definir los prototipos de las funciones C ---

core_lib.Simulator_new.argtypes = [ctypes.c_size_t]
core_lib.Simulator_new.restype = ctypes.c_void_p

core_lib.Simulator_delete.argtypes = [ctypes.c_void_p]
core_lib.Simulator_delete.restype = None

core_lib.Simulator_load_program.argtypes = [ctypes.c_void_p, ctypes.POINTER(ctypes.c_uint8), ctypes.c_size_t]
core_lib.Simulator_load_program.restype = None

core_lib.Simulator_step.argtypes = [ctypes.c_void_p]
core_lib.Simulator_step.restype = None

core_lib.Simulator_get_pc.argtypes = [ctypes.c_void_p]
core_lib.Simulator_get_pc.restype = ctypes.c_uint32

core_lib.Simulator_get_all_registers.argtypes = [ctypes.c_void_p, ctypes.POINTER(ctypes.c_uint32)]
core_lib.Simulator_get_all_registers.restype = None

# --- Paso 3: Crear una clase Python que envuelva la lógica C++ ---

class Simulator:
    """Wrapper de Python para el simulador C++."""
    def __init__(self, mem_size: int = 1024 * 1024):
        self.obj = core_lib.Simulator_new(mem_size)
        if not self.obj:
            raise MemoryError("No se pudo crear el objeto Simulator en C++.")

    def load_program(self, program: bytes):
        prog_array = (ctypes.c_uint8 * len(program))(*program)
        core_lib.Simulator_load_program(self.obj, prog_array, len(program))

    def step(self):
        core_lib.Simulator_step(self.obj)

    def get_registers(self) -> list[int]:
        reg_array = (ctypes.c_uint32 * 32)()
        core_lib.Simulator_get_all_registers(self.obj, reg_array)
        return list(reg_array)

    def __del__(self):
        if hasattr(self, 'obj') and self.obj:
            core_lib.Simulator_delete(self.obj)

# --- Paso 4: Crear la aplicación FastAPI ---

app = FastAPI(title="RISC-V Simulator API")

# Creamos una instancia global del simulador
simulator = Simulator()

# Cargamos un pequeño programa de prueba para demostrar la funcionalidad
# ADDI x5, x0, 10  (0x00A00293)
# ADDI x6, x0, 20  (0x01400313)
# ADD  x7, x5, x6  (0x006283B3) -> x7 debería ser 30
program_bytes = bytes([
    0x93, 0x02, 0xA0, 0x00, # Little-endian
    0x13, 0x03, 0x40, 0x01,
    0xB3, 0x83, 0x62, 0x00,
])
simulator.load_program(program_bytes)

@app.get("/state", summary="Obtener el estado actual del simulador")
def get_state():
    """Devuelve el PC y el valor de los 32 registros."""
    registers = simulator.get_registers()
    abi_names = [
        "zero", "ra", "sp", "gp", "tp", "t0", "t1", "t2", "s0", "s1", "a0", 
        "a1", "a2", "a3", "a4", "a5", "a6", "a7", "s2", "s3", "s4", "s5", 
        "s6", "s7", "s8", "s9", "s10", "s11", "t3", "t4", "t5", "t6"
    ]
    reg_map = {f"x{i} ({abi_names[i]})": f"0x{val:08x}" for i, val in enumerate(registers)}
    return {"registers": reg_map}

@app.post("/step", summary="Ejecutar un ciclo de instrucción")
def execute_step():
    """Ejecuta un paso y devuelve el nuevo estado de los registros."""
    simulator.step()
    return get_state()