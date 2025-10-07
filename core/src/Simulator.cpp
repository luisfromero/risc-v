#include "Simulator.h"
#include <iostream> // Para depuración, se puede quitar después
#include <stdexcept>
#include <algorithm> // Para std::max
#include <sstream>
#include <vector>
#include "ControlTableData.h" // Para el namespace ControlWord


void copy_pipeline_registers_to_out(DatapathState& datapath) {
    datapath.Pipe_IF_ID_Instr_out=datapath.Pipe_IF_ID_Instr;
    datapath.Pipe_IF_ID_NPC_out=datapath.Pipe_IF_ID_NPC;
    datapath.Pipe_IF_ID_PC_out=datapath.Pipe_IF_ID_PC;
    datapath.Pipe_ID_EX_Control_out=datapath.Pipe_ID_EX_Control;
    datapath.Pipe_ID_EX_NPC_out=datapath.Pipe_ID_EX_NPC;
    datapath.Pipe_ID_EX_PC_out=datapath.Pipe_ID_EX_PC;
    datapath.Pipe_ID_EX_A_out=datapath.Pipe_ID_EX_A;
    datapath.Pipe_ID_EX_B_out=datapath.Pipe_ID_EX_B;
    datapath.Pipe_ID_EX_RD_out=datapath.Pipe_ID_EX_RD;
    datapath.Pipe_ID_EX_RS1_out=datapath.Pipe_ID_EX_RS1;
    datapath.Pipe_ID_EX_RS2_out=datapath.Pipe_ID_EX_RS2;
    datapath.Pipe_ID_EX_Imm_out=datapath.Pipe_ID_EX_Imm;
    datapath.Pipe_EX_MEM_Control_out=datapath.Pipe_EX_MEM_Control;
    datapath.Pipe_EX_MEM_NPC_out=datapath.Pipe_EX_MEM_NPC;
    datapath.Pipe_EX_MEM_ALU_result_out=datapath.Pipe_EX_MEM_ALU_result;
    datapath.Pipe_EX_MEM_B_out=datapath.Pipe_EX_MEM_B;
    datapath.Pipe_EX_MEM_RD_out=datapath.Pipe_EX_MEM_RD;
    datapath.Pipe_MEM_WB_Control_out=datapath.Pipe_MEM_WB_Control;
    datapath.Pipe_MEM_WB_NPC_out=datapath.Pipe_MEM_WB_NPC;
    datapath.Pipe_MEM_WB_ALU_result_out=datapath.Pipe_MEM_WB_ALU_result;
    datapath.Pipe_MEM_WB_RM_out=datapath.Pipe_MEM_WB_RM;
    datapath.Pipe_MEM_WB_RD_out=datapath.Pipe_MEM_WB_RD;
    }

// Función de ayuda para extender el signo de un valor a 32 bits.
static int32_t sign_extend32(uint32_t value, unsigned bits) {
    if (bits == 0 || bits >= 32) return static_cast<int32_t>(value);
    uint32_t mask = (1u << bits) - 1u;
    uint32_t v = value & mask;
    if (v & (1u << (bits - 1))) {
        // negative
        return static_cast<int32_t>(v | ~mask);
    } else {
        return static_cast<int32_t>(v);
    }
}

// Versión corregida y más robusta
std::string Simulator::disassemble(uint32_t instruction, const InstructionInfo* info) const {
    if (!info) return "not implemented";
    if (instruction == 0x00000013u) return "nop";

    uint32_t rd  = (instruction >> 7) & 0x1F;
    uint32_t rs1 = (instruction >> 15) & 0x1F;
    uint32_t rs2 = (instruction >> 20) & 0x1F;

    std::ostringstream oss;
    oss << info->instr << " ";

    switch (info->type) {
        case 'R': // rd, rs1, rs2
            oss << "x" << rd << ", x" << rs1 << ", x" << rs2;
            break;

        case 'I': { // rd, rs1, imm12
            uint32_t imm12 = (instruction >> 20) & 0xFFFu;
            int32_t imm = sign_extend32(imm12, 12);
            oss << "x" << rd << ", x" << rs1 << ", " << imm;
            break;
        }

        case 'S': { // sw rs2, imm(rs1)
            uint32_t imm11_5 = (instruction >> 25) & 0x7Fu;
            uint32_t imm4_0  = (instruction >> 7)  & 0x1Fu;
            uint32_t imm12 = (imm11_5 << 5) | imm4_0;
            int32_t imm = sign_extend32(imm12, 12);
            oss << "x" << rs2 << ", " << imm << "(x" << rs1 << ")";
            break;
        }

        case 'B': { // beq rs1, rs2, imm (imm is multiple of 2; represented as signed 13-bit)
            uint32_t imm12   = (instruction >> 31) & 0x1u;        // bit 31 -> imm[12]
            uint32_t imm11   = (instruction >> 7)  & 0x1u;        // bit 7  -> imm[11]
            uint32_t imm10_5 = (instruction >> 25) & 0x3Fu;       // bits 30:25 -> imm[10:5]
            uint32_t imm4_1  = (instruction >> 8)  & 0xFu;        // bits 11:8  -> imm[4:1]
            uint32_t imm_b = (imm12 << 12) | (imm11 << 11) | (imm10_5 << 5) | (imm4_1 << 1);
            int32_t imm = sign_extend32(imm_b, 13);
            oss << "x" << rs1 << ", x" << rs2 << ", " << imm;
            break;
        }

        case 'U': { // lui/auipc rd, imm20
            uint32_t imm_val = instruction >> 12; // Desplaza para obtener el valor real
            oss << "x" << rd << ", 0x" << std::hex << imm_val;
            oss << std::dec; // Restaura el formato a decimal para otros casos
            break;
        }

        case 'J': { // jal rd, imm (signed 21-bit immediate, LSB implied 0)
            uint32_t imm20    = (instruction >> 31) & 0x1u;      // bit31 -> imm[20]
            uint32_t imm19_12 = (instruction >> 12) & 0xFFu;     // bits 19:12
            uint32_t imm11    = (instruction >> 20) & 0x1u;      // bit20 -> imm[11]
            uint32_t imm10_1  = (instruction >> 21) & 0x3FFu;    // bits 30:21 -> imm[10:1]
            uint32_t imm_j = (imm20 << 20) | (imm19_12 << 12) | (imm11 << 11) | (imm10_1 << 1);
            int32_t imm = sign_extend32(imm_j, 21);
            oss << "x" << rd << ", " << imm;
            break;
        }

        default:
            oss << std::hex << "0x" << instruction << std::dec;
            break;
    }

    return oss.str();
}

// Constructor: Inicializa los componentes del simulador.
Simulator::Simulator(size_t mem_size, PipelineModel model)
    : pc(0), // El PC se inicializa en 0.
    current_cycle(0),
    status_reg(0), // Inicializamos el registro de estado a 0
    register_file(),
    model(model),
    memory(mem_size),
    i_cache(IMEM_SIZE, 16, memory),//No usado
    d_cache(DMEM_SIZE, 16, memory),//No usado
    i_mem(IMEM_SIZE), // Memoria de instrucciones para modo didáctico
    d_mem(DMEM_SIZE),  // Memoria de datos para modo didáctico
    history_pointer(0),
    assembler(&m_logfile), // Pasamos el logfile al ensamblador
    datapath{}
{
      // Abrir el fichero de log. Se sobreescribirá en cada nueva ejecución.
      m_logfile.open("simulator.log", std::ios::out | std::ios::trunc);
      m_logfile << "--- Log del Simulador RISC-V ---" << std::endl;

      // Reservar espacio para el historial para evitar realojamientos frecuentes
      history.reserve(1024);
      m_logfile << "--- Historia reservada ---" << std::endl;
}

// Ensambla un código ensamblador a código máquina.
std::vector<uint8_t> Simulator::assemble(const char* assembly_code)  {
    // Llama al ensamblador de múltiples pasadas para convertir el código
    // fuente en código máquina.
    m_logfile << "ENTRANDO A ENSAMBLAR"<< std::endl;
    m_logfile << assembly_code  << std::endl;
    return assembler.assemble_program(assembly_code);
    m_logfile << "FIN DE ENSAMBLAR"<< std::endl;

}

// Carga un programa en la memoria del simulador desde código ensamblador.
void Simulator::load_program(const char* assembly_code, PipelineModel model) {
    std::vector<uint8_t> machine_code = assemble(assembly_code);
    load_program(machine_code, model);
}

// Carga un programa en la memoria del simulador.
void Simulator::load_program(const std::vector<uint8_t>& program, PipelineModel model) {
    // La carga depende del modo de pipeline.
    if (program.empty()) {
        m_logfile << "\n--- Advertencia: Se cargó un programa vacío. Limpiando memoria. ---" << std::endl;
        if (model != PipelineModel::General) {
            i_mem.clear();
            d_mem.clear();
        } else {
            memory.clear(); // Limpiamos la memoria general también
        }
        return; // Salimos para evitar errores de acceso.
    }

    if (model == PipelineModel::General) {
        m_logfile << "\n--- Programa cargado en memoria (modo general)" << program[0] << " ---" << std::endl;
        memory.load_program(program, 0);
    } else {
        // En modo didáctico, el programa se carga en la memoria de instrucciones.
        // La memoria de datos permanece vacía inicialmente.
        i_mem.clear();
        d_mem.clear();
        i_mem.load_program(program, 0);
        m_logfile << "\n--- Programa cargado en memoria (modo didactico) " << program[0] << " ---" << std::endl;
    }
}

