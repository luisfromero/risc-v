#pragma once

#include <cstdint>
#include <string>

// Modos de pipeline para configurar el simulador
enum class PipelineModel {
    SingleCycle = 0,  // Modelo didáctico monociclo con memorias separadas
    PipeLined = 1,     // Modelo segmentado 
    MultiCycle = 2,     // Modelo multiciclo con memorias separadas
    General = 3        // Modelo general con cachés. Simula risc-v sin microarquitectura
};

template<typename T>
struct Signal {
    T value;
    uint32_t ready_at=1; // En ciclos de reloj
    uint8_t is_active=1; // Usamos uint8_t para garantizar un tamaño de 1 byte
};



struct InstructionInfo {
    std::string instr; // Mnemónico
    uint8_t PCsrc;     // 0 = pc+4, 1 = salto, 2 reg
    uint8_t BRwr;      // 1 = escribir en reg
    uint8_t ALUsrc;    // 0 = reg, 1 = inm  posiblemente ampliable ¿cortocircuito?
    uint8_t ALUctr;    // 3 bits para la ALU (según tu tabla de ALU)
    uint8_t MemWr;     // 1=escribir en MEM
    uint8_t ResSrc;    // 0=ALU, 1=MEM, 2=PC+4
    uint8_t ImmSrc;    // 0=I, 1=S, 2=B, 3=J
    uint32_t mask;
    uint32_t value;
    char type;
    uint8_t cycles;  // Número de ciclos para el modo multiciclo
    uint16_t controlWord;

    
};

// --- Estructuras para los Registros de Segmentación (Pipeline) ---
// Contienen los datos que se almacenan entre etapas.

struct IF_ID_Register {
    uint32_t instr = 0;
    uint32_t npc = 0; // Next PC (PC+4)
};

struct ID_EX_Register {
    uint16_t control = 0;
    uint32_t pc_plus_4 = 0;
    uint32_t a = 0;
    uint32_t b = 0;
    uint32_t imm = 0;
    uint8_t rs1 = 0;
    uint8_t rs2 = 0;
    uint8_t rd = 0;
};

struct EX_MEM_Register {
    uint16_t control = 0;
    uint32_t alu_result = 0;
    uint32_t b = 0;
    uint8_t rd = 0;
    bool alu_zero = false;
    uint32_t branch_target = 0;
};

struct MEM_WB_Register {
    uint16_t control = 0;
    uint32_t mem_read_data = 0;
    uint32_t alu_result = 0;
    uint8_t rd = 0;
};





struct DatapathState {
    // --- Ciclo de instrucción ---
    Signal<uint32_t> bus_PC;             // Contenido actual del Program Counter (PC)
    Signal<uint32_t> bus_Instr;          // Instrucción actual (salida de Memoria Instrucciones)

    // --- Decodificación de campos ---
    Signal<uint8_t>  bus_opcode;         // opcode [6:0]
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
    Signal<uint8_t> bus_ALUsrc;        // Palabra de control (como combinación de señales)
    Signal<uint8_t> bus_ResSrc;        // Palabra de control (como combinación de señales)
    Signal<uint8_t> bus_ALUctr;        // Palabra de control (como combinación de señales)
    Signal<uint8_t> bus_ImmSrc;        // Palabra de control (como combinación de señales)
    Signal<uint8_t> bus_BRwr;        // Palabra de control (como combinación de señales)
    Signal<uint8_t> bus_MemWr;        // Palabra de control (como combinación de señales)

    

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

    Signal<bool>     bus_branch_taken;   // Se ha tomado una dirección diferente a PC+4 (rg+imm o PC+imm)
    
    uint32_t criticalTime;
    uint32_t total_micro_cycles;
    //std::string instruction;
    char instruction_cptr[256];

    // --- Buses de Salida de los Registros de Segmentación ---

    char Pipe_IF_instruction_cptr[256];
    char Pipe_ID_instruction_cptr[256];
    char Pipe_EX_instruction_cptr[256];
    char Pipe_MEM_instruction_cptr[256];
    char Pipe_WB_instruction_cptr[256];

    uint32_t Pipe_IF_instruction=0x00000013;
    uint32_t Pipe_ID_instruction=0x00000013;
    uint32_t Pipe_EX_instruction=0x00000013;
    uint32_t Pipe_MEM_instruction=0x00000013;
    uint32_t Pipe_WB_instruction=0x00000013;




