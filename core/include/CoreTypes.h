#pragma once

#include <cstdint>
#include <string>
#define INDETERMINADO 0x00FABADA

// Modos de pipeline para configurar el simulador
enum class PipelineModel {
    SingleCycle = 0,  // Modelo didáctico monociclo con memorias separadas
    MultiCycle = 1,     // Modelo multiciclo con memorias separadas
    PipeLined = 2,     // Modelo segmentado 
    General = 3        // Modelo general con cachés. Simula risc-v sin microarquitectura
};

template<typename T>
struct Signal {
    T value;
    uint32_t ready_at; // En ciclos de reloj
    bool is_active=true;
};



struct InstructionInfo {
    std::string instr; // Mnemónico
    uint8_t PCsrc;     // 0 = pc+4, 1 = salto, 2 reg
    uint8_t BRwr;      // 1 = escribir en reg
    uint8_t ALUsrc;    // 0 = reg, 1 = inm
    uint8_t ALUctr;    // 3 bits para la ALU (según tu tabla de ALU)
    uint8_t MemWr;     // 1=escribir en MEM
    uint8_t ResSrc;    // 0=ALU, 1=MEM, 2=PC+4
    uint8_t ImmSrc;    // 0=I, 1=S, 2=B, 3=J
    uint32_t mask;
    uint32_t value;
    char type;
    
};




struct DatapathState {
    // --- Ciclo de instrucción ---
    Signal<uint32_t> bus_PC;             // Contenido actual del Program Counter (PC)
    Signal<uint32_t> bus_Instr;          // Instrucción actual (salida de Memoria Instrucciones)

    // --- Decodificación de campos ---
    Signal<uint8_t>  bus_Opcode;         // opcode [6:0]
    Signal<uint8_t>  bus_funct3;         // funct3 [14:12]
    Signal<uint8_t>  bus_funct7;         // funct7 [31:25]
    Signal<uint8_t>  bus_DA;             // rs1 [19:15]
    Signal<uint8_t>  bus_DB;             // rs2 [24:20]
    Signal<uint8_t>  bus_DC;             // rd [11:7]

    // --- Lectura de registros e inmediatos ---
    Signal<uint32_t> bus_A;              // valor leído del registro rs1
    Signal<uint32_t> bus_B;              // valor leído del registro rs2
    Signal<uint32_t> bus_imm;            // inmediato sin extender
    Signal<uint32_t> bus_immExt;         // inmediato extendido según tipo

    // --- ALU ---
    Signal<uint32_t> bus_ALU_A;          // Entrada A de la ALU
    Signal<uint32_t> bus_ALU_B;          // Entrada B de la ALU
    Signal<uint32_t> bus_ALU_result;     // Resultado de la ALU
    Signal<bool>     bus_ALU_zero;       // Bandera zero

    // --- Unidad de control ---
    Signal<uint16_t> bus_Control;        // Palabra de control (como combinación de señales)
    Signal<uint8_t> bus_PCsrc;        // Palabra de control (como combinación de señales)
    

    // --- Memoria de datos ---
    Signal<uint32_t> bus_Mem_address;    // Dirección de acceso a memoria
    Signal<uint32_t> bus_Mem_write_data; // Datos a escribir
    Signal<uint32_t> bus_Mem_read_data;  // Datos leídos

    // --- Resultado final ---
    Signal<uint32_t> bus_C;              // Resultado final a escribir en rd

    // --- Cálculo de siguiente PC ---
    Signal<uint32_t> bus_PC_plus4;       // PC + 4
    Signal<uint32_t> bus_PC_dest;        // Dirección destino de salto (PC + desplazamiento)
    Signal<uint32_t> bus_PC_next;        // Valor final de PC

    Signal<bool>     bus_branch_taken;   // ¿Se tomó un salto condicional?
    uint32_t criticalTime;
    std::string instruction;
    

};