// Ejecuta un ciclo completo: fetch, decode, execute.
void Simulator::step() {
    // Si hemos retrocedido y ahora avanzamos, se crea una nueva línea de tiempo.
    // Se borra el historial "futuro" que ya no es válido.
    if (history_pointer < history.size()) {
        history.resize(history_pointer);
    }

    // Guardar el estado actual ANTES de ejecutar el ciclo.
    history.emplace_back(pc, register_file, datapath, current_cycle, instructionString, d_mem);
    history_pointer++;

    uint32_t instruction = fetch();
    if (m_logfile.is_open()) {
        m_logfile << "\n--- Ciclo " << current_cycle << " ---" << std::endl;
        m_logfile << "PC: 0x" << std::hex << pc << std::dec << std::endl;
        m_logfile << "Instruccion leida: 0x" << std::hex << instruction << std::dec << std::endl;

    }
    current_cycle++; // Avanzamos el ciclo de instruccion//reloj
    decode_and_execute(instruction);
    if (m_logfile.is_open()) {
        m_logfile << "Instruccion ejecutada: 0x" << std::hex << instruction << std::dec << std::endl;
        m_logfile << "Control: 0x" << std::hex << datapath.bus_Control.value << std::dec << std::endl;

    }
}

// Ejecuta un ciclo completo: fetch, decode, execute.
void Simulator::reset(PipelineModel _model, uint32_t _initial_pc) {
    // Actualizamos el modelo del simulador con el que nos pasan.
    model = _model;
    initial_pc=IMEM_SIZE*(_initial_pc/IMEM_SIZE); 
    pc = initial_pc;
    current_cycle = 0;
    status_reg = 0;
    register_file.reset();
    datapath = {};
    instructionString = "";
    // Después de resetear, ejecutamos el primer ciclo para que la UI muestre
    // el estado inicial con la primera instrucción (la de PC=0) ya procesada.
    d_mem.clear();
    //step();
    // Limpiar el historial
    history.clear();
    history_pointer = 0;

    if (m_logfile.is_open()) {
        m_logfile << "Model:" << (int) model << std::endl;
        m_logfile << "\n--- Reseteando ---" << std::endl;
        m_logfile << "PC: 0x" << std::hex << pc << std::dec << std::endl;
        m_logfile << "\n--- Localizando la primera instruccion ---" << std::endl;
    }
    if(model == PipelineModel::PipeLined) {

        datapath.Pipe_IF_ID_Instr.is_active=false;
        datapath.Pipe_IF_ID_NPC.is_active=false;
        datapath.Pipe_IF_ID_PC.is_active=false;
        
        datapath.bus_DA.is_active=false;
        datapath.bus_DB.is_active=false;
        datapath.bus_DC.is_active=false;
        datapath.bus_Instr.is_active=false;

        datapath.Pipe_ID_EX_A.is_active=false;
        datapath.Pipe_ID_EX_B.is_active=false;  
        datapath.Pipe_ID_EX_Imm.is_active=false;
        datapath.Pipe_ID_EX_RD.is_active=false;
        datapath.Pipe_ID_EX_RS1.is_active=false;
        datapath.Pipe_ID_EX_RS2.is_active=false;
        datapath.Pipe_ID_EX_NPC.is_active=false;
        datapath.Pipe_ID_EX_PC.is_active=false;
        datapath.Pipe_ID_EX_Control.is_active=false;

        datapath.Pipe_EX_MEM_Control.is_active=false;
        datapath.Pipe_EX_MEM_ALU_result.is_active=false;
        datapath.Pipe_EX_MEM_B.is_active=false;
        datapath.Pipe_EX_MEM_NPC.is_active=false;
        datapath.Pipe_EX_MEM_RD.is_active=false;

        datapath.Pipe_MEM_WB_ALU_result.is_active=false;
        datapath.Pipe_MEM_WB_NPC.is_active=false;
        datapath.Pipe_MEM_WB_RD.is_active=false;
        datapath.Pipe_MEM_WB_Control.is_active=false;
        datapath.Pipe_MEM_WB_RM.is_active=false;

        //No todo es necesario, pero por si acaso...
        datapath.bus_ALU_B.is_active = false;
        datapath.bus_ALU_A.is_active = false;
        datapath.bus_ALU_result.is_active = false;
        datapath.bus_ALU_zero.is_active = false;
        datapath.bus_imm.is_active = false;
        datapath.bus_C.is_active = false;
        datapath.bus_Mem_address.is_active = false;
        datapath.bus_Mem_write_data.is_active = false;
        
        datapath.bus_Instr.is_active = false;
        datapath.bus_branch_taken.is_active=false;
        datapath.bus_PC_dest.is_active=false;

        datapath.bus_ImmSrc.is_active=false;
        datapath.bus_PCsrc.is_active=false;
        datapath.bus_ALUctr.is_active=false;
        datapath.bus_MemWr.is_active=false;
        datapath.bus_ResSrc.is_active=false;
        datapath.bus_BRwr.is_active=false;
        datapath.bus_ALUsrc.is_active=false;

        datapath.bus_ControlForwardA={1, 1, false};
        datapath.bus_ControlForwardB={1, 1, false};
        datapath.bus_ForwardA.is_active=false;
        datapath.bus_ForwardB.is_active=false;

        


    } 
    step();
}

// Retrocede un ciclo en la simulación.
void Simulator::step_back() {
    if (history_pointer == 0) {
        // No se puede retroceder más allá del estado inicial.
        return;
    }

    // Mover el puntero al estado anterior.
    history_pointer--;

    // Restaurar el estado desde la instantánea.
    const auto& snapshot = history[history_pointer];
    pc = snapshot.pc;
    register_file = snapshot.register_file; // Restaura la copia completa
    datapath = snapshot.datapath;
    current_cycle = snapshot.current_cycle;
    instructionString = snapshot.instructionString;
    d_mem = snapshot.d_mem; // Restaurar la memoria de datos
}

// Devuelve el valor actual del Program Counter.
uint32_t Simulator::get_pc() const {
    return pc;
}

// Devuelve el valor del registro de estado.
uint32_t Simulator::get_status_register() const {
    return status_reg;
}

DatapathState Simulator::get_datapath_state() const {
    
    return this->datapath;
}

std::string Simulator::get_instruction_string() const {
    return this->instructionString;
}


// Devuelve una referencia constante al banco de registros.
const RegisterFile& Simulator::get_registers() const {
    return register_file;
}

// Devuelve el contenido de la memoria de datos (para modo didáctico).
const std::vector<uint8_t>& Simulator::get_d_mem() const {
    return d_mem.get_data();
}

// Devuelve el contenido de la memoria de instrucciones desensamblado.
std::vector<std::pair<uint32_t, std::string>> Simulator::get_i_mem()  {
    std::vector<std::pair<uint32_t, std::string>> disassembled_memory;
    
    // Iteramos sobre la memoria de instrucciones en incrementos de 4 bytes (una palabra).
    // Asumimos que el tamaño es 256 bytes, como se definió en el constructor.
    for (uint32_t address = 0; address < IMEM_SIZE; address += 4) {
        try {
            // Leemos la instrucción en la dirección actual.
            uint32_t instruction = i_mem.read_word(address);


            // Si la instrucción es 0, podría ser el final del programa útil.
            // Podríamos optar por detenernos, pero por ahora continuaremos para mostrar todo el contenido.

            // Decodificamos y desensamblamos.
            const InstructionInfo* info = control_unit.decode(instruction);
            std::string disassembled_instruction = disassemble(instruction, info);
            
            // Añadimos la dirección y la instrucción desensamblada al vector.
            disassembled_memory.emplace_back(static_cast<uint32_t>(instruction), disassembled_instruction);

        } catch (const std::out_of_range& e) {
            // Si read_word lanza una excepción (p.ej. fuera de rango), hemos llegado al final.
            break; 
        }
    }

    return disassembled_memory;
}


// Fase de Fetch: Lee la siguiente instrucción de la memoria.
uint32_t Simulator::fetch() {
    // Lee una palabra de 32 bits (4 bytes) desde la caché de instrucciones.
    if (model == PipelineModel::General) {
        return i_cache.read_word(pc);
    } else {
        // En modo didáctico, lee directamente de la memoria de instrucciones. La memoria sólo tiene 256 bytes, pero puede ser de un segmento distinto de cero
            m_logfile << "Model:" << (int) model << std::endl;
            uint32_t instruction=i_mem.read_word(pc-initial_pc,true);
            m_logfile << "Instruction:" << (int) instruction << std::endl;
        return instruction;
    }
    
}


/*
 * uint16_t controlWord(const InstructionInfo* info) {
 *     return (info->ALUctr  & 0x7) << 13 |  // 3 bits
 *            (info->ResSrc & 0x3) << 11 |  // 2 bits
 *            (info->ImmSrc & 0x7) << 8  |  // 3 bits
 *            (info->PCsrc  & 0x3) << 6  |  // 2 bit
 *            (info->ALUsrc   & 0x1) << 4  |  // 1 bit
 *            (info->BRwr & 0x1) << 3  |  // 1 bit
 *            (info->MemWr  & 0x1) << 2 | 0;    // 1 bit
 * }
 */

uint16_t controlWord(const InstructionInfo* info) {
    using namespace riscv_sim::ControlWord;
    return (static_cast<uint16_t>(info->ALUctr & ((1 << ALUctr_width) - 1)) << ALUctr_pos) |
           (static_cast<uint16_t>(info->ResSrc & ((1 << ResSrc_width) - 1)) << ResSrc_pos) |
           (static_cast<uint16_t>(info->ImmSrc & ((1 << ImmSrc_width) - 1)) << ImmSrc_pos) |
           (static_cast<uint16_t>(info->PCsrc  & ((1 << PCsrc_width) - 1))  << PCsrc_pos)  |
           (static_cast<uint16_t>(info->ALUsrc & ((1 << ALUsrc_width) - 1)) << ALUsrc_pos) |
           (static_cast<uint16_t>(info->BRwr   & ((1 << BRwr_width) - 1))   << BRwr_pos)   |
           (static_cast<uint16_t>(info->MemWr  & ((1 << MemWr_width) - 1))  << MemWr_pos);
}

/*
uint8_t controlSignal(uint16_t controlWord, const std::string& name) {
    if (name == "PCsrc") {
        return (controlWord >> 6) & 0x3;
    } else if (name == "BRwr") {
        return (controlWord >> 3) & 0x1;
    } else if (name == "ALUsrc") {
        return (controlWord >> 4) & 0x1;
    } else if (name == "ResSrc") {
        return (controlWord >> 11) & 0x3;
    } else if (name == "ImmSrc") {
        return (controlWord >> 8) & 0x7;
    }
    return (controlWord >> 13) & 0x7; // Default to ALUctr
}
*/

