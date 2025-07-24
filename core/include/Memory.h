#include <vector>
#include <cstdint>
#include "CoreExport.h"

class SIMULATOR_API Memory {
public:
    // Inicializa la memoria con un tamaño dado en bytes.
    Memory(size_t size_in_bytes);

    // Lee 32 bits (una palabra) de una dirección de memoria.
    uint32_t read_word(uint32_t address);

    // Escribe 32 bits (una palabra) en una dirección de memoria.
    void write_word(uint32_t address, uint32_t value);

    // Carga un programa (un vector de bytes) en la memoria en una dirección base.
    void load_program(const std::vector<uint8_t>& program, uint32_t base_address);

private:
    std::vector<uint8_t> mem;
};
