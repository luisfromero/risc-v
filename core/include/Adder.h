#pragma once

#include <cstdint>
#include "Config.h"
#include "CoreExport.h"

/**
 * @class Adder
 * @brief Componente combinacional que suma dos números de 32 bits.
 */
class SIMULATOR_API Adder {
public:
    Adder() = default;
    virtual ~Adder() = default;
    void set_delay(uint32_t new_delay) { delay = new_delay; }
    uint32_t get_delay() const { return delay; }

    /**
     * @brief Realiza la suma de dos operandos de 32 bits.
     * @param a Primer operando.
     * @param b Segundo operando.
     * @return La suma de a y b.
     */
    uint32_t add(uint32_t a, uint32_t b);

private:
    uint32_t delay = DELAY_ADDERS;
};

/**
 * @class Adder4
 * @brief Componente especializado que suma 4 a un número de 32 bits.
 *        Pensado para el cálculo de PC + 4.
 */
class SIMULATOR_API Adder4 {
private:
    uint32_t delay = DELAY_ADDERS;
public:
    Adder4() = default;
    uint32_t add(uint32_t val);
    void set_delay(uint32_t new_delay) { delay = new_delay; }
    uint32_t get_delay() const { return delay; }
};