uint8_t controlSignal(uint16_t controlWord, const std::string& name) {
    using namespace riscv_sim::ControlWord;
    if (name == "PCsrc")  return (controlWord >> PCsrc_pos)  & ((1 << PCsrc_width) - 1);
    if (name == "BRwr")   return (controlWord >> BRwr_pos)   & ((1 << BRwr_width) - 1);
    if (name == "ALUsrc") return (controlWord >> ALUsrc_pos) & ((1 << ALUsrc_width) - 1);
    if (name == "ResSrc") return (controlWord >> ResSrc_pos) & ((1 << ResSrc_width) - 1);
    if (name == "ImmSrc") return (controlWord >> ImmSrc_pos) & ((1 << ImmSrc_width) - 1);
    if (name == "MemWr")  return (controlWord >> MemWr_pos)  & ((1 << MemWr_width) - 1);
    // Default to ALUctr
    return (controlWord >> ALUctr_pos) & ((1 << ALUctr_width) - 1);
}

void Simulator::decode_and_execute(uint32_t instruction)
{
    m_logfile << "Model:" << (int) model << std::endl;
    if (model == PipelineModel::PipeLined) {
        // La simulación segmentada no se basa en una sola instrucción, sino en el estado de los registros.
        // La instrucción 'fetch' es solo para la primera etapa.
        simulate_pipeline(instruction);
    } else if (model == PipelineModel::MultiCycle) {
        simulate_multi_cycle(instruction);
    } else {
        // Por defecto, o para SingleCycle, usamos la simulación original.
        simulate_single_cycle(instruction);
    }
}

void Simulator::simulate_single_cycle(uint32_t instruction) {
    // --- INICIO DEL CICLO (t=0) ---
    // La única señal estable al inicio del ciclo es el PC.
    // Le ponemos 1 ps para ver su aparición
    datapath.bus_PC = { pc, DELAY_PC };
    uint32_t pc_plus_4 = adder4.add(pc);
    datapath.bus_PC_plus4 = { pc_plus_4,datapath.bus_PC.ready_at+ adder4.get_delay() };


    // --- FASE 1: FETCH (Búsqueda de instrucción) ---
    // La memoria de instrucciones (i_mem) necesita el PC. Su salida (la instrucción)
    // estará lista después de su retardo de propagación.
    uint32_t tmptime=datapath.bus_PC.ready_at + i_mem.get_delay();
    datapath.bus_Instr={instruction,tmptime};
    datapath.bus_imm = datapath.bus_Instr;
    
    uint32_t rs1_addr = (instruction >> 15) & 0x1F;
    uint32_t rs2_addr = (instruction >> 20) & 0x1F;
    uint32_t rd_addr  = (instruction >> 7)  & 0x1F;
    datapath.bus_DA = {(uint8_t)rs1_addr,tmptime};
    datapath.bus_DB = {(uint8_t)rs2_addr,tmptime};
    datapath.bus_DC = {(uint8_t)rd_addr,tmptime};
    datapath.bus_opcode={(uint8_t)(instruction & 0x7F),tmptime};
    datapath.bus_funct3={(uint8_t)((instruction >> 12) & 0x07),tmptime};
    datapath.bus_funct7={(uint8_t)((instruction >> 25) & 0x7F),tmptime};

    

    // 1. DECODIFICACIÓN Y LECTURA DE REGISTROS
    const InstructionInfo* info = control_unit.decode(instruction);
    m_logfile << info << std::endl;


    
    if (!info) {
        std::cerr << "Instrucción no reconocida: 0x" << std::hex << instruction << std::endl;
        if (m_logfile.is_open()) {
            m_logfile << "Instrucción no reconocida: 0x" << std::hex << instruction << std::endl;
        }
        // Tratar como NOP para evitar un bucle infinito: avanzar PC y no hacer nada más.
        pc = pc_plus_4;
        instructionString = disassemble(instruction, nullptr);
        return;
    }



    try{
 
    instructionString = disassemble(instruction, info);
        if (m_logfile.is_open()) {
            m_logfile << "Instruccion reconocida: 0x" << std::hex << instruction << std::endl;
            m_logfile << "Tipo: " << info->type << std::endl;
            m_logfile << "Desensamblado: " << instructionString << std::endl;
        }
   //datapath.instruction=instructionString;
    datapath.total_micro_cycles = info->cycles;
    strcpy(datapath.instruction_cptr,instructionString.c_str());
    }
    catch(const std::exception& e){
        m_logfile << "Error al formatear la instrucción: " << e.what() << std::endl;
        pc = pc_plus_4;
        return;
    }

    uint32_t controlDelay=tmptime+control_unit.get_delay();
    try{
    datapath.bus_Control = {controlWord(info),controlDelay};
    if (m_logfile.is_open()) {
        m_logfile << "Info: instr=" << info->instr << ", PCsrc=" << static_cast<int>(info->PCsrc)
                  << ", BRwr=" << static_cast<int>(info->BRwr) << ", ALUsrc=" << static_cast<int>(info->ALUsrc)
                  << ", ALUctr=" << static_cast<int>(info->ALUctr) << ", MemWr=" << static_cast<int>(info->MemWr)
                  << ", ResSrc=" << static_cast<int>(info->ResSrc) << ", ImmSrc=" << static_cast<int>(info->ImmSrc)
                  << ", type=" << info->type 
                  << "Control word:" << std::hex << controlWord(info) << std::endl;
    }
    datapath.bus_PCsrc = {info->PCsrc,tmptime,true}; //El tiempo se cambia después

}
    catch(const std::exception& e){
        m_logfile <<  "Error al calcular control de  la instrucción: " << e.what() << std::endl; 
        pc = pc_plus_4;
        return;
    }
    // 2. Lectura de registros y EXTENSIÓN DE SIGNO

    uint32_t rs1_val = register_file.readA(rs1_addr);
    uint32_t rs2_val = register_file.readB(rs2_addr);
    tmptime=datapath.bus_Instr.ready_at + register_file.get_delay();
    datapath.bus_A = {rs1_val,tmptime};

    // Para LUI, el primer operando de la ALU debe ser 0, no el valor de rs1.
    // Para AUIPC, sería el PC. Aquí lo simplificamos para LUI.
    const uint32_t alu_op_a = (info->type == 'U') ? 0 : rs1_val;
    datapath.bus_ALU_A = {alu_op_a, tmptime};

    datapath.bus_B = {rs2_val,tmptime};
    uint32_t imm_ext = sign_extender.extender(instruction, info->ImmSrc);
    uint32_t tmptime2=datapath.bus_Control.ready_at + sign_extender.get_delay();
    datapath.bus_immExt = {imm_ext,tmptime2};
    datapath.bus_Mem_write_data=datapath.bus_B;
    m_logfile <<  "Lectura de registros ok" << std::endl; 
    

    //

        // 3. EJECUCIÓN (ALU)
    // Mux para la entrada B de la ALU
    uint32_t alu_op_b =mux_B.select(imm_ext,rs2_val,info->ALUsrc)   ;
    uint32_t tmptime3=std::max(std::max(datapath.bus_B.ready_at,datapath.bus_immExt.ready_at),datapath.bus_Control.ready_at) + mux_B.get_delay();
    datapath.bus_ALU_B = {alu_op_b,tmptime3};

    
    uint32_t alu_result = alu.calc(alu_op_a, alu_op_b, info->ALUctr);
    bool alu_zero = (alu_result == 0);
    uint32_t tmptime4=std::max(std::max(datapath.bus_ALU_A.ready_at,datapath.bus_ALU_B.ready_at),datapath.bus_Control.ready_at) + alu.get_delay();
    datapath.bus_ALU_result    = {alu_result,tmptime4};
    datapath.bus_ALU_zero      = {alu_zero,tmptime4};
    datapath.bus_Mem_address    = datapath.bus_ALU_result;



    
    uint32_t pc_plus_imm = adder.add(pc, imm_ext);
    datapath.bus_PC_dest       = {pc_plus_imm, datapath.bus_immExt.ready_at+ adder.get_delay()};


    m_logfile <<  "ALU ok" << std::endl; 


    // 4. ACCESO A MEMORIA
    uint32_t mem_read_data = INDETERMINADO;


    if(info->instr=="lw")
    try{
    mem_read_data = d_mem.read_word(alu_result,true);
    }
    catch(const std::exception& e)
    {
    m_logfile <<  "Error al leer de la memoria: " << e.what() << std::endl; 
    mem_read_data=alu_result;
    }

    if (info->MemWr == 1) { // SW
    try{
        d_mem.write_word(alu_result, rs2_val);
    }
    catch(const std::exception& e)
    {
    m_logfile <<  "Error al escribir en la memoria: " << e.what() << std::endl; 
    }

    }

    datapath.bus_Mem_read_data = {mem_read_data, tmptime4+ d_mem.get_delay()};//tmptime4 es la salida de la alu con dirección efectiva
    m_logfile <<  "MEM ok" << std::endl; 

    // 5. ESCRITURA (WRITE-BACK)
    // Mux para el resultado final
    uint32_t  final_result=mux_C.select(mem_read_data,alu_result,pc_plus_4,INDETERMINADO,info->ResSrc);
    criticalTime=std::max(std::max(std::max(datapath.bus_ALU_result.ready_at,datapath.bus_Mem_read_data.ready_at),datapath.bus_Control.ready_at),datapath.bus_PC_plus4.ready_at)+mux_C.get_delay();
    datapath.bus_C = {final_result,criticalTime};
    datapath.criticalTime=criticalTime+register_file.get_write_delay();
        if (m_logfile.is_open()) {
            m_logfile << "Resultado ALU: "+std::to_string(alu_result) << std::endl;
            m_logfile << "Resultado MEM: "+std::to_string(mem_read_data) << std::endl;
            m_logfile << "Resultado PC+4: "+std::to_string(pc_plus_4) << std::endl;
            m_logfile << "Resultado final: "+std::to_string(final_result) << std::endl;
            m_logfile << "Critical Tme: "+std::to_string(datapath.criticalTime) << std::endl;
        }

    if (info->BRwr == 1) {
        register_file.write(rd_addr, final_result);
    }


 
    // Mux para el PC
    // Lógica de selección del siguiente PC
    bool take_branch = false;
    if (info->type == 'B') { // Instrucciones de salto condicional
        if (info->instr == "beq" && alu_zero) take_branch = true;
        if (info->instr == "bne" && !alu_zero) take_branch = true;
        // Añadir aquí otros saltos condicionales (blt, bge, etc.) si se implementan
    } else if (info->instr == "jal" || info->instr == "jalr") { // Saltos incondicionales (JAL, JALR)
        take_branch = true;
    }

    uint32_t tmptime5 = std::max(datapath.bus_ALU_zero.ready_at,datapath.bus_Control.ready_at)+DELAY_Z_AND; //Tiempo en llegar la sñal que controla el mux
    
    datapath.bus_branch_taken = {take_branch, tmptime5};
    datapath.bus_PCsrc.ready_at = tmptime5;

    // La dirección de destino para JALR es el resultado de la ALU, no PC + imm.
    uint32_t jump_target = (info->instr == "jalr") ? alu_result : pc_plus_imm;

    tmptime5 = std::max(std::max(datapath.bus_PC_plus4.ready_at,datapath.bus_PC_dest.ready_at),tmptime5) + mux_PC.get_delay();

    uint32_t next_pc = take_branch ? jump_target : pc_plus_4;

    datapath.bus_PC_next = {next_pc,tmptime5};
    // Aquí desactivamos las rutas que no se usan para la instrucción actual.
    // Por defecto, todos los is_active son 'true' desde la definición de la struct Signal.
    if(info->PCsrc!=0)datapath.bus_PC_plus4.is_active=false;

    if (info->instr == "addi") {
        datapath.bus_PC_dest.is_active = false;       // El sumador de saltos no se usa.
        datapath.bus_Mem_read_data.is_active = false; // No se lee de la memoria de datos.
        datapath.bus_B.is_active = false;             // La segunda lectura de registros (rs2) no se usa.
    } else if (info->instr == "lw") { // Load Word
        datapath.bus_PC_dest.is_active = false;       // El sumador de saltos no se usa.
        datapath.bus_B.is_active = false;             // La segunda lectura de registros no se usa para la ALU.
    } else if (info->instr == "sw") { // Store Word
        datapath.bus_PC_dest.is_active = false;       // El sumador de saltos no se usa.
        datapath.bus_Mem_read_data.is_active = false; // No se lee de memoria, se escribe.
        datapath.bus_C.is_active = false;             // No hay resultado que escribir en los registros (write-back).
    } else if (info->type == 'U') { // LUI
        datapath.bus_Mem_read_data.is_active = false; // No se accede a la memoria de datos.
        datapath.bus_PC_dest.is_active = false;       // El sumador de saltos no se usa.
    } else if (info->type == 'R') { // LUI
        datapath.bus_Mem_read_data.is_active = false; // No se accede a la memoria de datos.
        datapath.bus_PC_dest.is_active = false;       // El sumador de saltos no se usa.
    } else if (info->type == 'B') { // Branches (BEQ, etc.)
        datapath.bus_Mem_read_data.is_active = false; // No se accede a la memoria de datos.
        datapath.bus_PC_plus4.is_active=true;

        datapath.bus_C.is_active = false;             // No hay resultado que escribir en los registros.
    } else if (info->type == 'J' || info->instr == "jalr") { // Jumps
        // Para JAL, el sumador de saltos (PC + imm) SÍ está activo.
        // Lo que no se usa es el resultado de la ALU principal ni la memoria de datos.
        datapath.bus_ALU_result.is_active = false;
        datapath.bus_Mem_address.is_active = false;
        datapath.bus_Mem_read_data.is_active = false;
        datapath.bus_PC_plus4.is_active=true;
    }




    datapath.bus_PCsrc = {info->PCsrc, controlDelay};
    datapath.bus_ALUsrc = {info->ALUsrc, controlDelay};
    datapath.bus_ResSrc = {info->ResSrc, controlDelay};
    datapath.bus_ImmSrc = {info->ImmSrc, controlDelay};
    datapath.bus_ALUctr = {info->ALUctr, controlDelay};
    datapath.bus_BRwr = {info->BRwr, controlDelay};
    datapath.bus_MemWr = {info->MemWr, controlDelay};




    pc = next_pc;
}

