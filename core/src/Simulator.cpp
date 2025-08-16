#include "Simulator.h"
#include <iostream> // Para depuración, se puede quitar después
#include <stdexcept>
#include <algorithm> // Para std::max
#include <sstream>
#include <vector>

#define DELAY_Z_AND 1
#define DELAY_PC 1

// (Puedes ponerlo como un método privado o función estática)
std::string Simulator::disassemble(uint32_t instruction, const InstructionInfo* info) const {
    if (!info) return "not implemented";

    // Extraer campos comunes (ya los tienes en decode_and_execute, pásalos aquí o recalcúlalos)
    uint32_t rd  = (instruction >> 7) & 0x1F;
    uint32_t rs1 = (instruction >> 15) & 0x1F;
    uint32_t rs2 = (instruction >> 20) & 0x1F;
    int32_t imm  = static_cast<int32_t>(instruction) >> 20; // I-type, puede variar según tipo

    std::ostringstream oss;

    // Mostrar el nombre mnemónico
    oss << info->instr << " ";

    // Según el tipo de instrucción
    switch (info->type) {
        case 'R': // ej. add rd, rs1, rs2
            oss << "x" << rd << ", x" << rs1 << ", x" << rs2;
            break;
        case 'I': // ej. addi rd, rs1, imm
            oss << "x" << rd << ", x" << rs1 << ", " << imm;
            break;
        case 'S': { // ej. sw rs2, imm(rs1)
            const uint32_t imm11_5 = (instruction >> 25) & 0x7F;
            const uint32_t imm4_0  = (instruction >> 7)  & 0x1F;
            uint32_t imm_s = (imm11_5 << 5) | imm4_0;
            if (imm_s & 0x800) { // Sign-extend from 12 bits
                imm_s |= 0xFFFFF000;
            }
            oss << "x" << rs2 << ", " << static_cast<int32_t>(imm_s) << "(x" << rs1 << ")";
            break;
        }
        case 'B': { // ej. beq rs1, rs2, imm
            const uint32_t imm12   = (instruction >> 19) & 0x1000; // bit 31 -> bit 12
            const uint32_t imm11   = (instruction << 4)  & 0x800;  // bit 7  -> bit 11
            const uint32_t imm10_5 = (instruction >> 20) & 0x7E0;  // bits 30:25 -> 10:5
            const uint32_t imm4_1  = (instruction >> 7)  & 0x1E;   // bits 11:8  -> 4:1
            uint32_t imm_b   = imm12 | imm11 | imm10_5 | imm4_1;

            // Sign-extend from 13 bits
            if (imm_b & 0x1000) {
                imm_b |= 0xFFFFE000;
            }
            oss << "x" << rs1 << ", x" << rs2 << ", " << static_cast<int32_t>(imm_b);
            break;
        }
        case 'U': { // ej. lui rd, imm
            const uint32_t imm = instruction >> 12;
            oss << "x" << rd << ", 0x" << std::hex << imm;
            break;
        }
        case 'J': { // ej. jal rd, imm
            const uint32_t imm20    = (instruction >> 11) & 0x100000; // bit 31 -> bit 20
            const uint32_t imm19_12 = instruction & 0xFF000;          // bits 19:12
            const uint32_t imm11    = (instruction >> 9)  & 0x800;    // bit 20 -> bit 11
            const uint32_t imm10_1  = (instruction >> 20) & 0x7FE;    // bits 30:21 -> 10:1
            uint32_t imm_j    = imm20 | imm19_12 | imm11 | imm10_1;

            // Sign-extend from 21 bits
            if (imm_j & 0x100000) {
                imm_j |= 0xFFE00000;
            }
            oss << "x" << rd << ", " << static_cast<int32_t>(imm_j);
            break;
        }
        default:
            oss << std::hex << "0x" << instruction;
    }

    return oss.str();
}

