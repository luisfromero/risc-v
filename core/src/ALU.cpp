#include "ALU.h"
#include <cstdint>

uint32_t ALU::calc(uint32_t opA, uint32_t opB, uint8_t funct)
{
    switch(funct) {
        case 0b000: // ADD
            return opA + opB;
        case 0b001: // SUB
            return opA - opB;
        case 0b010: // AND
            return opA & opB;
        case 0b011: // OR
            return opA | opB;
        case 0b100: // SLT
            // SLT debe ser firmado, así que convertimos a int32_t
            return (static_cast<int32_t>(opA) < static_cast<int32_t>(opB)) ? 1 : 0;
        case 0b101: // SRL
            return opA >> (opB & 0x1F); // Solo los 5 bits bajos de opB para el desplazamiento
        case 0b110: // SLL
            return opA << (opB & 0x1F);
        case 0b111: // SRA
            return static_cast<uint32_t>(static_cast<int32_t>(opA) >> (opB & 0x1F));
        default:
            return 0; // Por defecto, regresa 0
    }
}
