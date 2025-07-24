#include "RegisterFile.h"
#include <stdexcept>

// Constructor: Inicializa todos los registros a 0.
RegisterFile::RegisterFile() {
    regs.fill(0);
}

// Lee el valor de un registro.
uint32_t RegisterFile::read(uint8_t reg_num) const {
    if (reg_num >= 32) {
        throw std::out_of_range("Invalid register number for read operation.");
    }
    return regs[reg_num];
}

// Escribe un valor en un registro.
void RegisterFile::write(uint8_t reg_num, uint32_t value) {
    if (reg_num >= 32) {
        throw std::out_of_range("Invalid register number for write operation.");
    }
    // El registro x0 (índice 0) es cableado a cero y no se puede modificar.
    if (reg_num != 0) {
        regs[reg_num] = value;
    }
}