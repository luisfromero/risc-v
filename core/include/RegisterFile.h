#include <array>
#include <cstdint>
#include <utility>
#include "CoreExport.h"

class SIMULATOR_API RegisterFile {
public:
    RegisterFile();

    // Lee el valor de un registro.
    // El registro x0 siempre debe devolver 0.
    uint32_t readA(uint8_t reg_num) const;
    uint32_t readB(uint8_t reg_num) const;
    std::pair<uint32_t,uint32_t> read(uint8_t reg_numA,uint8_t reg_numB) const;

    // Escribe un valor en un registro.
    // No se debe poder escribir en el registro x0.
    void write(uint8_t reg_num, uint32_t value);
    void set_write_delay(uint32_t new_delay) { write_delay = new_delay; }
    uint32_t get_write_delay() const { return write_delay; }

    void set_delay(uint32_t new_delay) { delay = new_delay; }
    uint32_t get_delay() const { return delay; }

private:
    uint32_t delay=20;
    uint32_t write_delay=5;
private:
    // x0 a x31
    std::array<uint32_t, 32> regs;
};
