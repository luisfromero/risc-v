#include <array>
#include <cstdint>
#include "CoreExport.h"

class SIMULATOR_API RegisterFile {
public:
    RegisterFile();

    // Lee el valor de un registro.
    // El registro x0 siempre debe devolver 0.
    uint32_t read(uint8_t reg_num) const;

    // Escribe un valor en un registro.
    // No se debe poder escribir en el registro x0.
    void write(uint8_t reg_num, uint32_t value);

private:
    // x0 a x31
    std::array<uint32_t, 32> regs;
};
