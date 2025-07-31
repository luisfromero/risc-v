
#include "ControlUnit.h"
#include <fstream>
#include <stdexcept>

#include <cstdint>
#include "nlohmann/json.hpp"

using json = nlohmann::json;

ControlUnit::ControlUnit() {

/**
 * Tabla de control para las instrucciones de risc-v-r
 */
static const InstructionInfo control_table_original[] = {
    // instr   PCsrc BRwr ALUsrc ALUctr MemWr ResSrc ImmSrc   mask        value
    {"add",    0,    1,    0,    0b000, 0,     0,     0, 0xFE00707F, 0x00000033,'R' }, // R-type
    {"sub",    0,    1,    0,    0b001, 0,     0,     0, 0xFE00707F, 0x40000033,'R' }, // R-type
    {"and",    0,    1,    0,    0b010, 0,     0,     0, 0xFE00707F, 0x00007033,'R' }, // R-type
    {"or",     0,    1,    0,    0b011, 0,     0,     0, 0xFE00707F, 0x00006033,'R' }, // R-type
    {"addi",   0,    1,    1,    0b000, 0,     0,     0, 0x707F,     0x00000013,'I' }, // I-type
    {"lw",     0,    1,    1,    0b000, 0,     1,     0, 0x707F,     0x00002003,'I' }, // I-type (funct3=0x2 si usas lw, ajústalo)
    {"sw",     0,    0,    1,    0b000, 1,     0,     1, 0x707F,     0x00002023,'S' }, // S-type
    {"beq",    1,    0,    0,    0b001, 0,     0,     2, 0x707F,     0x00000063,'B' }, // B-type (funct3=0)
    {"jal",    1,    1,    0,    0b000, 0,     2,     3, 0x7F,       0x0000006F,'J' }, // J-type
    {"sll",    0,    1,    0,    0b110, 0,     0,     0, 0xFE00707F, 0x00001033,'R' }, // R-type shift left logical
};

    control_table.assign(std::begin(control_table_original), std::end(control_table_original));


}

std::vector<InstructionInfo> ControlUnit::get_control_table()
{
    return control_table;
}


uint32_t ControlUnit::decode(uint32_t instruction, uint8_t funct)
{
    return 0;
}
uint32_t ControlUnit::decode(uint32_t instruction, bool Z)
{
    return 0;
}


void ControlUnit::load_control_table(const std::string& json_path) {
    std::ifstream f(json_path);
    if (!f.is_open()) {
        throw std::runtime_error("ControlUnit Error: No se pudo abrir el fichero de instrucciones: " + json_path);
    }

    json data = json::parse(f);

    control_table.clear();
    for (const auto& item : data) {
        InstructionInfo info;
        info.instr = item.at("instr").get<std::string>();
        info.PCsrc = item.at("PCsrc").get<uint8_t>();
        info.BRwr = item.at("BRwr").get<uint8_t>();
        info.ALUsrc = item.at("ALUsrc").get<uint8_t>();
        info.ALUctr = item.at("ALUctr").get<uint8_t>();
        info.MemWr = item.at("MemWr").get<uint8_t>();
        info.ResSrc = item.at("ResSrc").get<uint8_t>();
        info.ImmSrc = item.at("ImmSrc").get<uint8_t>();
        info.mask = item.at("mask").get<uint32_t>();
        info.value = item.at("value").get<uint32_t>();
        info.type = item.at("type").get<std::string>()[0]; // Coge el primer char del string
        
        control_table.push_back(info);
    }
}
const InstructionInfo* ControlUnit::decode(uint32_t instruction) {
    for (const auto& info : control_table) {
        if ((instruction & info.mask) == info.value) {
            return &info;
        }
    }
    return nullptr; // Instrucción no reconocida
}