// Constructor: Inicializa los componentes del simulador.
Simulator::Simulator(size_t mem_size, PipelineModel model)
    : pc(0),
      current_cycle(0),
      status_reg(0), // Inicializamos el registro de estado a 0
      register_file(),
      model(model),
      memory(mem_size),
      i_cache(256, 16, memory),//No usado
      d_cache(256, 16, memory),//No usado
      i_mem(256), // Memoria de instrucciones para modo didáctico
      d_mem(256),  // Memoria de datos para modo didáctico
      history_pointer(0),
      datapath{}
{
    // El PC se inicializa en 0.
      // NOTA: La ruta al fichero de instrucciones debería ser configurable, no "hard-coded".
      // Por ejemplo, podría pasarse al constructor o leerse de una variable de entorno.
      
      if(false)//Pensar si es mejor o peor ToDo
      control_unit.load_control_table("d:/onedrive/proyectos/riscv/resources/instructions.json");
      
      
      // Abrir el fichero de log. Se sobreescribirá en cada nueva ejecución.
      m_logfile.open("simulator.log", std::ios::out | std::ios::trunc);
      m_logfile << "--- Log del Simulador RISC-V ---" << std::endl;

      // Reservar espacio para el historial para evitar realojamientos frecuentes
      history.reserve(1024);
      
}

// Carga un programa en la memoria del simulador.
void Simulator::load_program(const std::vector<uint8_t>& program, PipelineModel model) {
    // La carga depende del modo de pipeline.
    if (model == PipelineModel::General) {
        m_logfile << "\n--- Programa cargado en memoria (modo general)" << program[0] << " ---" << std::endl;
        memory.load_program(program, 0);
    } else {
        // En modo didáctico, el programa se carga en la memoria de instrucciones.
        // La memoria de datos permanece vacía inicialmente.
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
        m_logfile << "Instruccion leída: 0x" << std::hex << instruction << std::dec << std::endl;

    }
    current_cycle++; // Avanzamos el ciclo de instruccion//reloj
    decode_and_execute(instruction);
    if (m_logfile.is_open()) {
        m_logfile << "Instruccion ejecutada: 0x" << std::hex << instruction << std::dec << std::endl;

    }
}

