#include "Memory.h"
#include "RegisterFile.h"
#include "Cache.h"
#include <cstdint>
#include <fstream>
#include <vector>
#include "Mux.h"
#include "Adder.h"
#include "ALU.h"
#include "SignExtender.h"
#include "ControlUnit.h"
#include "CoreTypes.h"
#include "CoreExport.h"

class SIMULATOR_API Simulator {
public:
    // El constructor ahora acepta un modelo de pipeline.
    Simulator(size_t mem_size, PipelineModel model = PipelineModel::General);

    // Carga un programa en la memoria.
    void load_program(const std::vector<uint8_t>& program);

    // Ejecuta un solo ciclo de instrucción.
    void step();

    // Devuelve el estado actual para la API.
    uint32_t get_pc() const;
    uint32_t get_status_register() const;
    DatapathState get_datapath_state() const;
    std::string get_instruction_string() const;
    
    const RegisterFile& get_registers() const;

private:
    uint32_t pc; // Program Counter
    uint32_t status_reg;
    DatapathState datapath;   // Estado actual del datapath (todas las señales con valor + ready_at)
    uint32_t current_cycle;   // Ciclo actual de simulación (tiempo absoluto tipo reloj de pared)
    std::ofstream m_logfile;  // Fichero para el log
    RegisterFile register_file;
    PipelineModel model;

    // Componentes para el modo General (con cachés)
    Memory memory; // Memoria principal unificada
    InstructionCache i_cache;
    DataCache d_cache;

    // Componentes para el modo SingleCycle (didáctico)
    Memory i_mem; // Memoria de instrucciones de 256 bytes
    Memory d_mem; // Memoria de datos de 256 bytes

    // --- Unidades funcionales ---
    Mux2 mux_PC;
    Mux2 mux_B;
    Mux4 mux_C;
    SignExtender sign_extender;
    Adder adder;
    ALU alu;
    Adder4 adder4;
    ControlUnit control_unit;









    // Funciones privadas para el ciclo
    uint32_t fetch();
    void decode_and_execute(uint32_t instruction);
    std::string disassemble(uint32_t instruction, const InstructionInfo* info) const;
    std::string instructionString ="nop";

    // --- Tabla de decodificación ---
    // La estructura y la tabla se mueven dentro de la clase para que tengan
    // acceso a los miembros privados.
    struct InstructionFormat {
        uint32_t mask;
        uint32_t match;
        void (Simulator::*execute)(uint32_t);
    };

};
