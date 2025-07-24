#include "Simulator.h"
#include <iostream> // Para depuración, se puede quitar después
#include <stdexcept>

// Constructor: Inicializa los componentes del simulador.
Simulator::Simulator(size_t mem_size)
    : pc(0), memory(mem_size), register_file() {
    // El PC se inicializa en 0.
    // La memoria se inicializa con el tamaño dado.
    // El banco de registros se inicializa con su constructor por defecto.
}

// Carga un programa en la memoria del simulador.
void Simulator::load_program(const std::vector<uint8_t>& program) {
    // Cargamos el programa en la dirección base 0 de la memoria.
    memory.load_program(program, 0);
}

// Ejecuta un ciclo completo: fetch, decode, execute.
void Simulator::step() {
    uint32_t instruction = fetch();
    decode_and_execute(instruction);
}

// Devuelve el valor actual del Program Counter.
uint32_t Simulator::get_pc() const {
    return pc;
}

// Devuelve una referencia constante al banco de registros.
const RegisterFile& Simulator::get_registers() const {
    return register_file;
}

// Fase de Fetch: Lee la siguiente instrucción de la memoria.
uint32_t Simulator::fetch() {
    // Lee una palabra de 32 bits (4 bytes) de la memoria en la dirección del PC.
    return memory.read_word(pc);
}

// Fase de Decode y Execute: Interpreta y ejecuta la instrucción.
void Simulator::decode_and_execute(uint32_t instruction) {
    uint32_t opcode = instruction & 0x7F; // bits 0-6

    switch (opcode) {
    case 0x13: { // ADDI (I-Type)
        uint32_t funct3 = (instruction >> 12) & 0x7;
        if (funct3 == 0x0) { // ADDI
            uint32_t rd = (instruction >> 7) & 0x1F;
            uint32_t rs1 = (instruction >> 15) & 0x1F;
            int32_t imm = static_cast<int32_t>(instruction) >> 20; // Extensión de signo
            uint32_t rs1_val = register_file.read(rs1);
            register_file.write(rd, rs1_val + imm);
        }
        break;
    }
    case 0x33: { // ADD (R-Type)
        uint32_t funct3 = (instruction >> 12) & 0x7;
        uint32_t funct7 = (instruction >> 25) & 0x7F;
        if (funct3 == 0x0 && funct7 == 0x0) { // ADD
            uint32_t rd = (instruction >> 7) & 0x1F;
            uint32_t rs1 = (instruction >> 15) & 0x1F;
            uint32_t rs2 = (instruction >> 20) & 0x1F;
            uint32_t rs1_val = register_file.read(rs1);
            uint32_t rs2_val = register_file.read(rs2);
            register_file.write(rd, rs1_val + rs2_val);
        }
        break;
    }
    default:
        // Instrucción no reconocida o no implementada
        std::cerr << "Instrucción no reconocida: 0x" << std::hex << instruction << std::endl;
        break;
    }

    pc += 4;
}
