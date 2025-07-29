#pragma once

#include <cstdint>
#include "CoreExport.h"

/**
 * @class Adder
 * @brief Componente combinacional que suma dos números de 32 bits.
 */
class SIMULATOR_API ALU {
public:
    ALU() = default;
    void set_delay(uint32_t new_delay) { delay = new_delay; }
    uint32_t get_delay() const { return delay; }

    /**
     * @brief Realiza la suma de dos operandos de 32 bits.
     * @param a Primer operando.
     * @param b Segundo operando.
     * @return La suma de a y b.
     */
    uint32_t calc(uint32_t a, uint32_t b, uint8_t funct3);

private:
    uint32_t delay=20;
};

/*


*/