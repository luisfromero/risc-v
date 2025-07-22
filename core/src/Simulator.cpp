// ...

void Simulator::decode_and_execute(uint32_t instruction) {
    // Extraer los campos de la instrucción usando máscaras y desplazamientos de bits.
    uint32_t opcode = instruction & 0x7F; // bits 0-6

    switch (opcode) {
        // Caso para ADDI (I-Type)
        case 0x13: {
            // funct3 para ADDI es 0x0
            uint32_t funct3 = (instruction >> 12) & 0x7;
            if (funct3 == 0x0) {
                // Decodificar operandos para I-Type
                uint32_t rd = (instruction >> 7) & 0x1F;
                uint32_t rs1 = (instruction >> 15) & 0x1F;
                // El inmediato necesita extensión de signo
                int32_t imm = static_cast<int32_t>(instruction) >> 20;

                // Ejecutar
                uint32_t rs1_val = register_file.read(rs1);
                register_file.write(rd, rs1_val + imm);
            }
            // Aquí irían otros if/else para SLTI, XORI, etc.
            break;
        }

        // Caso para ADD (R-Type)
        case 0x33: {
            // funct3 y funct7 para ADD son 0x0
            uint32_t funct3 = (instruction >> 12) & 0x7;
            uint32_t funct7 = (instruction >> 25) & 0x7F;
            if (funct3 == 0x0 && funct7 == 0x0) {
                // Decodificar operandos para R-Type
                uint32_t rd = (instruction >> 7) & 0x1F;
                uint32_t rs1 = (instruction >> 15) & 0x1F;
                uint32_t rs2 = (instruction >> 20) & 0x1F;

                // Ejecutar
                uint32_t rs1_val = register_file.read(rs1);
                uint32_t rs2_val = register_file.read(rs2);
                register_file.write(rd, rs1_val + rs2_val);
            }
            // Aquí irían otros if/else para SUB, SLL, etc.
            break;
        }

        // ... otros opcodes como LW, SW, BEQ ...

        default:
            // Instrucción no reconocida
            break;
    }

    // Por ahora, simplemente incrementamos el PC en 4.
    // Las instrucciones de salto y branch lo modificarán de otra forma.
    pc += 4;
}
