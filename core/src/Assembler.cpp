#include "Assembler.h"

// --- Funciones de ayuda para manipulación de strings ---
namespace {
    // Elimina espacios en blanco al principio y al final de un string.
    void trim(std::string &s) {
        s.erase(s.begin(), std::find_if(s.begin(), s.end(), [](unsigned char ch) {
            return !std::isspace(ch);
        }));
        s.erase(std::find_if(s.rbegin(), s.rend(), [](unsigned char ch) {
            return !std::isspace(ch);
        }).base(), s.end());
    }

    // Convierte un string a minúsculas.
    void to_lower(std::string &s) {
        std::transform(s.begin(), s.end(), s.begin(),
                       [](unsigned char c){ return std::tolower(c); });
    }
}

RISCVAssembler::RISCVAssembler() {
    // Inicializa el mapa de registros (ABI a nombres de arquitectura)
    reg_map = {
        {"zero", "x0"}, {"x0", "x0"}, {"ra", "x1"}, {"x1", "x1"}, {"sp", "x2"}, {"x2", "x2"},
        {"gp", "x3"}, {"x3", "x3"}, {"tp", "x4"}, {"x4", "x4"}, {"t0", "x5"}, {"x5", "x5"},
        {"t1", "x6"}, {"x6", "x6"}, {"t2", "x7"}, {"x7", "x7"}, {"s0", "x8"}, {"fp", "x8"},
        {"x8", "x8"}, {"s1", "x9"}, {"x9", "x9"}, {"a0", "x10"}, {"x10", "x10"}, {"a1", "x11"},
        {"x11", "x11"}, {"a2", "x12"}, {"x12", "x12"}, {"a3", "x13"}, {"x13", "x13"},
        {"a4", "x14"}, {"x14", "x14"}, {"a5", "x15"}, {"x15", "x15"}, {"a6", "x16"},
        {"x16", "x16"}, {"a7", "x17"}, {"x17", "x17"}, {"s2", "x18"}, {"x18", "x18"},
        {"s3", "x19"}, {"x19", "x19"}, {"s4", "x20"}, {"x20", "x20"}, {"s5", "x21"},
        {"x21", "x21"}, {"s6", "x22"}, {"x22", "x22"}, {"s7", "x23"}, {"x23", "x23"},
        {"s8", "x24"}, {"x24", "x24"}, {"s9", "x25"}, {"x25", "x25"}, {"s10", "x26"},
        {"x26", "x26"}, {"s11", "x27"}, {"x27", "x27"}, {"t3", "x28"}, {"x28", "x28"},
        {"t4", "x29"}, {"x29", "x29"}, {"t5", "x30"}, {"x30", "x30"}, {"t6", "x31"},
        {"x31", "x31"}
    };

    // Inicializa la base de datos de instrucciones
    // NOTA: Sería ideal cargar esto desde el mismo JSON que usa ControlUnit para mantener la consistencia.
    instruction_db = {
{"add","R","0110011","000","0000000"},
{"sub","R","0110011","000","0100000"},
{"sll","R","0110011","001","0000000"},
{"slt","R","0110011","010","0000000"},
{"sltu","R","0110011","011","0000000"},
{"xor","R","0110011","100","0000000"},
{"srl","R","0110011","101","0000000"},
{"sra","R","0110011","101","0100000"},
{"or","R","0110011","110","0000000"},
{"and","R","0110011","111","0000000"},
{"addw","R","0111011","000","0000000"},
{"subw","R","0111011","000","0100000"},
{"sllw","R","0111011","001","0000000"},
{"slrw","R","0111011","101","0000000"},
{"sraw","R","0111011","101","0100000"},
{"addi","I","0010011","000",""},
{"lb","I","0000011","000",""},
{"lh","I","0000011","001",""},
{"lw","I","0000011","010",""},
{"ld","I","0000011","011",""},
{"lbu","I","0000011","100",""},
{"lhu","I","0000011","101",""},
{"lwu","I","0000011","110",""},
{"fence","I","0001111","000",""},
{"fence.i","I","0001111","001",""},
{"slli","I","0010011","001","0000000"},
{"slti","I","0010011","010",""},
{"sltiu","I","0010011","011",""},
{"xori","I","0010011","100",""},
{"slri","I","0010011","101","0000000"},
{"srai","I","0010011","101","0100000"},
{"ori","I","0010011","110",""},
{"andi","I","0010011","111",""},
{"addiw","I","0011011","000",""},
{"slliw","I","0011011","001","0000000"},
{"srliw","I","0011011","101","0000000"},
{"sraiw","I","0011011","101","0100000"},
{"jalr","I","1100111","000",""},
{"ecall","I","1110011","000","000000000000"},
{"ebreak","I","1110011","000","000000000001"},
{"csrrw","I","1110011","001",""},
{"csrrs","I","1110011","010",""},
{"csrrc","I","1110011","011",""},
{"csrrwi","I","1110011","101",""},
{"csrrsi","I","1110011","110",""},
{"csrrci","I","1110011","111",""},
{"sw","S","0100011","010",""},
{"sb","S","0100011","000",""},
{"sh","S","0100011","001",""},
{"sd","S","0100011","011",""},
{"beq","SB","1100011","000",""},
{"bne","SB","1100011","001",""},
{"blt","SB","1100011","100",""},
{"bge","SB","1100011","101",""},
{"bltu","SB","1100011","110",""},
{"bgeu","SB","1100011","111",""},
{"auipc","U","0010111","",""},
{"lui","U","0110111","",""},
{"jal","UJ","1101111","",""},
{"mul","R","0110011","000","0000001"},
{"mulh","R","0110011","001","0000001"},
{"mulsu","R","0110011","010","0000001"},
{"mulu","R","0110011","011","0000001"},
{"div","R","0110011","100","0000001"},
{"divu","R","0110011","101","0000001"},
{"rem","R","0110011","110","0000001"},
{"remu","R","0110011","111","0000001"}
};
}

