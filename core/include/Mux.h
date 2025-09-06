#pragma once

#include <cstdint>
#include "Config.h"
#include "CoreExport.h"
#include "CoreTypes.h"

// Clase base abstracta para un multiplexor.
class SIMULATOR_API Mux {
public:
    virtual ~Mux() = default;
    uint32_t get_output() const { return output; }
        void set_delay(uint32_t new_delay) { delay = new_delay; }
        uint32_t get_delay() const { return delay; }

private:
    uint32_t delay=DELAY_MUXES;

protected:
    uint32_t output = 0;
};

// Multiplexor de 2 entradas a 1 salida.
class SIMULATOR_API Mux2 : public Mux {
public:
    uint32_t select(uint32_t in0, uint32_t in1, bool sel);
};

// Multiplexor de 4 entradas a 1 salida.
class SIMULATOR_API Mux4 : public Mux {
public:
    // sel es un valor de 2 bits (0 a 3)
    uint32_t select(uint32_t in0, uint32_t in1, uint32_t in2, uint32_t in3, uint8_t sel);
};