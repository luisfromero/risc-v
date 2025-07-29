#include "Cache.h"
#include "Memory.h" // Se necesita la definición completa para usar sus métodos
#include <stdexcept>
#include <cmath> // Para log2

// --- Implementación de CacheLine ---
CacheLine::CacheLine(size_t block_size) : data(block_size, 0) {}


// --- Funciones de ayuda para la descomposición de direcciones ---
// Se mantienen internas a este fichero.
namespace {
    uint32_t get_tag(uint32_t address, uint32_t offset_bits, uint32_t index_bits) {
        return address >> (offset_bits + index_bits);
    }

    uint32_t get_index(uint32_t address, uint32_t offset_bits, uint32_t num_lines) {
        // Usar (num_lines - 1) como máscara funciona porque num_lines es una potencia de 2.
        return (address >> offset_bits) & (num_lines - 1);
    }
}


// --- Implementación de la Clase Base Cache ---

Cache::Cache(size_t cache_size, size_t block_size, Memory& main_memory)
    : block_size(block_size), memory(main_memory) {
    if (cache_size == 0 || block_size == 0 || (cache_size % block_size) != 0) {
        throw std::invalid_argument("El tamaño de la caché debe ser un múltiplo no nulo del tamaño del bloque.");
    }
    num_lines = cache_size / block_size;
    // El esquema de indexación simple requiere que el número de líneas sea una potencia de 2.
    if ((num_lines & (num_lines - 1)) != 0 && num_lines != 0) {
        throw std::invalid_argument("El número de líneas de la caché debe ser una potencia de 2.");
    }

    lines.reserve(num_lines);
    for(size_t i = 0; i < num_lines; ++i) {
        lines.emplace_back(block_size);
    }
}

void Cache::load_block_from_memory(uint32_t address, uint32_t index, uint32_t tag) {
    // Calcula la dirección de inicio del bloque en la memoria principal.
    uint32_t block_start_address = address & ~(static_cast<uint32_t>(block_size) - 1);
    
    // Lee el bloque completo desde la memoria al buffer de datos de la línea de caché.
    memory.read_block(block_start_address, lines[index].data);
    
    // Actualiza los metadatos de la línea de caché.
    lines[index].valid = true;
    lines[index].tag = tag;
}

uint32_t Cache::read_word(uint32_t address) {
    // Descompone la dirección en tag, índice y offset.
    const uint32_t offset_bits = static_cast<uint32_t>(log2(block_size));
    const uint32_t index_bits = static_cast<uint32_t>(log2(num_lines));

    const uint32_t index = get_index(address, offset_bits, num_lines);
    const uint32_t tag = get_tag(address, offset_bits, index_bits);
    const uint32_t offset = address & (static_cast<uint32_t>(block_size) - 1);

    // Comprueba si hay un acierto de caché (cache hit).
    if (!lines[index].valid || lines[index].tag != tag) {
        // Fallo de caché (cache miss): Carga el bloque necesario desde la memoria principal.
        load_block_from_memory(address, index, tag);
    }

    // Acierto de caché: Ensambla la palabra desde los datos de la línea de caché (little-endian).
    uint32_t word = 0;
    word |= static_cast<uint32_t>(lines[index].data[offset + 0]) << 0;
    word |= static_cast<uint32_t>(lines[index].data[offset + 1]) << 8;
    word |= static_cast<uint32_t>(lines[index].data[offset + 2]) << 16;
    word |= static_cast<uint32_t>(lines[index].data[offset + 3]) << 24;
    return word;
}

void Cache::write_word(uint32_t address, uint32_t value) {
    // Política Write-Through: siempre escribe el dato en la memoria principal.
    memory.write_word(address, value);

    // Ahora, manejamos la caché. Con una política No-Write-Allocate, solo
    // nos importa si hay un acierto de escritura (write hit) para mantener la consistencia.
    const uint32_t offset_bits = static_cast<uint32_t>(log2(block_size));
    const uint32_t index_bits = static_cast<uint32_t>(log2(num_lines));

    const uint32_t index = get_index(address, offset_bits, num_lines);
    const uint32_t tag = get_tag(address, offset_bits, index_bits);
    const uint32_t offset = address & (static_cast<uint32_t>(block_size) - 1);

    // Comprueba si hay un acierto de caché (write hit).
    if (lines[index].valid && lines[index].tag == tag) {
        // Write Hit: Actualiza el dato en la línea de caché.
        lines[index].data[offset + 0] = (value >> 0) & 0xFF;
        lines[index].data[offset + 1] = (value >> 8) & 0xFF;
        lines[index].data[offset + 2] = (value >> 16) & 0xFF;
        lines[index].data[offset + 3] = (value >> 24) & 0xFF;
    }
    // Si es un fallo (write miss), no hacemos nada en la caché (No-Write-Allocate).
}

// --- Implementación de las clases derivadas ---

InstructionCache::InstructionCache(size_t cache_size, size_t block_size, Memory& main_memory)
    : Cache(cache_size, block_size, main_memory) {}

DataCache::DataCache(size_t cache_size, size_t block_size, Memory& main_memory)
    : Cache(cache_size, block_size, main_memory) {}
