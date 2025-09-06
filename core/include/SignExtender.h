#pragma once

#include <cstdint>
#include "Config.h"
#include "CoreExport.h"

/**
 * @class SignExtender
 * @brief Componente combinacional que extiende el signo de los inmediatos de RISC-V.
 *
 * Este componente toma la instrucción completa de 32 bits y una señal de control
 * de 2 bits (sExt) para generar el valor inmediato de 32 bits correspondiente,
 * con el signo extendido según el tipo de instrucción (I, S, B, J).
 */

class SIMULATOR_API SignExtender {
public:
    SignExtender() = default;
    /**
     * @brief Extrae y extiende el signo del inmediato de una instrucción.
     * @param instr La instrucción completa de 32 bits.
     * @param sExt Señal de control que indica el formato del inmediato.
     * @return El inmediato de 32 bits con el signo extendido.
     */
    uint32_t  extender(uint32_t instr, uint8_t sExt);
    void set_delay(uint32_t new_delay) { delay = new_delay; }
    uint32_t get_delay() const { return delay; }

private:
    uint32_t delay=DELAY_IMM_EXT;

};
