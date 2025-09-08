#include "Config.h"
#include <vector>
#include <cstddef>
#include <cstdint>
#include "CoreExport.h"

class SIMULATOR_API Memory {
public:
    // Inicializa la memoria con un tamaño dado en bytes.
    Memory(size_t size_in_bytes);

    // Lee 32 bits (una palabra) de una dirección de memoria.
    uint32_t read_word(uint32_t address,bool cyclic=false);

    // Escribe 32 bits (una palabra) en una dirección de memoria.
    void write_word(uint32_t address, uint32_t value,bool cyclic=false);

    // Carga un programa (un vector de bytes) en la memoria en una dirección base.
    void load_program(const std::vector<uint8_t>& program, uint32_t base_address);

    // Lee un bloque de memoria. Usado por la caché para manejar fallos.
    void read_block(uint32_t base_address, std::vector<uint8_t>& buffer);

    void clear();
    

    void set_delay(uint32_t new_delay) { delay = new_delay; }

    uint32_t get_delay() const { return delay; }

    // Devuelve una referencia constante al vector de datos interno.
    const std::vector<uint8_t>& get_data() const { return mem; }

private:
    uint32_t delay=DELAY_MEMORY;

private:
    std::vector<uint8_t> mem;
};
