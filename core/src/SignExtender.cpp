#include "SignExtender.h"
#include "CoreTypes.h"

uint32_t SignExtender::extender(uint32_t instr, uint8_t sExt)
{
    uint32_t immediate = 0;

    switch (sExt) {
        case 0b00: { // I-type (ADDI, LW, JALR, etc.)
            // El inmediato son los bits instr[31:20].
            // El casteo a int32_t asegura un desplazamiento aritmético (extiende el signo).
            immediate = static_cast<uint32_t>(static_cast<int32_t>(instr) >> 20);
            break;
        }

        case 0b01: { // S-type (SW, SH, SB)
            // El inmediato se construye con {instr[31:25], instr[11:7]}
            const uint32_t imm11_5 = (instr >> 25) & 0x7F;
            const uint32_t imm4_0  = (instr >> 7)  & 0x1F;
            uint32_t imm_s   = (imm11_5 << 5) | imm4_0;

            // Extender signo desde 12 bits
            if (imm_s & 0x800) { // Si el bit 11 (el bit de signo) está activo
                imm_s |= 0xFFFFF000;
            }
            immediate = imm_s;
            break;
        }

        case 0b10: { // B-type (Branches: BEQ, BNE, etc.)
            // El inmediato de 13 bits se forma con {instr[31], instr[7], instr[30:25], instr[11:8]}
            // y se desplaza 1 bit a la izquierda (el bit 0 es implícito y siempre 0).
            const uint32_t imm12   = (instr >> 19) & 0x1000; // bit 31 -> bit 12
            const uint32_t imm11   = (instr << 4)  & 0x800;  // bit 7  -> bit 11
            const uint32_t imm10_5 = (instr >> 20) & 0x7E0;  // bits 30:25 -> 10:5
            const uint32_t imm4_1  = (instr >> 7)  & 0x1E;   // bits 11:8  -> 4:1
            uint32_t imm_b   = imm12 | imm11 | imm10_5 | imm4_1;

            // Extender signo desde el bit 12
            if (imm_b & 0x1000) {
                imm_b |= 0xFFFFE000;
            }
            immediate = imm_b;
            break;
        }

        case 0b11: { // J-type (JAL)
            // El inmediato de 21 bits se forma con {instr[31], instr[19:12], instr[20], instr[30:21]}
            // y se desplaza 1 bit a la izquierda.
            const uint32_t imm20    = (instr >> 11) & 0x100000; // bit 31 -> bit 20
            const uint32_t imm19_12 = instr & 0xFF000;          // bits 19:12
            const uint32_t imm11    = (instr >> 9)  & 0x800;    // bit 20 -> bit 11
            const uint32_t imm10_1  = (instr >> 20) & 0x7FE;    // bits 30:21 -> 10:1
            uint32_t imm_j    = imm20 | imm19_12 | imm11 | imm10_1;

            // Extender signo desde el bit 20
            if (imm_j & 0x100000) {
                imm_j |= 0xFFE00000;
            }
            immediate = imm_j;
            break;
        }

        case 4: { // U-type (LUI)
            // El inmediato son los bits instr[31:12], los 12 bits inferiores son 0.
            immediate = instr & 0xFFFFF000;
            break;
        }

        default: {
            // Caso por defecto. En una implementación correcta, la unidad de control
            // nunca debería generar un valor de sExt no válido. Puedo poner deadbeef para -1
            immediate = INDETERMINADO;
            break;
        }
    }
    return immediate;
}