    // IF/ID Stage
    Signal<uint32_t> Pipe_IF_ID_NPC; // PC + 4
    Signal<uint32_t> Pipe_IF_ID_NPC_out; // Valor en salida
    Signal<uint32_t> Pipe_IF_ID_Instr;
    Signal<uint32_t> Pipe_IF_ID_Instr_out;
    Signal<uint32_t> Pipe_IF_ID_PC;
    Signal<uint32_t> Pipe_IF_ID_PC_out;

    // ID/EX Stage
    Signal<uint16_t> Pipe_ID_EX_Control;
    Signal<uint16_t> Pipe_ID_EX_Control_out;
    Signal<uint32_t> Pipe_ID_EX_NPC; // PC + 4
    Signal<uint32_t> Pipe_ID_EX_NPC_out;
    Signal<uint32_t> Pipe_ID_EX_A;
    Signal<uint32_t> Pipe_ID_EX_A_out;
    Signal<uint32_t> Pipe_ID_EX_B;
    Signal<uint32_t> Pipe_ID_EX_B_out;
    Signal<uint8_t>  Pipe_ID_EX_RD; // Nombre registro destino
    Signal<uint8_t>  Pipe_ID_EX_RD_out;
    Signal<uint8_t>  Pipe_ID_EX_RS1; // Nombre registro origen1 (para forwarding)
    Signal<uint8_t>  Pipe_ID_EX_RS1_out;
    Signal<uint8_t>  Pipe_ID_EX_RS2; // Nombre registro origen2 (para forwarding)
    Signal<uint8_t>  Pipe_ID_EX_RS2_out;
    Signal<uint32_t> Pipe_ID_EX_Imm; // Inmediato extendido
    Signal<uint32_t> Pipe_ID_EX_Imm_out;
    Signal<uint32_t> Pipe_ID_EX_PC;
    Signal<uint32_t> Pipe_ID_EX_PC_out;

    // EX/MEM Stage
    Signal<uint16_t> Pipe_EX_MEM_Control;
    Signal<uint16_t> Pipe_EX_MEM_Control_out;
    Signal<uint32_t> Pipe_EX_MEM_NPC; // PC + 4
    Signal<uint32_t> Pipe_EX_MEM_NPC_out;
    Signal<uint32_t> Pipe_EX_MEM_ALU_result;
    Signal<uint32_t> Pipe_EX_MEM_ALU_result_out;
    Signal<uint32_t> Pipe_EX_MEM_B;
    Signal<uint32_t> Pipe_EX_MEM_B_out;
    Signal<uint8_t>  Pipe_EX_MEM_RD; // Nombre registro destino
    Signal<uint8_t>  Pipe_EX_MEM_RD_out;

    // MEM/WB Stage
    Signal<uint16_t> Pipe_MEM_WB_Control; 
    Signal<uint16_t> Pipe_MEM_WB_Control_out;
    Signal<uint32_t> Pipe_MEM_WB_NPC;  // PC + 4
    Signal<uint32_t> Pipe_MEM_WB_NPC_out;
    Signal<uint32_t> Pipe_MEM_WB_ALU_result; 
    Signal<uint32_t> Pipe_MEM_WB_ALU_result_out;
    Signal<uint32_t> Pipe_MEM_WB_RM; // Memoria
    Signal<uint32_t> Pipe_MEM_WB_RM_out;
    Signal<uint8_t> Pipe_MEM_WB_RD; // Nombre registro destino
    Signal<uint8_t> Pipe_MEM_WB_RD_out;

    Signal<bool> bus_stall; // Indica si se debe detener el pipeline
    Signal<bool> bus_flush; // Indica si se debe limpiar el pipeline

    // --- Señales para Cortocircuitos (Forwarding) ---
    Signal<uint8_t> bus_ControlForwardA; // Control para el Mux de Forwarding A (01: normal, 00: EX/MEM, 10: MEM/WB)
    Signal<uint8_t> bus_ControlForwardB; // Control para el Mux de Forwarding B
    Signal<uint32_t> bus_ForwardA; // Salida de forward a, si existe (entrada alu a)
    Signal<uint32_t> bus_ForwardB; // Salida de forward b, si existe (entrada alu b)

};