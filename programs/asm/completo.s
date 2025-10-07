main:
    addi x23 x0 7         # 1. Contador para el bucle de inicialización (3 elementos)
	addi x14 x23 9			# Instrucciones para probar dependencias
	add x15 x23 x23			# Dependencia 2
	sw x14, 4(x14)          # La direccion efectiva es 20 (x14), el dato es 16 (0x10)
	lw x18, 20(x0)          # Ambigüedad de memoria
    addi x9 x18 -13         # 1. Contador para el bucle de inicialización (3 elementos)
	beq x18 x14 4
    add x8 x0 x0   
    addi x18 x0 10        # 2. Valor inicial a almacenar en el array
    addi x19 x8 128       # 3. Puntero al inicio del array (dirección 0x80)
init_loop:
    beq x9 x0 end_init    # 4. Si el contador es 0 fin del bucle
    sw x18 0(x19)          # 5. Almacenar el valor en la dirección actual del array
    addi x18 x18 10       # 6. Incrementar el valor a almacenar
    addi x19 x19 4        # 7. Avanzar el puntero del array al siguiente elemento
    addi x9 x9 -1         # 8. Decrementar el contador
    jal x0 init_loop       # 9. Volver al inicio del bucle
end_init:
    addi x10 x8 128       # 10. Argumento 1 para sum_array puntero al array (a0)
    addi x11 x0 3        # 11. Argumento 2 para sum_array número de elementos (a1)
    jal x1 sum_array       # 12. Llamar a la subrutina sum_array
    addi x5 x8 16         # 13. Puntero a la dirección de memoria 0x10 (t0)
    sw x12 0(x5)           # 14. Almacenar el resultado de la suma (en a2) en 0x10
    addi x6 x0 500        # 15. Cargar 500 en t1 para la comparación
    slt x7 x6 x12         # 16. t2 = (500 < suma) ? 1 else 0
    addi x5 x8 20         # 17. Puntero a la dirección de memoria 0x14 (t0)
    sw x7 0(x5)            # 18. Almacenar el resultado de la comparación en 0x14
    addi x28 x0 240       # 19. Cargar 0xF0 en t3
    addi x29 x0 15        # 20. Cargar 0x0F en t4
    xor x5 x28 x29        # 21. t0 = t3 ^ t4 (debería ser 0xFF)
    and x6 x28 x29        # 22. t1 = t3 & t4 (debería ser 0x00)
    or x7 x28 x29         # 23. t2 = t3 | t4 (debería ser 0xFF)
halt:
    jal x0 halt            # 24. Bucle infinito para detener la ejecución
# Padding para alinear la subrutina
    nop                     # 26.
# Subroutine sum_array
# Suma los elementos de un array.
# Argumentos  a0 (x10) = puntero al array, a1 (x11) = número de elementos.
# Retorno a2 (x12) = suma total.
sum_array:
    add x6 x11 x0         # 30. t1 = a1 (copia del contador)
    add x5 x10 x0         # 29. t0 = a0 (copia del puntero)
    addi x12 x0 0         # 31. a2 = 0 (inicializar suma)
sum_loop:
    beq x6 x0 end_sum     # 32. Si el contador es 0, fin del bucle
    lw x7 0(x5)            # 33. t2 = *t0 (cargar elemento del array)
    add x12 x12 x7        # 34. a2 += t2 (sumar al total)
    addi x6 x6 -1         # 36. Decrementar contador
    addi x5 x5 4          # 35. Avanzar puntero
    jal x0 sum_loop        # 37. Volver al inicio del bucle
end_sum:
    jalr x0 x1 0          # 38. Retornar de la subrutina