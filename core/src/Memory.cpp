#include "Memory.h"
#include <stdexcept>
#include <algorithm>

// Inicializa la memoria con un tamaño dado y la llena de ceros.
Memory::Memory(size_t size_in_bytes) : mem(size_in_bytes, 0) {}

// Lee 32 bits (una palabra) de una dirección de memoria.
uint32_t Memory::read_word(uint32_t address) {
    if (address + 3 >= mem.size()) {
        throw std::out_of_range("Memory read access out of bounds");
    }
    // Asumimos little-endian, como en RISC-V estándar.
    uint32_t word = 0;
    word |= static_cast<uint32_t>(mem[address + 0]) << 0;
    word |= static_cast<uint32_t>(mem[address + 1]) << 8;
    word |= static_cast<uint32_t>(mem[address + 2]) << 16;
    word |= static_cast<uint32_t>(mem[address + 3]) << 24;
    return word;
}

// Escribe 32 bits (una palabra) en una dirección de memoria.
void Memory::write_word(uint32_t address, uint32_t value) {
    if (address + 3 >= mem.size()) {
        throw std::out_of_range("Memory write access out of bounds");
    }
    mem[address + 0] = (value >> 0) & 0xFF;
    mem[address + 1] = (value >> 8) & 0xFF;
    mem[address + 2] = (value >> 16) & 0xFF;
    mem[address + 3] = (value >> 24) & 0xFF;
}

// Carga un programa (un vector de bytes) en la memoria en una dirección base.
void Memory::load_program(const std::vector<uint8_t>& program, uint32_t base_address) {
    if (base_address + program.size() > mem.size()) {
        throw std::out_of_range("Program does not fit in memory");
    }
    std::copy(program.begin(), program.end(), mem.begin() + base_address);
}

// Lee un bloque de memoria y lo copia en el buffer proporcionado.
void Memory::read_block(uint32_t base_address, std::vector<uint8_t>& buffer) {
    if (base_address + buffer.size() > mem.size()) {
        throw std::out_of_range("Memory block read access out of bounds");
    }
    std::copy(mem.begin() + base_address, mem.begin() + base_address + buffer.size(), buffer.begin());
}