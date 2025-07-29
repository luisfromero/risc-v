#include "Simulator.h"
#include <iostream> // Para depuración, se puede quitar después
#include <stdexcept>
#include <algorithm> // Para std::max
#include <sstream>


// (Puedes ponerlo como un método privado o función estática)
std::string Simulator::disassemble(uint32_t instruction, const InstructionInfo* info) const {
    if (!info) return "NOP";

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
        case 'S': // ej. sw rs2, imm(rs1)   (store word)
            oss << "x" << rs2 << ", " << ((instruction >> 7) & 0x1F | ((instruction >> 25) << 5)) // S-type imm
                << "(x" << rs1 << ")";
            break;
        case 'B': // ej. beq rs1, rs2, imm
            oss << "x" << rs1 << ", x" << rs2 << ", " << ((instruction >> 8) & 0xF)
                /* etc, calcula bien el inmediato tipo B */;
            break;
        case 'U': // ej. lui rd, imm
            oss << "x" << rd << ", " << (instruction & 0xFFFFF000);
            break;
        case 'J': // ej. jal rd, imm
            oss << "x" << rd << ", " << /*calcula_j_imm(instruction)*/0;
            break;
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
      i_cache(256, 16, memory),
      d_cache(256, 16, memory),
      i_mem(256), // Memoria de instrucciones para modo didáctico
      d_mem(256),  // Memoria de datos para modo didáctico
      datapath{}
{
    // El PC se inicializa en 0.
      // NOTA: La ruta al fichero de instrucciones debería ser configurable, no "hard-coded".
      // Por ejemplo, podría pasarse al constructor o leerse de una variable de entorno.
      control_unit.load_control_table("d:/onedrive/proyectos/riscv/resources/instructions.json");
      // Abrir el fichero de log. Se sobreescribirá en cada nueva ejecución.
      m_logfile.open("simulator.log", std::ios::out | std::ios::trunc);
      m_logfile << "--- Log del Simulador RISC-V ---" << std::endl;
      
}

// Carga un programa en la memoria del simulador.
void Simulator::load_program(const std::vector<uint8_t>& program) {
    // La carga depende del modo de pipeline.
    if (model == PipelineModel::General) {
        memory.load_program(program, 0);
    } else {
        // En modo didáctico, el programa se carga en la memoria de instrucciones.
        // La memoria de datos permanece vacía inicialmente.
        i_mem.load_program(program, 0);
    }
}

// Ejecuta un ciclo completo: fetch, decode, execute.
void Simulator::step() {
    uint32_t instruction = fetch();
    if (m_logfile.is_open()) {
        m_logfile << "\n--- Ciclo " << current_cycle << " ---" << std::endl;
        m_logfile << "PC: 0x" << std::hex << pc << std::dec << std::endl;
        m_logfile << "Instrucción leída: 0x" << std::hex << instruction << std::dec << std::endl;

    }
    current_cycle++; // Avanzamos el ciclo de instruccion//reloj
    decode_and_execute(instruction);
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

// Fase de Fetch: Lee la siguiente instrucción de la memoria.
uint32_t Simulator::fetch() {
    // Lee una palabra de 32 bits (4 bytes) desde la caché de instrucciones.
    if (model == PipelineModel::General) {
        return i_cache.read_word(pc);
    } else {
        // En modo didáctico, lee directamente de la memoria de instrucciones.
        return i_mem.read_word(pc);
    }
    
}


/*
// --- Implementación de las funciones de ejecución de instrucciones ---

void Simulator::execute_lw(uint32_t instruction) {
    uint32_t rd = (instruction >> 7) & 0x1F;
    uint32_t rs1 = (instruction >> 15) & 0x1F;
    int32_t imm = static_cast<int32_t>(instruction) >> 20;
    uint32_t address = register_file.readA(rs1) + imm;
    uint32_t data = (model == PipelineModel::General)
                        ? d_cache.read_word(address)
                        : d_mem.read_word(address);
    register_file.write(rd, data);
    pc += 4;
}

void Simulator::execute_sw(uint32_t instruction) {
    uint32_t rs1 = (instruction >> 15) & 0x1F;
    uint32_t rs2 = (instruction >> 20) & 0x1F;
    int32_t imm = ((static_cast<int32_t>(instruction) >> 25) << 5) | ((instruction >> 7) & 0x1F);
    uint32_t address = register_file.readA(rs1) + imm;
    uint32_t data = register_file.readB(rs2);
    if (model == PipelineModel::General) {
        d_cache.write_word(address, data);
    } else {
        d_mem.write_word(address, data);
    }
    pc += 4;

}


void Simulator::execute_addi(uint32_t instruction) {
    uint32_t cycle = current_cycle; // Asume que tienes este contador en el simulador
    if(this->model==PipelineModel::SingleCycle)cycle=0;
    if(this->model==PipelineModel::MultiCycle)cycle=0;  //ToDo
    if(this->model==PipelineModel::PipeLined)cycle=0;  //ToDo
    
    // --- Extraer campos de la instrucción ---
    uint32_t rd  = (instruction >> 7) & 0x1F;
    uint32_t rs1 = (instruction >> 15) & 0x1F;
    int32_t imm  = static_cast<int32_t>(instruction) >> 20;

    // Guardar campos en el datapath con disponibilidad inmediata (este ciclo)
    this->datapath.bus_Instr          = {instruction, cycle};
    this->datapath.bus_DC             = {static_cast<uint8_t>(rd),  cycle};
    this->datapath.bus_DA             = {static_cast<uint8_t>(rs1), cycle};
    this->datapath.bus_imm            = {static_cast<uint32_t>(imm), cycle};
    this->datapath.bus_immExt         = {static_cast<uint32_t>(imm), cycle}; // Para uniformidad, aunque ya está extendido

    // Leer valor de rs1
    uint32_t rs1_val = register_file.readA(rs1);
    this->datapath.bus_A             = {rs1_val, cycle + 1}; // Retardo de lectura del registro: 1 ciclo

    // ALU: suma rs1 + imm
    this->datapath.bus_ALU_A         = {rs1_val, cycle + 1};
    this->datapath.bus_ALU_B         = {static_cast<uint32_t>(imm), cycle + 1};
    uint32_t result            = rs1_val + imm;
    this->datapath.bus_ALU_result    = {result, cycle + 2};
    this->datapath.bus_ALU_zero      = {result == 0, cycle + 2};

    // Control: señal ficticia, asumimos una palabra codificada como 0x001 para ADDI
    this->datapath.bus_Control       = {0x0001, cycle};

    // Write-back al registro destino (retardo: 3er ciclo)
    this->datapath.bus_C             = {result, cycle + 3};
    register_file.write(rd, result); // Puedes sincronizar esta escritura con ready_at si lo deseas

    // PC + 4
    this->datapath.bus_PC            = {pc, cycle};
    this->datapath.bus_PC_plus4      = {pc + 4, cycle + 1};
    this->datapath.bus_PC_next       = {pc + 4, cycle + 1};

    pc += 4;
}


void Simulator::execute_add(uint32_t instruction) {
    uint32_t rd = (instruction >> 7) & 0x1F;
    uint32_t rs1 = (instruction >> 15) & 0x1F;
    uint32_t rs2 = (instruction >> 20) & 0x1F;
    uint32_t rs1_val = register_file.readA(rs1);
    uint32_t rs2_val = register_file.readB(rs2);
    register_file.write(rd, rs1_val + rs2_val);
    pc += 4;
}

void Simulator::execute_unrecognized(uint32_t instruction) {
    // Instrucción no reconocida o no implementada
    std::cerr << "Instrucción no reconocida: 0x" << std::hex << instruction << std::endl;
    // Por ahora, solo avanzamos el PC para no entrar en un bucle infinito.
    // En un futuro, esto podría lanzar una excepción de instrucción ilegal.
    pc += 4;
}



// --- Tabla de decodificación ---

// Definición de la tabla estática. Al ser un miembro estático de Simulator,
// tiene acceso a los punteros a funciones miembro privadas.
const std::vector<Simulator::InstructionFormat> Simulator::instruction_table = {
    // R-Type
    {0xFE00707F, 0x00000033, &Simulator::execute_add},  // ADD (funct7=0x00, funct3=0x0, opcode=0x33)
    // I-Type
    {0x707F,     0x00000013, &Simulator::execute_addi}, // ADDI (funct3=0x0, opcode=0x13)
    {0x707F,     0x00002003, &Simulator::execute_lw},   // LW (funct3=0x2, opcode=0x03)
    // S-Type
    {0x707F,     0x00002023, &Simulator::execute_sw},   // SW (funct3=0x2, opcode=0x23)
};

// Fase de Decode y Execute: Interpreta y ejecuta la instrucción.
void Simulator::decode_and_execute(uint32_t instruction) {
    for (const auto& fmt : instruction_table) {
        if ((instruction & fmt.mask) == fmt.match) {
            (this->*fmt.execute)(instruction); // Llama a la función miembro correspondiente
            return; // Instrucción encontrada y ejecutada
        }
    }

    // Si el bucle termina, ninguna instrucción coincidió.
    execute_unrecognized(instruction);
}
    */

uint16_t controlWord(const InstructionInfo* info) {
    return (info->ALUctr  & 0x7) << 13 |  // 3 bits
           (info->ResSrc & 0x3) << 11 |  // 2 bits
           (info->ImmSrc & 0x3) << 9  |  // 2 bits
           (info->PCsrc  & 0x1) << 8  |  // 1 bit
           (info->BRwr   & 0x1) << 7  |  // 1 bit
           (info->ALUsrc & 0x1) << 6  |  // 1 bit
           (info->MemWr  & 0x1) << 5;    // 1 bit
}


void Simulator::decode_and_execute(uint32_t instruction)
{
    // --- INICIO DEL CICLO (t=0) ---
    // La única señal estable al inicio del ciclo es el PC.
    datapath.bus_PC = { pc, 0 };
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

    

    // 1. DECODIFICACIÓN Y LECTURA DE REGISTROS
    const InstructionInfo* info = control_unit.decode(instruction);
    datapath.bus_Control = {controlWord(info),tmptime+control_unit.get_delay()};

    if (!info) {
        std::cerr << "Instrucción no reconocida: 0x" << std::hex << instruction << std::endl;
        return;
    }

    

    // 2. Lectura de registros y EXTENSIÓN DE SIGNO
    uint32_t rs1_val = register_file.readA(rs1_addr);
    uint32_t rs2_val = register_file.readB(rs2_addr);
    tmptime=datapath.bus_Instr.ready_at + register_file.get_delay();
    datapath.bus_A = {rs1_val,tmptime};
    datapath.bus_ALU_A = {rs1_val,tmptime};
    datapath.bus_B = {rs2_val,tmptime};
    uint32_t imm_ext = sign_extender.extender(instruction, info->ImmSrc);
    uint32_t tmptime2=datapath.bus_Control.ready_at + sign_extender.get_delay();
    datapath.bus_immExt = {imm_ext,tmptime2};
    datapath.bus_Mem_write_data=datapath.bus_B;
    

    //

        // 3. EJECUCIÓN (ALU)
    // Mux para la entrada B de la ALU
    uint32_t alu_op_b =mux_B.select(rs2_val,imm_ext,info->ALUsrc)   ;
    uint32_t tmptime3=std::max(std::max(datapath.bus_B.ready_at,datapath.bus_immExt.ready_at),datapath.bus_Control.ready_at) + mux_B.get_delay();
    datapath.bus_ALU_B = {alu_op_b,tmptime3};

    
    uint32_t alu_result = alu.calc(rs1_val, alu_op_b, info->ALUctr);
    bool alu_zero = (alu_result == 0);
    uint32_t tmptime4=std::max(std::max(datapath.bus_ALU_A.ready_at,datapath.bus_ALU_B.ready_at),datapath.bus_Control.ready_at) + alu.get_delay();
    datapath.bus_ALU_result    = {alu_result,tmptime4};
    datapath.bus_ALU_zero      = {alu_zero,tmptime4};
    datapath.bus_Mem_address    = datapath.bus_ALU_result;



    
    uint32_t branch_target = adder.add(pc, imm_ext);
    datapath.bus_PC_dest       = {branch_target, datapath.bus_immExt.ready_at+ adder.get_delay()};




    // 4. ACCESO A MEMORIA
    uint32_t mem_read_data = 0;
    if (info->MemWr == 1) { // SW
        d_mem.write_word(alu_result, rs2_val);
        datapath.bus_Mem_read_data = {INDETERMINADO, tmptime4};//tmptime4 es la salida de la alu con dirección efectiva

    }
    if (info->ResSrc == 1) { // LW
        mem_read_data = d_mem.read_word(alu_result);
        datapath.bus_Mem_read_data = {mem_read_data, std::max(tmptime4,datapath.bus_Control.ready_at) + d_mem.get_delay()};;//tmptime4 es la salida de la alu con dirección efectiva
    }

    // 5. ESCRITURA (WRITE-BACK)
    // Mux para el resultado final
    uint32_t  final_result=mux_C.select(alu_result,mem_read_data,pc_plus_4,INDETERMINADO,info->ResSrc);
    uint32_t critical=std::max(std::max(std::max(datapath.bus_ALU_result.ready_at,datapath.bus_Mem_read_data.ready_at),datapath.bus_Control.ready_at),datapath.bus_PC_plus4.ready_at)+mux_C.get_delay();
    datapath.bus_C = {final_result,critical};
    critical=critical+register_file.get_write_delay();


    if (info->BRwr == 1) {
        register_file.write(rd_addr, final_result);
    }


 
    // Mux para el PC
    bool take_branch = (info->PCsrc == 1|| (info->type=='B' && alu_zero));

    uint32_t tmptime5 = std::max(datapath.bus_ALU_zero.ready_at,datapath.bus_Control.ready_at); //Tiempo en llegar la sñal que controla el mux
    
    datapath.bus_branch_taken = {take_branch,tmptime5};
    tmptime5 = std::max(std::max(datapath.bus_PC_plus4.ready_at,datapath.bus_PC_dest.ready_at),tmptime5) + control_unit.get_delay();
    uint32_t next_pc = mux_PC.select(pc_plus_4, branch_target, take_branch);
    datapath.bus_PC_next = {next_pc,tmptime5};



    pc = next_pc;
    instructionString=disassemble(instruction, info);
    current_cycle++;


}
