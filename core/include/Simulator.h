#include "Memory.h"
#include "RegisterFile.h"
#include <cstdint>
#include <vector>
#include "CoreExport.h"

class SIMULATOR_API Simulator {
public:
    Simulator(size_t mem_size);

    // Carga un programa en la memoria.
    void load_program(const std::vector<uint8_t>& program);

    // Ejecuta un solo ciclo de instrucción.
    void step();

    // Devuelve el estado actual para la API.
    // (Podemos hacerlo más complejo después)
    uint32_t get_pc() const;
    const RegisterFile& get_registers() const;

private:
    uint32_t pc; // Program Counter
    Memory memory;
    RegisterFile register_file;

    // Funciones privadas para el ciclo
    uint32_t fetch();
    void decode_and_execute(uint32_t instruction);
};