std::vector<uint8_t> RISCVAssembler::assemble_program(const std::string& source_code) {
    // Fase 1: Limpieza y separación de etiquetas
    std::vector<std::string> clean_lines = preprocess(source_code);

    // Fase 2: Primera pasada para construir la tabla de símbolos
    std::vector<std::string> instructions_only = first_pass(clean_lines);

    // Fase 3: Segunda pasada para reemplazar etiquetas por offsets
    std::vector<std::string> final_code = second_pass(instructions_only);

    // Fase 4: Tercera pasada para ensamblar a código máquina
    std::vector<uint32_t> machine_words = third_pass(final_code);

    // Convertir palabras de 32 bits a un vector de bytes (little-endian)
    std::vector<uint8_t> machine_code_bytes;
    machine_code_bytes.reserve(machine_words.size() * 4);
    for (uint32_t word : machine_words) {
        machine_code_bytes.push_back(static_cast<uint8_t>((word >> 0) & 0xFF));
        machine_code_bytes.push_back(static_cast<uint8_t>((word >> 8) & 0xFF));
        machine_code_bytes.push_back(static_cast<uint8_t>((word >> 16) & 0xFF));
        machine_code_bytes.push_back(static_cast<uint8_t>((word >> 24) & 0xFF));
    }

    return machine_code_bytes;
}

const std::map<std::string, uint32_t>& RISCVAssembler::get_symbol_table() const {
    return symbol_table;
}

