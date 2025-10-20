import random
import json
from typing import Dict, Any, Tuple

# La URL donde se está ejecutando tu API de FastAPI
API_BASE_URL = "http://localhost:8070"
ABI_NAMES = [
    "zero", "ra", "sp", "gp", "tp", "t0", "t1", "t2", "s0", "s1", "a0",
    "a1", "a2", "a3", "a4", "a5", "a6", "a7", "s2", "s3", "s4", "s5",
    "s6", "s7", "s8", "s9", "s10", "s11", "t3", "t4", "t5", "t6"
]

class DeterministicGenerator:
    """
    Proporciona números pseudo-aleatorios de forma determinista y robusta
    a partir de un fingerprint. Si se necesitan más números en el futuro,
    se pueden añadir nuevas llamadas a los métodos de esta clase sin alterar
    la secuencia de los números ya generados para fingerprints antiguos.
    """
    def __init__(self, fingerprint_hex: str):
        try:
            # Intentamos usar el fingerprint como semilla.
            seed_int = int(fingerprint_hex, 16)
        except (ValueError, TypeError):
            # Si el fingerprint no es un hexadecimal válido, generamos una semilla aleatoria.
            # Esto es útil para pruebas, pero en producción se debería usar un fingerprint válido.
            seed_int = random.getrandbits(160)
        
        # Usamos una instancia de random.Random para no afectar al estado global.
        self._rng = random.Random(seed_int)

    def get_int(self, min_val: int, max_val: int) -> int:
        """Obtiene un entero en un rango, de forma determinista."""
        return self._rng.randint(min_val, max_val)

    def choice(self, sequence):
        """Elige un elemento de una secuencia, de forma determinista."""
        return self._rng.choice(sequence)
        
    def shuffle_and_pop(self, sequence: list, count: int) -> list:
        """Baraja una lista y devuelve los últimos 'count' elementos."""
        self._rng.shuffle(sequence)
        return [sequence.pop() for _ in range(count)]

def generate_test_case(fingerprint_hex: str) -> Tuple[str, Dict[str, Any], int]:
    """
    Función principal que, a partir de un fingerprint, genera de forma determinista
    el código ensamblador, la información relevante y el PC inicial.
    Toda la lógica "aleatoria" se encapsula aquí.
    """
    # 1. Crear nuestro proveedor de aleatoriedad robusto.
    gen = DeterministicGenerator(fingerprint_hex)

    # 2. Generar todos los "números aleatorios" que necesitamos en un orden fijo.
    # Si en el futuro necesitamos más, los añadimos al final de esta sección.
    available_regs = list(range(3, 32)) # Registros usables (x3 a x31)
    reg_load, reg_sum, reg_val2, reg_val1, reg_addr = gen.shuffle_and_pop(available_regs, 5)

    val1 = gen.get_int(1, 15)
    val2 = gen.get_int(1, 15)
    mem_addr = gen.get_int(0, 15) * 4
    initial_pc = gen.choice([0x100, 0x200, 0x400, 0x800])

    # 3. Construir el código ensamblador usando los valores generados.
    assembly_code = f"""
.text
addi x{reg_val1}, zero, {val1}
addi x{reg_val2}, zero, {val2}
add x{reg_sum}, x{reg_val1}, x{reg_val2}
addi x{reg_addr}, zero, {mem_addr}
sw x{reg_sum}, 0(x{reg_addr})
lw x{reg_load}, 0(x{reg_addr})
end:
jal zero, end
"""
    
    code_info = {'reg_load': reg_load, 'reg_sum': reg_sum}
    return assembly_code, code_info, initial_pc

def format_question_answer(assembly_code: str, initial_pc: int, sim, code_info: Dict[str, Any]) -> Dict[str, Any]:
    """
    Formatea la pregunta y la respuesta a partir de un estado final del simulador.
    """
    # --- Formateo de la Pregunta ---
    # Hacemos una pregunta más específica, por ejemplo, sobre el valor de un registro concreto.
    # Para que sea determinista, la elección también debería usar el generador,
    # pero por ahora la fijamos para simplificar.
    reg_to_ask = 'reg_load'
    reg_idx = code_info[reg_to_ask]
    reg_name = f"x{reg_idx} ({ABI_NAMES[reg_idx]})"
    question_text = f"""
Dada la siguiente secuencia de instrucciones RISC-V, que se empieza a ejecutar en la dirección {hex(initial_pc)}:

```assembly
{assembly_code}
```

Determine el valor final contenido en el banco de registros y en la memoria de datos después de que el programa se detenga.
"""
    
    # --- Formateo de la Respuesta ---
    # Obtenemos el estado directamente del objeto simulador que nos pasan.
    final_registers_list = sim.get_registers()
    final_registers = {f"x{i} ({ABI_NAMES[i]})": val for i, val in enumerate(final_registers_list)}
    final_memory_bytes = sim.get_d_mem()

    # Convertimos los bytes de memoria a un formato legible.
    memory_view = {}
    for i in range(0, len(final_memory_bytes), 4):
        if i + 4 <= len(final_memory_bytes):
            word_bytes = final_memory_bytes[i:i+4]
            # Asumimos Little Endian
            word_value = int.from_bytes(word_bytes, 'little')
            if word_value != 0:
                memory_view[f"0x{i:04x}"] = f"0x{word_value:08x} ({word_value})"

    answer = {
        "final_registers": final_registers,
        "final_data_memory": memory_view
    }

    return {
        "question": question_text.strip(),
        "answer": answer
    }