// Ejecuta un ciclo completo: fetch, decode, execute.
void Simulator::reset(PipelineModel model) {
    // Actualizamos el modelo del simulador con el que nos pasan.
    this->model = model;
    pc = 0;
    current_cycle = 0;
    status_reg = 0;
    register_file.reset();
    datapath = {};
    instructionString = "";
    // Después de resetear, ejecutamos el primer ciclo para que la UI muestre
    // el estado inicial con la primera instrucción (la de PC=0) ya procesada.

    // Limpiar el historial
    history.clear();
    history_pointer = 0;

    if (m_logfile.is_open()) {
        m_logfile << "Model:" << (int) model << std::endl;
        m_logfile << "\n--- Reseteando ---" << std::endl;
        m_logfile << "PC: 0x" << std::hex << pc << std::dec << std::endl;
        m_logfile << "\n--- Localizando la primera instruccion ---" << std::endl;
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

// Fase de Fetch: Lee la siguiente instrucción de la memoria.
uint32_t Simulator::fetch() {
    // Lee una palabra de 32 bits (4 bytes) desde la caché de instrucciones.
    if (model == PipelineModel::General) {
        return i_cache.read_word(pc);
    } else {
        // En modo didáctico, lee directamente de la memoria de instrucciones.
            m_logfile << "Model:" << (int) model << std::endl;
            uint32_t instruction=i_mem.read_word(pc);
            m_logfile << "Instrucción:" << (int) instruction << std::endl;
        return instruction;
    }
    
}


uint16_t controlWord(const InstructionInfo* info) {
    return (info->ALUctr  & 0x7) << 13 |  // 3 bits
           (info->ResSrc & 0x3) << 11 |  // 2 bits
           (info->ImmSrc & 0x7) << 8  |  // 3 bits
           (info->PCsrc  & 0x3) << 6  |  // 2 bit
           (info->ALUsrc   & 0x1) << 4  |  // 1 bit
           (info->BRwr & 0x1) << 3  |  // 1 bit
           (info->MemWr  & 0x1) << 2 | 0;    // 1 bit
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
    datapath.bus_Opcode={(uint8_t)(instruction & 0x3F),tmptime};
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
    //datapath.instruction=instructionString;
    datapath.total_micro_cycles = info->cycles;
    strcpy(datapath.instruction_cptr,instructionString.c_str());
    }
    catch(const std::exception& e){
        m_logfile << "Error al formatear la instrucción: " << e.what() << std::endl;
        pc = pc_plus_4;
        return;
    }


    try{
    datapath.bus_Control = {controlWord(info),tmptime+control_unit.get_delay()};
    if (m_logfile.is_open()) {
        m_logfile << "Info: instr=" << info->instr << ", PCsrc=" << static_cast<int>(info->PCsrc)
                  << ", BRwr=" << static_cast<int>(info->BRwr) << ", ALUsrc=" << static_cast<int>(info->ALUsrc)
                  << ", ALUctr=" << static_cast<int>(info->ALUctr) << ", MemWr=" << static_cast<int>(info->MemWr)
                  << ", ResSrc=" << static_cast<int>(info->ResSrc) << ", ImmSrc=" << static_cast<int>(info->ImmSrc)
                  << ", type=" << info->type << std::endl;
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



    
    uint32_t branch_target = adder.add(pc, imm_ext);
    datapath.bus_PC_dest       = {branch_target, datapath.bus_immExt.ready_at+ adder.get_delay()};


    m_logfile <<  "ALU ok" << std::endl; 


    // 4. ACCESO A MEMORIA
    uint32_t mem_read_data = 0x00FABADA;


    if(info->instr=="lw")
    try{
    mem_read_data = d_mem.read_word(alu_result);
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
    bool take_branch = (info->PCsrc == 1|| (info->type=='B' && alu_zero));

    uint32_t tmptime5 = std::max(datapath.bus_ALU_zero.ready_at,datapath.bus_Control.ready_at)+DELAY_Z_AND; //Tiempo en llegar la sñal que controla el mux
    
    datapath.bus_branch_taken = {take_branch,tmptime5};
    datapath.bus_PCsrc.ready_at = tmptime5;


    tmptime5 = std::max(std::max(datapath.bus_PC_plus4.ready_at,datapath.bus_PC_dest.ready_at),tmptime5) + mux_PC.get_delay();

    uint32_t next_pc = mux_PC.select(pc_plus_4, branch_target, take_branch);
    datapath.bus_PC_next = {next_pc,tmptime5};


    // --- Lógica de ActivePath ---
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
    if (!info) {
        pc += 4; // Tratar como NOP
        instructionString = disassemble(instruction, nullptr);
        strcpy(datapath.instruction_cptr, instructionString.c_str());
        datapath.total_micro_cycles = 1;
        return;
    }

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

    // --- MICRO-CICLO 1: ID (Instruction Decode & Register Fetch) ---
    // Se decodifica la instrucción y se leen los registros.
    datapath.bus_DA = { (uint8_t)rs1_addr, 1 };
    datapath.bus_DB = { (uint8_t)rs2_addr, 1 };
    datapath.bus_DC = { (uint8_t)rd_addr, 1 };
    datapath.bus_Opcode = { (uint8_t)(instruction & 0x3F), 1 };
    datapath.bus_funct3 = { (uint8_t)((instruction >> 12) & 0x07), 1 };
    datapath.bus_funct7 = { (uint8_t)((instruction >> 25) & 0x7F), 1 };
    datapath.bus_A = { rs1_val, 1 };
    datapath.bus_B = { rs2_val, 1 };
    datapath.bus_imm = { instruction, 1 };
    datapath.bus_immExt = { imm_ext, 1 };
    datapath.bus_Control = { controlWord(info), 1 };
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
    const uint32_t alu_op_b = mux_B.select(rs2_val, imm_ext, info->ALUsrc);
    const uint32_t alu_result = alu.calc(alu_op_a, alu_op_b, info->ALUctr);
    const bool alu_zero = (alu_result == 0);
    const uint32_t branch_target = pc + imm_ext;

    datapath.bus_ALU_A = { alu_op_a, 2 };
    datapath.bus_ALU_B = { alu_op_b, 2 };
    datapath.bus_ALU_result = { alu_result, 2 };
    datapath.bus_ALU_zero = { alu_zero, 2 };
    datapath.bus_PC_dest = { branch_target, 2 };

    // --- Lógica variable para los ciclos 3 y 4 ---
    uint32_t mem_read_data = 0x00FABADA;
    uint32_t final_result = 0x00FABADA;
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
        mem_read_data = d_mem.read_word(alu_result);
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
        d_mem.write_word(alu_result, rs2_val);
        next_pc = pc_plus_4;

    } else if (info->type == 'B') { // BEQ (3 ciclos)
        // Ciclo 2: EX/Branch completion
        bool take_branch = (alu_result == 0);
        datapath.bus_branch_taken = { take_branch, 2 };
        next_pc = take_branch ? branch_target : pc_plus_4;

    } else { // Jumps, etc. (Tratamiento genérico, se puede refinar)
        // Asumimos 4 ciclos por defecto para JAL, etc.
        final_result = mux_C.select(alu_result, mem_read_data, pc_plus_4, 0, info->ResSrc);
        datapath.bus_C = { final_result, 3 };
        datapath.bus_C.is_active = info->BRwr;
        if (info->BRwr == 1) register_file.write(rd_addr, final_result);
        bool take_branch = (info->PCsrc == 1 || (info->type == 'B' && alu_zero));
        datapath.bus_branch_taken = { take_branch, 2 };
        next_pc = take_branch ? branch_target : pc_plus_4;
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
    datapath.Pipe_IF_ID_Instr = { instruction, 0 };
    datapath.Pipe_IF_ID_NPC = { pc_plus_4, 0 };
    datapath.Pipe_IF_ID_PC = { pc, 0 };

    // ID/EX (listo en ciclo 2)    datapath.Pipe_ID_EX_Control = { controlWord(info), 2 };

    datapath.Pipe_ID_EX_Control = { controlWord(info), 1 };
    datapath.Pipe_ID_EX_NPC = { pc_plus_4, 1 };
    datapath.Pipe_ID_EX_A = { alu_op_a, 1 }; // alu_op_a es rs1_val (o 0 para LUI)
    datapath.Pipe_ID_EX_B = { rs2_val, 1 };
    datapath.Pipe_ID_EX_RD = { (uint8_t)rd_addr, 1 };
    datapath.Pipe_ID_EX_Imm = { imm_ext, 1 };
    datapath.Pipe_ID_EX_PC = { pc, 1 };

    // EX/MEM (listo en ciclo 3)
    bool esSW=info->instr == "sw";
    bool noesJ=info->type != 'J';
    datapath.Pipe_EX_MEM_Control = { controlWord(info), 2 };
    datapath.Pipe_EX_MEM_NPC = { pc_plus_4, 2,noesJ };
    datapath.Pipe_EX_MEM_ALU_result = { alu_result, 2 };
    datapath.Pipe_EX_MEM_B = { rs2_val, 2 ,esSW};
    datapath.Pipe_EX_MEM_RD = { (uint8_t)rd_addr, 2,!esSW}; // RD solo se usa en LW/R-Type, no en SW};

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
}

void Simulator::simulate_pipeline(uint32_t instruction) {
    // --- Simulación básica de las etapas IF y propagación de instructionString ---
    // 2. Decodificación mínima para obtener el mnemónico
    const InstructionInfo* info = control_unit.decode(instruction);
    std::string fetchedInstr = disassemble(instruction, info);

    // 3. Propagación de instructionString por las etapas del pipeline
    // En una implementación real, cada etapa tendría su propio registro y lógica
    // Aquí solo propagamos el string por las 5 etapas
    instructionString = fetchedInstr;
    strcpy(datapath.Pipe_WB_instruction_cptr, datapath.Pipe_MEM_instruction_cptr);    
    strcpy(datapath.Pipe_MEM_instruction_cptr, datapath.Pipe_EX_instruction_cptr);
    strcpy(datapath.Pipe_EX_instruction_cptr, datapath.Pipe_ID_instruction_cptr);
    strcpy(datapath.Pipe_ID_instruction_cptr, datapath.Pipe_IF_instruction_cptr);
    strcpy(datapath.Pipe_IF_instruction_cptr, instructionString.c_str());


    // Avanzar el PC (solo para la demo, normalmente el PC se actualiza en WB)
    pc += 4;
}