std::vector<std::string> RISCVAssembler::preprocess(const std::string& source_code) {
    std::vector<std::string> processed_lines;
    std::stringstream ss(source_code);
    std::string line;

    while (std::getline(ss, line)) {
        // 1. Eliminar comentarios
        size_t comment_pos = line.find('#');
        if (comment_pos != std::string::npos) {
            line = line.substr(0, comment_pos);
        }

        // 2. Convertir a minúsculas y limpiar
        to_lower(line);
        trim(line);

        if (line.empty()) {
            continue;
        }

        // 3. Reemplazar comas y paréntesis por espacios para facilitar el split
        std::replace(line.begin(), line.end(), ',', ' ');
        std::replace(line.begin(), line.end(), '(', ' ');
        std::replace(line.begin(), line.end(), ')', ' ');

        // 4. Normalizar espacios múltiples a uno solo
        std::string normalized_line;
        std::unique_copy(line.begin(), line.end(), std::back_inserter(normalized_line),
                         [](char a, char b) { return std::isspace(a) && std::isspace(b); });
        trim(normalized_line);

        // 5. Separar etiquetas de instrucciones
        size_t colon_pos = normalized_line.find(':');
        if (colon_pos != std::string::npos) {
            std::string label = normalized_line.substr(0, colon_pos + 1);
            std::string instruction = normalized_line.substr(colon_pos + 1);
            trim(label);
            trim(instruction);
            processed_lines.push_back(label);
            if (!instruction.empty()) {
                processed_lines.push_back(instruction);
            }
        } else {
            processed_lines.push_back(normalized_line);
        }
    }
    return processed_lines;
}

std::vector<std::string> RISCVAssembler::first_pass(const std::vector<std::string>& clean_lines) {
    symbol_table.clear();
    std::vector<std::string> instructions_only;
    uint32_t current_address = 0;

    for (const auto& line : clean_lines) {
        if (line.back() == ':') {
            std::string label = line.substr(0, line.length() - 1);
            if (symbol_table.count(label)) {
                throw std::runtime_error("Error: Etiqueta duplicada '" + label + "'");
            }
            symbol_table[label] = current_address;
        } else {
            instructions_only.push_back(line);
            current_address += 4;
        }
    }
    return instructions_only;
}

std::vector<std::string> RISCVAssembler::second_pass(const std::vector<std::string>& instructions) {
    std::vector<std::string> final_code;
    uint32_t current_pc = 0;

    for (const auto& instr : instructions) {
        std::stringstream ss(instr);
        std::string mnemonic, op1, op2, op3;
        ss >> mnemonic >> op1 >> op2 >> op3;

        // Solo las instrucciones de salto (B y J) usan etiquetas como último operando.
        const InstructionData& instr_data = getInstructionData(mnemonic);
        if (instr_data.type == "SB" || instr_data.type == "UJ") {
            std::string& label_operand = (instr_data.type == "SB") ? op3 : op2;
            if (symbol_table.count(label_operand)) {
                uint32_t target_address = symbol_table.at(label_operand);
                int32_t offset = static_cast<int32_t>(target_address) - static_cast<int32_t>(current_pc);
                label_operand = std::to_string(offset);
            }
        }
        
        // Reconstruir la instrucción
        std::string new_line = mnemonic;
        if (!op1.empty()) new_line += " " + op1;
        if (!op2.empty()) new_line += " " + op2;
        if (!op3.empty()) new_line += " " + op3;

        final_code.push_back(new_line);
        current_pc += 4;
    }
    return final_code;
}

std::vector<uint32_t> RISCVAssembler::third_pass(const std::vector<std::string>& final_code) {
    std::vector<uint32_t> machine_words;
    for (const auto& line : final_code) {
        machine_words.push_back(assemble_line(line));
    }
    return machine_words;
}

const InstructionData& RISCVAssembler::getInstructionData(const std::string& mnemonic) {
    for (const auto& data : instruction_db) {
        if (data.mnemonic == mnemonic) {
            return data;
        }
    }
    throw std::runtime_error("Instruccion desconocida: " + mnemonic);
}

