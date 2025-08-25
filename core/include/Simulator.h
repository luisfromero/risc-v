#include "Memory.h"
#include "RegisterFile.h"
#include "Cache.h"
#include <cstdint>
#include <string>
#include <fstream>
#include <vector>
#include "Mux.h"
#include "Adder.h"
#include "ALU.h"
#include "SignExtender.h"
#include "ControlUnit.h"
#include "CoreTypes.h"
#include "CoreExport.h"

// Estructura para guardar una "instantánea" del estado del simulador.
struct StateSnapshot {
    uint32_t pc;
    RegisterFile register_file; // Copia completa del banco de registros
    DatapathState datapath;     // Copia completa del estado del datapath
    uint32_t current_cycle;
    std::string instructionString;
    Memory d_mem;               // Copia de la memoria de datos

    // Constructor explícito para inicializar todos los miembros.
    // Necesario porque Memory no tiene un constructor por defecto.
    StateSnapshot(uint32_t p, const RegisterFile& rf, const DatapathState& dp, uint32_t cc, const std::string& is, const Memory& dm)
        : pc(p), register_file(rf), datapath(dp), current_cycle(cc), instructionString(is), d_mem(dm) {}

    // Constructor por defecto para que std::vector pueda manejarlo.
    // Inicializamos d_mem con un tamaño por defecto (256, como en el simulador).
    StateSnapshot() : d_mem(256) {}
};


class SIMULATOR_API Simulator {
public:
    // El constructor ahora acepta un modelo de pipeline.
    Simulator(size_t mem_size, PipelineModel model = PipelineModel::SingleCycle);

    // Carga un programa en la memoria.
    void load_program(const std::vector<uint8_t>& program, PipelineModel model = PipelineModel::SingleCycle );

    // Ejecuta un solo ciclo de instrucción.
    void step();

    // Retrocede un ciclo en la simulación.
    void step_back();

    void reset(PipelineModel model = PipelineModel::SingleCycle);
    
    // Devuelve el estado actual para la API.
    uint32_t get_pc() const;
    uint32_t get_status_register() const;
    DatapathState get_datapath_state() const;
    std::string get_instruction_string() const;
    
    const RegisterFile& get_registers() const;

    // Devuelve el contenido de la memoria de datos (para modo didáctico).
    const std::vector<uint8_t>& get_d_mem() const;
    std::vector<std::pair<uint32_t, std::string>> Simulator::get_i_mem()  ;
private:
    uint32_t pc; // Program Counter
    uint32_t pc_delay=1; 
    uint32_t criticalTime=0;
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

    int total_micro_cycles=5;
    






    // Funciones privadas para el ciclo
    uint32_t fetch();
    void decode_and_execute(uint32_t instruction);
    void simulate_single_cycle(uint32_t instruction);
    void simulate_multi_cycle(uint32_t instruction);
    void simulate_pipeline(uint32_t instruction);

    std::string disassemble(uint32_t instruction, const InstructionInfo* info) const;
    std::string instructionString ="nop";

    // --- Historial para rebobinado ---
    std::vector<StateSnapshot> history;
    size_t history_pointer;

    // --- Tabla de decodificación ---
    // La estructura y la tabla se mueven dentro de la clase para que tengan
    // acceso a los miembros privados.
    struct InstructionFormat {
        uint32_t mask;
        uint32_t match;
        void (Simulator::*execute)(uint32_t);
    };

};
