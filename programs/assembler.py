#!/usr/bin/env python
# -*- coding: utf-8 -*-

# ==============================================================================
#  ENSAMBLADOR PARA PROGRAMA D
# ==============================================================================
#
# Este script utiliza la librería riscv-assembler para convertir
# código ensamblador RISC-V en un array de bytes de Python.
#
# Instalación:
# pip install riscv-assembler
#
# Uso:
# python resources/assembler.py
#
# El resultado se imprimirá en la consola.
# ------------------------------------------------------------------------------

from riscv_assembler.convert import AssemblyConverter 
from riscv_assembler.instr_arr import *
from riscv_assembler.parse import Parser

import io
from pathlib import Path

path = str(Path(__file__).parent / "asm/programD.s")


def reemplazar_registros_abi(asm_code: str) -> str:
    """
    Reemplaza los registros x0..x31 por sus nombres ABI en un código ensamblador RISC-V.
    """
    # Mapeo de xN -> nombre ABI
    registro_abi = {
        "x0": "x0", "x1": "ra", "x2": "sp", "x3": "gp", "x4": "tp",
        "x5": "t0", "x6": "t1", "x7": "t2",
        "x8": "s0", "x9": "s1",
        "x10": "a0", "x11": "a1", "x12": "a2", "x13": "a3", "x14": "a4",
        "x15": "a5", "x16": "a6", "x17": "a7",
        "x18": "s2", "x19": "s3", "x20": "s4", "x21": "s5", "x22": "s6",
        "x23": "s7", "x24": "s8", "x25": "s9", "x26": "s10", "x27": "s11",
        "x28": "t3", "x29": "t4", "x30": "t5", "x31": "t6"
    }

    # Reemplazo de manera segura, evitando coincidencias parciales
    for x, abi in registro_abi.items():
        asm_code = asm_code.replace(x, abi)
    
    return asm_code

asm_code2="""
main:
    addi x9 x0 10         # 1. Contador para el bucle de inicialización (10 elementos)
    addi x18 x0 10        # 2. Valor inicial a almacenar en el array
    addi x19 x8 128       # 3. Puntero al inicio del array (dirección 0x80)
init_loop:
    beq x9 x0 end_init    # 4. Si el contador es 0 fin del bucle
    sw x18 0(x19)          # 5. Almacenar el valor en la dirección actual del array
    addi x18 x18 10       # 6. Incrementar el valor a almacenar
    addi x19 x19 4        # 7. Avanzar el puntero del array al siguiente elemento
    addi x9 x9 -1         # 8. Decrementar el contador
    j init_loop       # 9. Volver al inicio del bucle
end_init:
    addi x10 x8 128       # 10. Argumento 1 para sum_array puntero al array (a0)
    addi x11 x0 10        # 11. Argumento 2 para sum_array número de elementos (a1)
    jal sum_array        # 12. Llamar a la subrutina sum_array
    addi x5 x8 16         # 13. Puntero a la dirección de memoria 0x10 (t0)
    sw x12 0(x5)           # 14. Almacenar el resultado de la suma (en a2) en 0x10
    addi x6 x0 500        # 15. Cargar 500 en t1 para la comparación
    or x7 x6 x12         # 16. t2 = (500 < suma) ? 1 else 0
    addi x5 x8 20         # 17. Puntero a la dirección de memoria 0x14 (t0)
    sw x7 0(x5)            # 18. Almacenar el resultado de la comparación en 0x14
    addi x28 x0 240       # 19. Cargar 0xF0 en t3
    addi x29 x0 15        # 20. Cargar 0x0F en t4
    xor x5 x28 x29        # 21. t0 = t3 ^ t4 (debería ser 0xFF)
    and x6 x28 x29        # 22. t1 = t3 & t4 (debería ser 0x00)
    or x7 x28 x29         # 23. t2 = t3 | t4 (debería ser 0xFF)
halt:
    j halt            # 24. Bucle infinito para detener la ejecución
    nop                     # 25.
    nop                     # 26.
    nop                     # 27.
    nop                     # 28.
    nop                     # 25.
    nop                     # 26.
    nop                     # 27.
    nop                     # 28.
# Subroutine sum_array
# Suma los elementos de un array.
# Argumentos  a0 (x10) = puntero al array, a1 (x11) = número de elementos.
# Retorno  a2 (x12) = suma total.
sum_array:
    add x5 x10 x0         # 29. t0 = a0 (copia del puntero)
    add x6 x11 x0         # 30. t1 = a1 (copia del contador)
    addi x12 x0 0         # 31. a2 = 0 (inicializar suma)
sum_loop:
    beq x6 x0 end_sum     # 32. Si el contador es 0, fin del bucle
    lw x7 0(x5)            # 33. t2 = *t0 (cargar elemento del array)
    add x12 x12 x7        # 34. a2 += t2 (sumar al total)
    addi x5 x5 4          # 35. Avanzar puntero
    addi x6 x6 -1         # 36. Decrementar contador
    j sum_loop        # 37. Volver al inicio del bucle
end_sum:
    jalr x0 0        # 38. Retornar de la subrutina
"""
# asm_code = reemplazar_registros_abi(asm_code)

cnv = AssemblyConverter(hex_mode=True, output_mode='a')
machine_code = cnv(asm_code2)  # Esto devuelve lista de (line_number, instruction_object)

# Array de bytes final
program_bytes = []

for h in machine_code:
    # Convertir string hexadecimal a entero
    instr_int = int(h, 16)
    
    # Convertir a 4 bytes little-endian y añadirlos al array
    program_bytes.extend(instr_int.to_bytes(4, byteorder='little'))

# Imprimir en formato tipo Python, sin comillas
print("PROGRAM_D = bytes([")
print("    " + ", ".join(f"0x{b:02x}" for b in program_bytes))
print("])")