void Simulator::simulate_multi_cycle(uint32_t instruction) {
    // En multiciclo, el estado se construye a lo largo de varios ciclos.
    // Aquí, para la visualización, calculamos el estado final de todos los buses
    // y asignamos el microciclo (0-4) en el que se activan a 'ready_at'.
    // Se refiere a ciclo; no a etapa

    // --- Decodificación inicial para obtener información ---
    datapath = {}; // Limpiar datapath para el nuevo estado
    const InstructionInfo* info = control_unit.decode(instruction);
    if (!info) info=control_unit.decode(0x00000013); // Si no se reconoce la instrucción, usamos NOP como fallback.

    instructionString = disassemble(instruction, info);
    strcpy(datapath.instruction_cptr, instructionString.c_str());
    datapath.total_micro_cycles = info->cycles;

    // --- Valores que se propagan a través de los ciclos ---
    uint32_t rs1_addr = (instruction >> 15) & 0x1F;
    uint32_t rs2_addr = (instruction >> 20) & 0x1F;
    uint32_t rd_addr  = (instruction >> 7)  & 0x1F;
    uint32_t rs1_val = register_file.readA(rs1_addr);
    uint32_t rs2_val = register_file.readB(rs2_addr);
    uint32_t imm_ext = sign_extender.extender(instruction, info->ImmSrc); // Se calcula en ID, pero lo necesitamos antes.
    uint32_t pc_plus_4 = pc + 4;

    // --- MICRO-CICLO 0: IF (Instruction Fetch) ---
    // El PC se usa para leer la memoria de instrucciones.
    datapath.bus_PC = { pc, 0 };
    datapath.bus_Instr = { instruction, 0 };
    datapath.bus_PC_plus4 = { pc_plus_4, 0 };

    datapath.bus_DA = { (uint8_t)rs1_addr, 1 };
    datapath.bus_DB = { (uint8_t)rs2_addr, 1 };
    datapath.bus_DC = { (uint8_t)rd_addr, 1 };
    datapath.bus_opcode = { (uint8_t)(instruction & 0x7F), 1 };
    datapath.bus_funct3 = { (uint8_t)((instruction >> 12) & 0x07), 1 };
    datapath.bus_funct7 = { (uint8_t)((instruction >> 25) & 0x7F), 1 };
    datapath.bus_imm = { instruction, 1 };
    

    // --- MICRO-CICLO 1: ID (Instruction Decode & Register Fetch) ---
    // Se decodifica la instrucción y se leen los registros.
    
    datapath.bus_A = { rs1_val, 1 };
    datapath.bus_B = { rs2_val, 1 };
    datapath.bus_immExt = { imm_ext, 1 };
    datapath.bus_Control = { controlWord(info), 1, true };

    // Las señales de control individuales también están listas en este ciclo.

    datapath.bus_PCsrc = {info->PCsrc, 1};
    datapath.bus_ALUsrc = {info->ALUsrc, 1};
    datapath.bus_ResSrc = {info->ResSrc, 1};
    datapath.bus_ImmSrc = {info->ImmSrc, 1};
    datapath.bus_ALUctr = {info->ALUctr, 1};
    datapath.bus_BRwr = {info->BRwr, 1};
    datapath.bus_MemWr = {info->MemWr, 1};

    // --- MICRO-CICLO 2: EX (Execute) ---
    // La ALU realiza la operación.
    const uint32_t alu_op_a = (info->type == 'U') ? 0 : rs1_val;
    const uint32_t alu_op_b = mux_B.select(imm_ext, rs2_val, info->ALUsrc);
    const uint32_t alu_result = alu.calc(alu_op_a, alu_op_b, info->ALUctr);
    const bool alu_zero = (alu_result == 0);
    const uint32_t pc_plus_imm = pc + imm_ext;

    datapath.bus_ALU_A = { alu_op_a, 1 };
    datapath.bus_ALU_B = { alu_op_b, 2 };
    datapath.bus_ALU_result = { alu_result, 2 };
    datapath.bus_ALU_zero = { alu_zero, 2 };
    datapath.bus_PC_dest = { pc_plus_imm, 2 };

    // --- Lógica variable para los ciclos 3 y 4 ---
    uint32_t mem_read_data = INDETERMINADO;
    uint32_t final_result = INDETERMINADO;
    uint32_t next_pc;

    // Por defecto, las rutas de memoria y escritura no están activas.
    datapath.bus_Mem_address.is_active = false;
    datapath.bus_Mem_write_data.is_active = false;
    datapath.bus_Mem_read_data.is_active = false;
    datapath.bus_C.is_active = false;

    if (info->type == 'R' || info->instr == "addi") { // R-Type o ADDI (4 ciclos)
        // Ciclo 3: WB
        final_result = alu_result;
        datapath.bus_C = { final_result, 3 };
        datapath.bus_C.is_active = true;
        if (info->BRwr == 1) register_file.write(rd_addr, final_result);
        next_pc = pc_plus_4;

    } else if (info->instr == "lw") { // LW (5 ciclos)
        // Ciclo 3: MEM
        datapath.bus_Mem_address = { alu_result, 3, true };
        mem_read_data = d_mem.read_word(alu_result,true);
        datapath.bus_Mem_read_data = { mem_read_data, 3, true };
        // Ciclo 4: WB
        final_result = mem_read_data;
        datapath.bus_C = { final_result, 4 };
        datapath.bus_C.is_active = true;
        if (info->BRwr == 1) register_file.write(rd_addr, final_result);
        next_pc = pc_plus_4;

    } else if (info->instr == "sw") { // SW (4 ciclos)
        // Ciclo 3: MEM
        datapath.bus_Mem_address = { alu_result, 3, true };
        datapath.bus_Mem_write_data = { rs2_val, 3, true };
        datapath.bus_C = { INDETERMINADO,999, false };
        d_mem.write_word(alu_result, rs2_val);
        next_pc = pc_plus_4;

    } else if (info->type == 'B') { // BEQ (3 ciclos)
        // Ciclo 2: EX/Branch completion
        bool take_branch =info->instr == "beq" && (alu_result == 0) || info->instr == "bne" && (alu_result != 0);
        datapath.bus_branch_taken = { take_branch, 2 };
        next_pc = take_branch ? pc_plus_imm : pc_plus_4;

    } else { // Jumps, etc. (Tratamiento genérico, se puede refinar)
        // Asumimos 4 ciclos por defecto para JAL, etc.
        final_result = mux_C.select(alu_result, mem_read_data, pc_plus_4, 0, info->ResSrc);
        datapath.bus_C = { final_result, 3 };
        datapath.bus_C.is_active = info->BRwr;
        if (info->BRwr == 1) register_file.write(rd_addr, final_result);
        bool is_jump = (info->PCsrc == 1 || info->PCsrc == 2);
        datapath.bus_branch_taken = { is_jump, 2 };
        // Para JALR, el destino es el resultado de la ALU. Para JAL, es PC + imm.
        uint32_t jump_target = (info->PCsrc == 2) ? alu_result : pc_plus_imm;
        next_pc = is_jump ? jump_target : pc_plus_4;

    }

    // El PC se actualiza al final del último microciclo de la instrucción anterior.
    datapath.bus_PC_next = { next_pc, (uint32_t)(info->cycles - 1) };

    // Actualizamos el PC para el siguiente ciclo de instrucción.
    pc = next_pc;

    // --- Salidas de Registros de Pipeline (para visualización en modo multiciclo) ---
    // Estos buses simulan la salida de los registros de segmentación en el ciclo *siguiente*
    // a donde se calculan sus entradas.

    strcpy(datapath.Pipe_IF_instruction_cptr, instructionString.c_str());
    strcpy(datapath.Pipe_ID_instruction_cptr, instructionString.c_str());
    strcpy(datapath.Pipe_EX_instruction_cptr, instructionString.c_str());
    strcpy(datapath.Pipe_MEM_instruction_cptr, instructionString.c_str());
    strcpy(datapath.Pipe_WB_instruction_cptr, instructionString.c_str());



    // IF/ID (listo en ciclo 1)
    datapath.Pipe_IF_ID_Instr = { instruction,1 };
    //datapath.Pipe_IF_ID_NPC = { pc_plus_4, 1 };
    //datapath.Pipe_IF_ID_PC = { pc, 1 };

    // ID/EX (listo en ciclo 2)    datapath.Pipe_ID_EX_Control = { controlWord(info), 2 };

    //datapath.Pipe_ID_EX_Control = { controlWord(info), 2 };
    //datapath.Pipe_ID_EX_NPC = { pc_plus_4, 1 };
    datapath.Pipe_ID_EX_A = { alu_op_a, 2 }; // alu_op_a es rs1_val (o 0 para LUI)
    datapath.Pipe_ID_EX_B = { rs2_val, 2 };
    //datapath.Pipe_ID_EX_RD = { (uint8_t)rd_addr, 1 };
    datapath.Pipe_ID_EX_Imm = { imm_ext, 2 };
    //datapath.Pipe_ID_EX_PC = { pc, 1 };

    // EX/MEM (listo en ciclo 3)
    bool esSW=info->instr == "sw";
    bool noesJ=info->type != 'J';

    //datapath.Pipe_EX_MEM_Control = { controlWord(info), 3 };
    //datapath.Pipe_EX_MEM_NPC = { pc_plus_4, 2,noesJ };
    datapath.Pipe_EX_MEM_ALU_result = { alu_result, 3 };
    datapath.Pipe_EX_MEM_B = { rs2_val, 3 ,esSW};
    //datapath.Pipe_EX_MEM_RD = { (uint8_t)rd_addr, 2,!esSW}; // RD solo se usa en LW/R-Type, no en SW};

    // MEM/WB (listo en ciclo 4 para LW, 3 para R-Type)
    // El bus C ya tiene el tiempo correcto, así que lo copiamos.
    uint8_t cuando=(uint8_t) ((info->instr != "lw")?3:4);

    bool noesSW=info->instr != "sw";
    bool noesLW=info->instr != "lw";
    bool noesB=info->type != 'B';

    datapath.Pipe_MEM_WB_Control = { controlWord(info), cuando };
    datapath.Pipe_MEM_WB_NPC = { pc_plus_4,cuando, noesJ };
    datapath.Pipe_MEM_WB_ALU_result = {alu_result,cuando,noesSW&&noesLW&&noesB};
    datapath.Pipe_MEM_WB_RM = { (uint32_t)mem_read_data,cuando ,!noesLW};
    datapath.Pipe_MEM_WB_RD = { (uint8_t)rd_addr,cuando ,noesSW};

    // El tiempo crítico no es tan relevante en multiciclo, pero lo ponemos al final.
    datapath.criticalTime = info->cycles;

    //Aquí terminan el step con el mismo contenido (en pipeline se pone al principio, porque es diferente)
        copy_pipeline_registers_to_out(datapath);    

}

