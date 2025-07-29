#pragma once

#include <cstdint>
#include <vector>
#include "CoreExport.h"

// Declaración anticipada para evitar dependencia circular de cabeceras.
class Memory;

struct CacheLine {
    bool valid = false;
    uint32_t tag = 0;
    std::vector<uint8_t> data; // Bloque de datos

    CacheLine(size_t block_size);
};

// Clase base para una caché.
// Implementa una caché de mapeo directo con una política de escritura
// "write-through" y "no-write-allocate".
class SIMULATOR_API Cache {
public:
    // El destructor virtual es crucial para las clases base.
    virtual ~Cache() = default;

    virtual uint32_t read_word(uint32_t address);
    virtual void write_word(uint32_t address, uint32_t value);

protected:
    // El constructor es protegido para que solo las clases derivadas puedan llamarlo.
    Cache(size_t cache_size, size_t block_size, Memory& main_memory);

    size_t block_size;
    size_t num_lines;
    Memory& memory; // Referencia a la memoria principal para fallos de caché
    std::vector<CacheLine> lines;

private:
    void load_block_from_memory(uint32_t address, uint32_t index, uint32_t tag);
};

// Caché especializada para instrucciones.
class SIMULATOR_API InstructionCache : public Cache {
public:
    InstructionCache(size_t cache_size, size_t block_size, Memory& main_memory);
};

// Caché especializada para datos.
class SIMULATOR_API DataCache : public Cache {
public:
    DataCache(size_t cache_size, size_t block_size, Memory& main_memory);
};