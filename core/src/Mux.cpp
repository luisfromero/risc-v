#include "Mux.h"
#include <stdexcept>

// --- Mux2 ---
uint32_t Mux2::select(uint32_t in0, uint32_t in1, bool sel) {
    output = sel ? in1 : in0;
    return output;
}

// --- Mux4 ---
uint32_t Mux4::select(uint32_t in0, uint32_t in1, uint32_t in2, uint32_t in3, uint8_t sel) {
    switch (sel) {
        case 0:
            output = in0;
            break;
        case 1:
            output = in1;
            break;
        case 2:
            output = in2;
            break;
        case 3:
            output = in3;
            break;
        default:
            return INDETERMINADO;
            // Opcional: lanzar un error si la señal de control es inválida.
            throw std::invalid_argument("Señal de selección inválida para Mux4.");
    }
    return output;

}