void Simulator::simulate_pipeline(uint32_t instruction) {
    // This function is called once per clock cycle.
    uint32_t oldDestinationRegister=0;
    datapath.criticalTime = 1; // In a pipelined model, a result is produced each cycle.

    

    copy_pipeline_registers_to_out(datapath);     
    
    // --- Local variables for hazard detection ---
    // These flags will be determined by the logic in the EX and ID stages.
    bool stall = false;
    bool flush = false;

    // Save the state of the instruction display variables from the beginning of the cycle.
    uint32_t prev_mem_instr = datapath.Pipe_MEM_instruction;
    uint32_t prev_ex_instr  = datapath.Pipe_EX_instruction;
    uint32_t prev_id_instr  = datapath.Pipe_ID_instruction;
    uint32_t prev_if_instr  = datapath.Pipe_IF_instruction;

    const InstructionInfo* fetched_info = control_unit.decode(instruction);
    const InstructionInfo* decoded_info = control_unit.decode(datapath.Pipe_IF_ID_Instr_out.value);



    instructionString = fetched_info ? disassemble(instruction, fetched_info) : "c.unimp";

    bool is_valid_instr_WB = datapath.Pipe_MEM_WB_NPC_out.is_active;
    bool is_valid_instr_MEM = datapath.Pipe_EX_MEM_NPC_out.is_active;
    bool is_valid_instr_EX = datapath.Pipe_ID_EX_NPC_out.is_active;
    bool is_valid_instr_ID = decoded_info != nullptr && datapath.Pipe_IF_ID_Instr_out.is_active;
    bool is_valid_instr_IF = fetched_info != nullptr;

    /**
     * Control word for the instruction in the ID stage.
     */
    uint16_t id_control_word = is_valid_instr_ID ? controlWord(decoded_info) : 0;
    uint16_t if_control_word = is_valid_instr_IF ? controlWord(fetched_info) : 0;

    if(m_logfile.is_open()&&DEBUG_INFO){
        m_logfile << "PC: " << std::hex << pc << ", Instruction: " << instructionString << std::endl
                  << "Valid IF: " << is_valid_instr_IF << std::endl
                  << "Valid ID: " << is_valid_instr_ID << std::endl
                  << "Valid EX: " << is_valid_instr_EX << std::endl
                  << "Valid MEM: " << is_valid_instr_MEM << std::endl
                  << "Valid WB: " << is_valid_instr_WB << std::endl
                  << "id control" << id_control_word << std::endl
                  << "if control" << if_control_word << std::endl
                  << std::endl;

    }

    // =================================================================================
    // ETAPA 5: WRITE-BACK (WB)
    // =================================================================================
    // This stage writes the final result back to the register file.
    // Data comes from the MEM/WB pipeline register.

    // We first check if the instruction is valid and if the MEM/WB stage is active.
    // If not, we skip the write-back stage.

    uint8_t BRwr = 0;  // Inicializamos a 0 (no escribir) por defecto.
    
    try{
    if (is_valid_instr_WB) {
        uint8_t wb_rd = datapath.Pipe_MEM_WB_RD_out.value;
        uint16_t wb_control = datapath.Pipe_MEM_WB_Control_out.value;
        uint8_t ResSrc = controlSignal(wb_control, "ResSrc");
        BRwr = controlSignal(wb_control, "BRwr"); // BRwr is used as RegWrite

        datapath.bus_ResSrc = { ResSrc, 1, is_valid_instr_WB };
        datapath.bus_BRwr = { BRwr, 1, is_valid_instr_WB };

        // MUX C: Selects the final result to be written.
        uint32_t result = mux_C.select(datapath.Pipe_MEM_WB_RM_out.value,       // Data from memory (for loads)
                                       datapath.Pipe_MEM_WB_ALU_result_out.value, // Result from ALU
                                       datapath.Pipe_MEM_WB_NPC_out.value,      // PC+4 (for JAL)
                                       INDETERMINADO,
                                       ResSrc);

        if (BRwr && wb_rd != 0) { // If RegWrite is enabled and destination is not x0
            oldDestinationRegister=register_file.readA(wb_rd);
            register_file.write(wb_rd, result);
            datapath.bus_C = { result, 1,true };

        }
        else {
            datapath.bus_C = { INDETERMINADO, 1, false }; // No write-back
        }


    }
}
    catch(const std::exception& e){
        if(m_logfile.is_open()){
            m_logfile << "Error escribiendo en el registro: " << e.what() << std::endl;

        }
    }




    if(m_logfile.is_open()&&DEBUG_INFO){
        m_logfile << "WB Stage: " << std::endl
                  << "Pipe0: " << datapath.Pipe_MEM_WB_RD.is_active << "\t" << (int)datapath.Pipe_MEM_WB_RD.value << std::endl
                  << "Pipe1: " << datapath.Pipe_MEM_WB_RM.is_active << "\t" << (int)datapath.Pipe_MEM_WB_RM.value << std::endl
                  << "Pipe2: " << datapath.Pipe_MEM_WB_NPC.is_active << "\t" << (int)datapath.Pipe_MEM_WB_NPC.value << std::endl
                  << "Pipe3: " << datapath.Pipe_MEM_WB_ALU_result.is_active << "\t" << (int)datapath.Pipe_MEM_WB_ALU_result.value << std::endl
                  << std::endl;
    }

    // =================================================================================
    // ETAPA 4: MEMORY ACCESS (MEM)
    // =================================================================================
    // Accesses data memory for loads and stores.
    // Data comes from the EX/MEM pipeline register.
    uint32_t mem_read_data = INDETERMINADO;
    bool isLWorSW=false;
    try{
    if (datapath.Pipe_EX_MEM_Control_out.is_active) {
        uint16_t mem_control = datapath.Pipe_EX_MEM_Control_out.value;
        uint32_t alu_result = datapath.Pipe_EX_MEM_ALU_result_out.value;
        uint8_t MemWr = controlSignal(mem_control, "MemWr");
        datapath.bus_MemWr = { MemWr, 1, datapath.Pipe_EX_MEM_Control_out.is_active };


        if (MemWr == 1) { // Store instruction (e.g., SW)
            d_mem.write_word(alu_result, datapath.Pipe_EX_MEM_B_out.value);
            isLWorSW=true;
        } else if (controlSignal(mem_control, "ResSrc") == 0) { // Load instruction (e.g., LW)
            mem_read_data = d_mem.read_word(alu_result,true);
            isLWorSW=true;
        }
    }
    datapath.bus_Mem_read_data = { mem_read_data, 1, isLWorSW };

    // Pass data to the next stage's register (MEM/WB)
    datapath.Pipe_MEM_WB_Control      = datapath.Pipe_EX_MEM_Control_out;
    datapath.Pipe_MEM_WB_NPC          = datapath.Pipe_EX_MEM_NPC_out;
    datapath.Pipe_MEM_WB_ALU_result   = datapath.Pipe_EX_MEM_ALU_result_out;
    datapath.Pipe_MEM_WB_RD           = datapath.Pipe_EX_MEM_RD_out;
    datapath.Pipe_MEM_WB_RM           = {mem_read_data, 1, is_valid_instr_MEM};

}
catch(const std::exception& e){
    m_logfile << "Error accessing memory: " << e.what() << std::endl;
}

    if(m_logfile.is_open()&&DEBUG_INFO){
        m_logfile << "MEM Stage: " << std::endl
                    << "Pipe0: " << datapath.Pipe_EX_MEM_RD.is_active << "\t" << (int)datapath.Pipe_EX_MEM_RD.value << std::endl
                    << "Pipe1: " << datapath.Pipe_EX_MEM_B.is_active << "\t" << (int)datapath.Pipe_EX_MEM_B.value << std::endl
                    << "Pipe2: " << datapath.Pipe_EX_MEM_ALU_result.is_active << "\t" << (int)datapath.Pipe_EX_MEM_ALU_result.value << std::endl
                    << "Pipe3: " << datapath.Pipe_EX_MEM_NPC.is_active << "\t" << (int)datapath.Pipe_EX_MEM_NPC.value << std::endl
                    << std::endl;
    }






    // =================================================================================
    // ETAPA 3: EXECUTE (EX)
    // =================================================================================
    // Performs the calculation in the ALU.
    // Data comes from the ID/EX pipeline register.
    uint32_t alu_result = INDETERMINADO;
    bool alu_zero = false;
    uint32_t pc_plus_imm = 0;
    bool take_branch = false;

    uint32_t forwarded_a = datapath.Pipe_ID_EX_A_out.value;
    uint32_t forwarded_b = datapath.Pipe_ID_EX_B_out.value;

    if (is_valid_instr_EX && FORWARDING) {
        // --- FORWARDING UNIT LOGIC ---
        // Determina si necesitamos cortocircuitar datos desde las etapas MEM o WB a la etapa EX.

        // Registros fuente de la instrucción en la etapa EX (leídos desde el registro ID/EX)
        uint8_t ex_rs1_addr = datapath.Pipe_ID_EX_RS1_out.value;
        uint8_t ex_rs2_addr = datapath.Pipe_ID_EX_RS2_out.value;

        // Registros destino de las instrucciones en etapas posteriores
        uint8_t ex_mem_rd = datapath.Pipe_EX_MEM_RD_out.value;
        uint8_t mem_wb_rd = datapath.Pipe_MEM_WB_RD_out.value;

        // Señales de control de escritura en registro de etapas posteriores
        bool ex_mem_reg_write = datapath.Pipe_EX_MEM_Control_out.is_active && controlSignal(datapath.Pipe_EX_MEM_Control_out.value, "BRwr");
        bool mem_wb_reg_write = datapath.Pipe_MEM_WB_Control_out.is_active && controlSignal(datapath.Pipe_MEM_WB_Control_out.value, "BRwr");

        // Lógica para Forward A (operando rs1)
        if (ex_mem_reg_write && ex_mem_rd != 0 && ex_mem_rd == ex_rs1_addr) {
            datapath.bus_ControlForwardA = {0, 1, true}; // Forward desde MEM (ALU result)
            forwarded_a = datapath.Pipe_EX_MEM_ALU_result_out.value;
        } else if (mem_wb_reg_write && mem_wb_rd != 0 && mem_wb_rd == ex_rs1_addr) {
            datapath.bus_ControlForwardA = {2, 1, true}; // Forward desde WB (resultado final)
            forwarded_a = datapath.bus_C.value; // bus_C contiene el resultado final de la etapa WB
        } else {
            datapath.bus_ControlForwardA = {1, 1, false}; // Sin forwarding
        }

        // Lógica para Forward B (operando rs2)
        if (ex_mem_reg_write && ex_mem_rd != 0 && ex_mem_rd == ex_rs2_addr) {
            datapath.bus_ControlForwardB = {0, 1, true}; // Forward desde MEM
            forwarded_b = datapath.Pipe_EX_MEM_ALU_result_out.value;
        } else if (mem_wb_reg_write && mem_wb_rd != 0 && mem_wb_rd == ex_rs2_addr) {
            datapath.bus_ControlForwardB = {2, 1, true}; // Forward desde WB
            forwarded_b = datapath.bus_C.value;
        } else {
            datapath.bus_ControlForwardB = {1, 1, false}; // Sin forwarding
        }

        // Actualizamos los buses de datos que salen de los Mux de Forwarding
        datapath.bus_ForwardA = {forwarded_a, 1, datapath.bus_ControlForwardA.is_active};
        datapath.bus_ForwardB = {forwarded_b, 1, datapath.bus_ControlForwardB.is_active};
    }
    uint32_t alu_op_b=INDETERMINADO;
    try{
    if (datapath.Pipe_ID_EX_Control_out.is_active) {
        uint16_t ex_control = datapath.Pipe_ID_EX_Control_out.value;
        uint8_t ALUsrc = controlSignal(ex_control, "ALUsrc");
        uint8_t ALUctr = controlSignal(ex_control, "ALUctr");
        uint8_t PCsrc = controlSignal(ex_control, "PCsrc");

        // MUX B: Selects the second operand for the ALU.
        alu_op_b = mux_B.select(datapath.Pipe_ID_EX_Imm_out.value, forwarded_b, ALUsrc);

        m_logfile << "ALUsrc: "<< ALUsrc << std::endl;

        // ALU Execution
        alu_result = alu.calc(forwarded_a, alu_op_b, ALUctr);
        alu_zero = (alu_result == 0);

        // *** BUG FIX ***: Correct branch target calculation.
        // It uses the PC from the ID/EX register, not the current global PC.
        pc_plus_imm = datapath.Pipe_ID_EX_PC_out.value + datapath.Pipe_ID_EX_Imm_out.value;
        
        bool condition_met = false;
        if (PCsrc == 1) { // Salto condicional (B-type) o JAL
            if (controlSignal(ex_control, "BRwr") == 0) { // Es un salto condicional (no escribe en registro)
                uint8_t funct3 = datapath.Pipe_ID_EX_RD_out.value; // funct3 se pasó en el campo RD
                switch (funct3) {
                    case 0b000: // beq
                        condition_met = alu_zero;
                        break;
                    case 0b001: // bne
                        condition_met = !alu_zero;
                        break;
                    // Aquí se pueden añadir más saltos condicionales (blt, bge, etc.)
                }
            } else { // Es JAL (salto incondicional que escribe en registro)
                condition_met = true;
            }
        }
        take_branch = (PCsrc == 1 && condition_met) || PCsrc == 2; // PCsrc=2 para JALR
        datapath.bus_ALUsrc={ALUsrc,1,is_valid_instr_EX};
        datapath.bus_ALUctr={ALUctr,1,is_valid_instr_EX};
        datapath.bus_PCsrc={PCsrc,1,is_valid_instr_EX};


    }
    
}
    catch(const std::exception& e)
    {
        m_logfile <<  "Error en la ejecución de la ALU: " << e.what() << std::endl; 
        alu_result=INDETERMINADO;
        alu_zero=false;
        pc_plus_imm=0;
        take_branch=false;
    }
    // --- CONTROL HAZARD (BRANCH FLUSH) ---
    if(BRANCH_FLUSH)
    if (take_branch) {
        flush = true;
    }

    // Pass data to the next stage's register (EX/MEM)
    datapath.Pipe_EX_MEM_ALU_result ={ alu_result,1, is_valid_instr_EX}; // Pass the ALU result
    datapath.Pipe_EX_MEM_B  = {forwarded_b,1, is_valid_instr_EX}; // Pass the (potentially forwarded) value of rs2 for stores
    datapath.Pipe_EX_MEM_RD         = {datapath.Pipe_ID_EX_RD_out.value,1, is_valid_instr_EX};

    datapath.Pipe_EX_MEM_Control    =datapath.Pipe_ID_EX_Control_out;
    datapath.Pipe_EX_MEM_NPC        = datapath.Pipe_ID_EX_NPC_out;

    // Internal buses for this stage
    datapath.bus_PC_dest = {pc_plus_imm, 1, is_valid_instr_EX}; // Pass the branch target to the next stage
    datapath.bus_ALU_result = {alu_result, 1, is_valid_instr_EX}; // Pass the ALU result to the next stage
    datapath.bus_ALU_zero = {alu_zero, 1, is_valid_instr_EX}; // Pass the ALU zero flag to the next stage
    datapath.bus_branch_taken = {take_branch, 1, is_valid_instr_EX}; // Pass the branch taken signal to the next stage
    datapath.bus_ALU_B = {alu_op_b, 1, is_valid_instr_EX}; // Pass the second ALU operand to the next stage
    
    if(m_logfile.is_open()&&DEBUG_INFO){
        m_logfile << "EX Stage: " << std::endl
                  << "ID/EX RDestino: " << datapath.Pipe_ID_EX_RD.is_active << "\t" << (int)datapath.Pipe_ID_EX_RD.value << std::endl
                  << "ID/EX A: " << datapath.Pipe_ID_EX_A.is_active << "\t" << (int)datapath.Pipe_ID_EX_A.value << std::endl
                  << "ID/EX B: " << datapath.Pipe_ID_EX_B.is_active << "\t" << (int)datapath.Pipe_ID_EX_B.value << std::endl
                  << "ID/EX Imm: " << datapath.Pipe_ID_EX_Imm.is_active << "\t" << (int)datapath.Pipe_ID_EX_Imm.value << std::endl
                  << "ID/EX NPC: " << datapath.Pipe_ID_EX_NPC.is_active << "\t" << (int)datapath.Pipe_ID_EX_NPC.value << std::endl
                  << "ID/EX PC: " << datapath.Pipe_ID_EX_PC.is_active << "\t" << (int)datapath.Pipe_ID_EX_PC.value << std::endl
                  << "alu_op_b: " << alu_op_b << std::endl

                  << "ALU Result: " << alu_result << ", Zero: " << alu_zero 
                  << ", Branch Target: " << pc_plus_imm 
                  << ", Take Branch: " << take_branch 
                  << std::endl;
    }

    // =================================================================================
    // ETAPA 2: INSTRUCTION DECODE (ID)
    // =================================================================================
    // Decodes instruction, reads registers.
    // Data comes from the IF/ID pipeline register.

    uint8_t ImmSrc = is_valid_instr_ID ? controlSignal(id_control_word, "ImmSrc") : 0;
    

    // --- LOAD-USE HAZARD DETECTION (STALL) ---
    stall = false;
    if (LOAD_USE_HAZARD) {
        // A load-use hazard occurs if the instruction in the EX stage is a load (lw)
        // and its destination register (rd) is one of the source registers (rs1 or rs2)
        // of the instruction currently in the ID stage.
        if (datapath.Pipe_ID_EX_Control_out.is_active) {
            uint16_t ex_control = datapath.Pipe_ID_EX_Control_out.value;
            uint8_t ex_ResSrc = controlSignal(ex_control, "ResSrc");
            uint8_t ex_BRwr = controlSignal(ex_control, "BRwr");

            if (ex_ResSrc == 0 && ex_BRwr == 1) { // Es load
                uint8_t ex_rd = datapath.Pipe_ID_EX_RD_out.value;

                // Get the source registers for the instruction currently in the ID stage
                uint32_t id_instr = datapath.Pipe_IF_ID_Instr_out.value;
                uint8_t id_rs1 = (id_instr >> 15) & 0x1F;
                uint8_t id_rs2 = (id_instr >> 20) & 0x1F;

                // Check for dependency: if the destination of the load in EX is used as a source in ID
                if (ex_rd != 0 && (ex_rd == id_rs1 || ex_rd == id_rs2)) {
                    stall = true;
                    
                }
            }
        }
    }

    // Asignamos el estado de los buses de riesgo después de haberlos calculado.
    datapath.bus_stall = { stall, 1, stall };
    datapath.bus_flush = { flush, 1, flush };

    if (flush) {
        // Squash the instruction in the ID stage by passing a NOP to the EX stage.
        id_control_word = 0;
        if_control_word = 0;
        is_valid_instr_ID = false;



        datapath.Pipe_ID_EX_Control = {0, 1, false}; // Control signals for NOP, inactive
        datapath.Pipe_ID_EX_A = {0, 1, false};
        datapath.Pipe_ID_EX_B = {0, 1, false};
        datapath.Pipe_ID_EX_RD = {0, 1, false};
        datapath.Pipe_ID_EX_Imm = {0, 1, false};
        datapath.Pipe_ID_EX_NPC = {0, 1, false};
        datapath.Pipe_ID_EX_PC = {0, 1, false};

        strcpy(datapath.Pipe_IF_instruction_cptr , "nop (flush)");
        if(m_logfile.is_open()&&DEBUG_INFO)        m_logfile << "Flush detectado: " << std::endl;

    } else if (stall) {
        // Inject a "bubble" (NOP) into the pipeline
        datapath.Pipe_ID_EX_Control = {0, 1, false};        if(m_logfile.is_open()&&DEBUG_INFO)        m_logfile << "Stall detectado: " << std::endl;
        datapath.Pipe_ID_EX_A = {0, 1, false};
        datapath.Pipe_ID_EX_B = {0, 1, false};
        datapath.Pipe_ID_EX_RD = {0, 1, false};
        datapath.Pipe_ID_EX_Imm = {0, 1, false};
        datapath.Pipe_ID_EX_NPC = {0, 1, false};
        datapath.Pipe_ID_EX_PC = {0, 1, false};


    } else {
        // Normal operation

        uint32_t instruction_in_id = datapath.Pipe_IF_ID_Instr_out.value;
        uint8_t rs1_addr = (instruction_in_id >> 15) & 0x1F;
        uint8_t rs2_addr = (instruction_in_id >> 20) & 0x1F;
        uint8_t rd_addr  = (instruction_in_id >> 7)  & 0x1F;

        uint32_t regAcontent=register_file.readA(rs1_addr);
        uint32_t regBcontent=register_file.readB(rs2_addr);
        if(!WRITEFIRST)
        {
            if(rs1_addr==datapath.Pipe_MEM_WB_RD_out.value && BRwr)regAcontent=oldDestinationRegister;
            if(rs2_addr==datapath.Pipe_MEM_WB_RD_out.value && BRwr)regBcontent=oldDestinationRegister;
        }
        datapath.Pipe_ID_EX_A = {regAcontent,1,is_valid_instr_ID};
        datapath.Pipe_ID_EX_B = {regBcontent,1,is_valid_instr_ID};


        // --- REUTILIZACIÓN DE Pipe_ID_EX_RD para funct3 en saltos ---
        // Si la instrucción es de tipo 'B', usamos el registro RD (que no se usa en saltos)
        // para pasar el campo funct3 a la siguiente etapa.
        if (is_valid_instr_ID && decoded_info->type == 'B') {
            uint8_t funct3 = (instruction_in_id >> 12) & 0x7;
            datapath.Pipe_ID_EX_RD = {funct3, 1, is_valid_instr_ID};
        } else {
            datapath.Pipe_ID_EX_RD = {rd_addr,1,is_valid_instr_ID};
        }

        datapath.Pipe_ID_EX_RS1 = {rs1_addr, 1, is_valid_instr_ID};
        datapath.Pipe_ID_EX_RS2 = {rs2_addr, 1, is_valid_instr_ID};

        datapath.Pipe_ID_EX_Imm = {sign_extender.extender(instruction_in_id, ImmSrc),1,is_valid_instr_ID};

        datapath.Pipe_ID_EX_Control= {id_control_word,1,is_valid_instr_ID}; //No necesitaríamos todo. Parte ya se ha consumido en ID.
        datapath.Pipe_ID_EX_NPC = datapath.Pipe_IF_ID_NPC_out;
        datapath.Pipe_ID_EX_PC = datapath.Pipe_IF_ID_PC_out;

        //Buses de esta etapa
        datapath.bus_DA = { rs1_addr, 1, is_valid_instr_ID }; // DA is the address of the first source register
        datapath.bus_DB = { rs2_addr, 1, is_valid_instr_ID }; // DB is the address of the second source register
        datapath.bus_DC = { rd_addr, 1, is_valid_instr_ID }; // DC is the address of the destination register
        datapath.bus_opcode = { (uint8_t)(instruction_in_id & 0x7F), 1, is_valid_instr_ID }; // Opcode is the last 7 bits
        datapath.bus_funct3 = { (uint8_t)((instruction_in_id >> 12) & 0x07), 1, is_valid_instr_ID }; // Funct3 is bits 12-14
        datapath.bus_funct7 = { (uint8_t)((instruction_in_id >> 25) & 0x7F), 1, is_valid_instr_ID }; // Funct7 is bits 25-31
        //datapath.bus_Instr = { instruction_in_id, 1, is_valid_instr_ID }; // The instruction itself
        //datapath.bus_stall = { stall, 1, stall };
        //datapath.bus_flush = { flush, 1, flush };

        datapath.bus_A = { datapath.Pipe_ID_EX_A.value, 1, is_valid_instr_ID }; // Value of the first source register
        datapath.bus_B = { datapath.Pipe_ID_EX_B.value, 1, is_valid_instr_ID }; // Value of the second source register
        datapath.bus_imm = { instruction_in_id, 1, is_valid_instr_ID }; // Immediate value (not yet extended)
        datapath.bus_immExt = { datapath.Pipe_ID_EX_Imm.value, 1, is_valid_instr_ID }; // Extended immediate value

        datapath.bus_ImmSrc = { ImmSrc, 1, is_valid_instr_ID }; // ImmSrc
        if(m_logfile.is_open()&&DEBUG_INFO)        m_logfile << "No flush no stall: " << std::endl;

    }

    if(m_logfile.is_open()&&DEBUG_INFO){
        m_logfile << "ID Stage: " << std::endl
                  << "id control" << id_control_word << std::endl
                  << "if control" << if_control_word << std::endl
                  << "immSrc" << (int)ImmSrc << std::endl
                  << "IDctr: " << datapath.Pipe_ID_EX_Control.value << std::endl
                  << "Pipe0: " << datapath.Pipe_IF_ID_Instr.is_active << "\t" << (int)datapath.Pipe_IF_ID_Instr.value << std::endl
                  << "Pipe1: " << datapath.Pipe_ID_EX_Control.is_active << "\t" << (int)datapath.Pipe_ID_EX_Control.value << std::endl
                  << "Pipe2: " << datapath.Pipe_ID_EX_NPC.is_active << "\t" << (int)datapath.Pipe_ID_EX_NPC.value << std::endl
                  << "Pipe3: " << datapath.Pipe_ID_EX_PC.is_active << "\t" << (int)datapath.Pipe_ID_EX_PC.value << std::endl
                  << "Pipe4: " << datapath.Pipe_ID_EX_A.is_active << "\t" << (int)datapath.Pipe_ID_EX_A.value << std::endl
                  << "Pipe5: " << datapath.Pipe_ID_EX_B.is_active << "\t" << (int)datapath.Pipe_ID_EX_B.value << std::endl
                  << "Pipe6: " << datapath.Pipe_ID_EX_RD.is_active << "\t" << (int)datapath.Pipe_ID_EX_RD.value << std::endl
                  << "Pipe7: " << datapath.Pipe_ID_EX_Imm.is_active  << "\t"  << (int)datapath.Pipe_ID_EX_Imm.value  << std::endl;
                  //<< "Instruction: "  + instructionString 
                  //<< ", Opcode: " + std::to_string(datapath.bus_Opcode.value)
                  //<< ", Funct3: " + std::to_string(datapath.bus_funct3.value)
                  //<< ", Funct7: " + std::to_string(datapath.bus_funct7.value)
                  //<< ", DA: " + std::to_string(datapath.bus_DA.value)
                  //<< ", DB: " + std::to_string(datapath.bus_DB.value)
                  //<< ", DC: " + std::to_string(datapath.bus_DC.value)
                  //<< ", A: " + std::to_string(datapath.bus_A.value)
                  //<< ", B: " + std::to_string(datapath.bus_B.value)
                  //<< ", Imm: " + std::to_string(datapath.bus_imm.value)
                  //<< ", ImmExt: " + std::to_string(datapath.bus_imm
    }
    // =================================================================================
    // ETAPA 1: INSTRUCTION FETCH (IF)
    // =================================================================================
    // Fetches the next instruction from memory.
    
if(!BRANCH_FLUSH)flush=false;


    datapath.bus_Control = { id_control_word, 1 }; //En dart es 'Control'


    // Registro pipeline a final de etapa
    datapath.Pipe_IF_ID_Instr = {instruction,1, is_valid_instr_IF}; // PC + 4 
    datapath.Pipe_IF_ID_NPC = {pc+4,1, is_valid_instr_IF}; // PC + 4 
    datapath.Pipe_IF_ID_PC =  {pc ,1, is_valid_instr_IF};

    if(flush){
        datapath.Pipe_IF_ID_Instr = { 0x00000013, 1, false };// No sólo nop en ID, también en IF
        is_valid_instr_IF = false;
        datapath.Pipe_IF_ID_NPC = {0, 1, false}; //Este cero se usa en el visualizador para ponerla en gris
        datapath.Pipe_IF_ID_PC = {0, 1, false};
        datapath.bus_Control={0,1,false};

    }
    if(stall){
        datapath.Pipe_IF_ID_Instr = datapath.Pipe_IF_ID_Instr_out; //;// No change, we keep the previous instruction in IF/ID
    }


    //No calculamos los bits de control. Le pasamos la instrucción a la siguiente etapa

    // Buses internos de esta etapa
    datapath.bus_PC = { pc, 1, true }; // El PC se actualiza en la etapa IF
    datapath.bus_PC_plus4 = { pc +4, 1, true }; // PC + 4 para la siguiente instrucción
    datapath.bus_Instr={instruction,1,is_valid_instr_IF}; // La instrucción se lee en la etapa IF
    //datapath.bus_DC = { (uint8_t)((instruction >> 7) & 0x1F), 1, is_valid_instr_IF }; // DC is the destination register address


    if(m_logfile.is_open() && DEBUG_INFO) {
        m_logfile << "IF Stage: " << std::endl
                  << "PipeI: " << datapath.Pipe_IF_ID_Instr.is_active << "\t" << (int)datapath.Pipe_IF_ID_Instr.value << std::endl
                  << "PipeN: " << datapath.Pipe_IF_ID_NPC.is_active << "\t" << (int)datapath.Pipe_IF_ID_NPC.value << std::endl
                  << "PipeP: " << datapath.Pipe_IF_ID_PC.is_active << "\t" << (int)datapath.Pipe_IF_ID_PC.value << std::endl
                  << "Instruction: " + instructionString 
                  << ", PC: " + std::to_string(pc)
                  << ", PC+4: " + std::to_string(pc + 4)
                  << ", Stall: " + std::to_string(stall)
                  << ", Flush: " + std::to_string(flush)
                  << std::endl;
    }
 
    // =================================================================================
    // PC Update Logic
    // =================================================================================
    // This logic determines the PC for the *next* cycle's IF stage.
    if (!stall) {
        if (take_branch) {
            // Para JALR (I-type jump), el destino es el resultado de la ALU.
            // Para JAL (J-type) y branches (B-type), es PC + inmediato.
            uint16_t ex_control = datapath.Pipe_ID_EX_Control_out.value;
            if (controlSignal(ex_control, "PCsrc") == 2 && controlSignal(ex_control, "ImmSrc") == 0) { // JALR (ImmSrc I-type)
                pc = alu_result;
            } else { // JAL o Branch
                pc = pc_plus_imm;
            }
        } else {
            pc = pc + 4;
        }
    }
    datapath.bus_PC_next={pc ,1,true};

    // If stalling, the PC is not updated, freezing the fetch stage.

    // =================================================================================
    // LABELLING PIPELINE STAGES
    // This section updates the instruction values for display in each stage,
    // correctly handling stalls and flushes.
    // =================================================================================

    // --- Update the display variables this cycle ---
    datapath.Pipe_WB_instruction = prev_mem_instr;
    datapath.Pipe_MEM_instruction = prev_ex_instr;
    datapath.Pipe_EX_instruction = prev_id_instr;
    

    if (flush) { //El flush se detecta en la etapa ex
        datapath.Pipe_IF_instruction = 0x00000013; // Bubble 2 (replaces instruction from IF)
        datapath.Pipe_ID_instruction = 0x00000013; // Bubble 1 (replaces instruction from ID)
        datapath.Pipe_IF_ID_Instr_out = { 0x00000013, 1, false }; // Bubble
        datapath.bus_imm={ 0x00000013, 1, false };
        datapath.bus_DA= datapath.bus_DB= datapath.bus_DC= { 0, 1, false };
        datapath.bus_immExt={ 0, 1, false };
        
    } else if (stall) { //Se detecta en ex, al descubrir que la que hay en id depende
        // Data hazard (load-use): Insert a bubble in EX and freeze ID/IF.
        datapath.Pipe_ID_instruction = 0x00000013; // Bubble
        datapath.Pipe_IF_instruction = prev_if_instr;
        datapath.Pipe_IF_ID_Instr_out = { 0x00000013, 1, false }; // Bubble
        datapath.bus_imm={ 0x00000013, 1, false };
        datapath.bus_DA= datapath.bus_DB= datapath.bus_DC= { 0, 1, false };
        datapath.bus_immExt={ 0, 1, false };
    } else {
        // Normal operation: Advance instructions.
        datapath.Pipe_ID_instruction = prev_if_instr;
        datapath.Pipe_IF_instruction = instruction;
    }
    // The IF stage always fetches the next instruction, which is correct
    // because the PC was updated based on the branch outcome.

    // Usamos strncpy para evitar desbordamientos de búfer.
    strncpy(datapath.instruction_cptr, instructionString.c_str(), sizeof(datapath.instruction_cptr) - 1);
    datapath.instruction_cptr[sizeof(datapath.instruction_cptr) - 1] = '\0'; // Aseguramos la terminación nula.

    // Now, generate the disassembled strings from the final instruction values
    auto copy_safe = [this](char* dest, const std::string& src) {
        strncpy(dest, src.c_str(), sizeof(datapath.instruction_cptr) - 1);
        dest[sizeof(datapath.instruction_cptr) - 1] = '\0';
    };

    copy_safe(datapath.Pipe_IF_instruction_cptr, disassemble(datapath.Pipe_IF_instruction, control_unit.decode(datapath.Pipe_IF_instruction)));
    copy_safe(datapath.Pipe_ID_instruction_cptr, disassemble(datapath.Pipe_ID_instruction, control_unit.decode(datapath.Pipe_ID_instruction)));
    copy_safe(datapath.Pipe_EX_instruction_cptr, disassemble(datapath.Pipe_EX_instruction, control_unit.decode(datapath.Pipe_EX_instruction)));
    copy_safe(datapath.Pipe_MEM_instruction_cptr, disassemble(datapath.Pipe_MEM_instruction, control_unit.decode(datapath.Pipe_MEM_instruction)));
    copy_safe(datapath.Pipe_WB_instruction_cptr, disassemble(datapath.Pipe_WB_instruction, control_unit.decode(datapath.Pipe_WB_instruction)));
    if(m_logfile.is_open() && DEBUG_INFO) {
        m_logfile << "Pipeline Stage 1 (IF): " << datapath.Pipe_IF_instruction_cptr << std::endl;
        m_logfile << "Pipeline Stage 2 (ID): " << datapath.Pipe_ID_instruction_cptr << std::endl;
        m_logfile << "Pipeline Stage 3 (EX): " << datapath.Pipe_EX_instruction_cptr << std::endl;
        m_logfile << "Pipeline Stage 4 (MEM): " << datapath.Pipe_MEM_instruction_cptr << std::endl;
        m_logfile << "Pipeline Stage 5 (WB): " << datapath.Pipe_WB_instruction_cptr << std::endl;
        m_logfile << "Next PC: " << std::hex << pc << std::endl;
    }
    
}