int RISCVAssembler::get_register_num(const std::string& reg) {
    // Eliminar comas si las hubiera
    std::string clean_reg = reg;
    clean_reg.erase(std::remove(clean_reg.begin(), clean_reg.end(), ','), clean_reg.end());

    if (reg_map.count(clean_reg)) {
        const std::string& arch_reg = reg_map.at(clean_reg);
        return std::stoi(arch_reg.substr(1)); // Elimina la 'x' inicial
    }
    throw std::runtime_error("Registro invalido: " + reg);
}

uint32_t RISCVAssembler::ensamblarR(const std::vector<std::string>& partes, const InstructionData& instr_data) {
    int rd = get_register_num(partes[1]);
    int rs1 = get_register_num(partes[2]);
    int rs2 = get_register_num(partes[3]);
    uint32_t opcode = std::stoul(instr_data.opcode, nullptr, 2);
    uint32_t funct3 = instr_data.funct3.empty() ? 0 : std::stoul(instr_data.funct3, nullptr, 2);
    uint32_t funct7 = instr_data.funct7.empty() ? 0 : std::stoul(instr_data.funct7, nullptr, 2);
    return (funct7 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode;
}

uint32_t RISCVAssembler::ensamblarI(const std::vector<std::string>& partes, const InstructionData& instr_data) {
    int rd, rs1, imm;
    rd = get_register_num(partes[1]);

    // Caso especial para desplazamientos: slli, srli, srai, slliw, srliw, sraiw
    if (instr_data.mnemonic == "slli" || instr_data.mnemonic == "srli" || instr_data.mnemonic == "srai") {
        rs1 = get_register_num(partes[2]);
        int shamt = std::stoi(partes[3]); // Shift amount
        uint32_t opcode = std::stoul(instr_data.opcode, nullptr, 2);
        uint32_t funct3 = std::stoul(instr_data.funct3, nullptr, 2);
        uint32_t funct7 = std::stoul(instr_data.funct7, nullptr, 2);
        // El inmediato se construye con funct7 y shamt
        uint32_t imm_field = (funct7 << 5) | (shamt & 0x1F);
        return (imm_field << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode;
    }
    if (instr_data.mnemonic == "slliw" || instr_data.mnemonic == "srliw" || instr_data.mnemonic == "sraiw") {
        rs1 = get_register_num(partes[2]);
        int shamt = std::stoi(partes[3]); // Shift amount
        uint32_t opcode = std::stoul(instr_data.opcode, nullptr, 2);
        uint32_t funct3 = std::stoul(instr_data.funct3, nullptr, 2);
        uint32_t funct7 = std::stoul(instr_data.funct7, nullptr, 2);
        return (funct7 << 25) | ((shamt & 0x1F) << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode;
    }

    if (partes.size() == 4) { // Formato: addi rd, rs1, imm
        rs1 = get_register_num(partes[2]);
        imm = std::stoi(partes[3]);
    } else if (partes.size() == 3) { // Formato: lw rd, offset(rs1)
        size_t open_paren = partes[2].find('(');
        size_t close_paren = partes[2].find(')');
        if (open_paren == std::string::npos || close_paren == std::string::npos) {
            throw std::runtime_error("Formato I invalido para carga/salto: " + partes[2]);
        }
        imm = std::stoi(partes[2].substr(0, open_paren));
        rs1 = get_register_num(partes[2].substr(open_paren + 1, close_paren - (open_paren + 1)));
    } else {
        throw std::runtime_error("Numero de operandos incorrecto para formato I.");
    }
    uint32_t opcode = std::stoul(instr_data.opcode, nullptr, 2);
    uint32_t funct3 = instr_data.funct3.empty() ? 0 : std::stoul(instr_data.funct3, nullptr, 2);
    return ((imm & 0xFFF) << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode;
}

uint32_t RISCVAssembler::ensamblarS(const std::vector<std::string>& partes, const InstructionData& instr_data) {
    int rs2 = get_register_num(partes[1]);
    size_t open_paren = partes[2].find('(');
    size_t close_paren = partes[2].find(')');
    if (open_paren == std::string::npos || close_paren == std::string::npos) {
        throw std::runtime_error("Formato S invalido para almacenamiento: " + partes[2]);
    }
    int imm = std::stoi(partes[2].substr(0, open_paren));
    int rs1 = get_register_num(partes[2].substr(open_paren + 1, close_paren - (open_paren + 1)));
    uint32_t opcode = std::stoul(instr_data.opcode, nullptr, 2);
    uint32_t funct3 = instr_data.funct3.empty() ? 0 : std::stoul(instr_data.funct3, nullptr, 2);
    return (((imm >> 5) & 0x7F) << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | ((imm & 0x1F) << 7) | opcode;
}

uint32_t RISCVAssembler::ensamblarSB(const std::vector<std::string>& partes, const InstructionData& instr_data) {
    int rs1 = get_register_num(partes[1]);
    int rs2 = get_register_num(partes[2]);
    int imm = std::stoi(partes[3]);
    uint32_t opcode = std::stoul(instr_data.opcode, nullptr, 2);
    uint32_t funct3 = instr_data.funct3.empty() ? 0 : std::stoul(instr_data.funct3, nullptr, 2);

    uint32_t imm_12   = (imm >> 12) & 1;
    uint32_t imm_10_5 = (imm >> 5)  & 0x3F;
    uint32_t imm_4_1  = (imm >> 1)  & 0xF;
    uint32_t imm_11   = (imm >> 11) & 1;

    return (imm_12 << 31) | (imm_10_5 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (imm_4_1 << 8) | (imm_11 << 7) | opcode;
}

uint32_t RISCVAssembler::ensamblarUJ(const std::vector<std::string>& partes, const InstructionData& instr_data) {
    int rd = get_register_num(partes[1]);
    int imm = std::stoi(partes[2]);
    uint32_t opcode = std::stoul(instr_data.opcode, nullptr, 2);

    uint32_t imm_20    = (imm >> 20) & 1;
    uint32_t imm_10_1  = (imm >> 1)  & 0x3FF;
    uint32_t imm_11    = (imm >> 11) & 1;
    uint32_t imm_19_12 = (imm >> 12) & 0xFF;

    return (imm_20 << 31) | (imm_10_1 << 21) | (imm_11 << 20) | (imm_19_12 << 12) | (rd << 7) | opcode;
}

uint32_t RISCVAssembler::ensamblarU(const std::vector<std::string>& partes, const InstructionData& instr_data) {
    int rd = get_register_num(partes[1]);
    uint32_t imm = std::stoul(partes[2]);
    uint32_t opcode = std::stoul(instr_data.opcode, nullptr, 2);
    return (imm << 12) | (rd << 7) | opcode;
}

uint32_t RISCVAssembler::assemble_line(const std::string& instruction_str) {
    std::stringstream ss(instruction_str);
    std::string token;
    std::vector<std::string> partes;
    while (ss >> token) {
        partes.push_back(token);
    }

    if (partes.empty()) {
        return 0; // Línea vacía, se podría ignorar.
    }

    std::string mnemonic = partes[0];
    // Manejar pseudo-instrucción 'nop'
    if (mnemonic == "nop") {
        return 0x00000013; // Equivale a addi x0, x0, 0
    }

    const InstructionData& instr_data = getInstructionData(mnemonic);

    if (instr_data.type == "R") {
        return ensamblarR(partes, instr_data);
    } else if (instr_data.type == "I") {
        return ensamblarI(partes, instr_data);
    } else if (instr_data.type == "S") {
        return ensamblarS(partes, instr_data);
    } else if (instr_data.type == "SB") {
        return ensamblarSB(partes, instr_data);
    } else if (instr_data.type == "UJ") {
        return ensamblarUJ(partes, instr_data);
    } else if (instr_data.type == "U") {
        return ensamblarU(partes, instr_data);
    } else {
        throw std::runtime_error("Tipo de instruccion no soportado: " + instr_data.type);
    }
}
