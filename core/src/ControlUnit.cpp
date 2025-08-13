
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
    {"add",    0,    1,    1,    0b000, 0,     1,    -1, 0xFE00707F, 0x00000033, 'R',4 }, // R-type
    {"sub",    0,    1,    1,    0b001, 0,     1,    -1, 0xFE00707F, 0x40000033, 'R',4 }, // R-type
    {"and",    0,    1,    1,    0b010, 0,     1,    -1, 0xFE00707F, 0x00007033, 'R',4 }, // R-type
    {"or",     0,    1,    1,    0b011, 0,     1,    -1, 0xFE00707F, 0x00006033, 'R',4}, // R-type
    {"addi",   0,    1,    0,    0b000, 0,     1,     0, 0x707F,     0x00000013, 'I',4 }, // I-type
    {"lw",     0,    1,    0,    0b000, 0,     0,     0, 0x707F,     0x00002003, 'I',5 }, // I-type (funct3=0x2 si usas lw, ajústalo)
    {"sw",     0,    0,    0,    0b000, 1,    -1,     1, 0x707F,     0x00002023, 'S',4 }, // S-type
    {"beq",    1,    0,    1,    0b001, 0,    -1,     2, 0x707F,     0x00000063, 'B',3 }, // B-type (funct3=0)
    {"jal",    1,    1,   -1,       -1, 0,     2,     3, 0x7F,       0x0000006F, 'J',4 }, // J-type
    {"sll",    0,    1,    1,    0b110, 0,     1,    -1, 0xFE00707F, 0x00001033, 'R',4 }, // R-type shift left logical
    {"ori",    0,    1,    0,    0b011, 0,     1,     0, 0x707F,     0x00006013, 'I',4}, // <<< NUEVA
    {"lui",    0,    1,    0,    0b000, 0,     1,     4, 0x7F,       0x00000037, 'U',4}, // <<< NUEVA
    // {"j",   'J'}, // j es una pseudo-instrucción de 'jal x0, imm'. Usa la misma línea que jal.

};

/*
aluctr ressrc inmsrc pcsrc x ALUsrc brwr  memwr x x

000 01 xxx 00 x 0 1 0 //add
001 01 xxx 00 x 0 1 0 //sub
010 01 xxx 00 x 0 1 0 //and
011 01 xxx 00 x 0 1 0 //or
000 01 000 00 x 1 1 0 //addi
000 10 000 00 x 1 1 0 //lw
000 xx 001 00 x 1 0 1 //sw
001 xx 010 01 x 0 0 0 //beq
xxx 00 011 01 x x 1 0 //jal
110 01 xxx 00 x 0 1 0 //sll
011 01 000 00 x 1 1 0 //ori
000 01 100 00 x 1 1 0 
*/

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
        info.BRwr = item.at("BRwr").get<bool>();
        info.ALUsrc = item.at("ALUsrc").get<uint8_t>();
        info.ALUctr = item.at("ALUctr").get<uint8_t>();
        info.MemWr = item.at("MemWr").get<bool>();
        info.ResSrc = item.at("ResSrc").get<uint8_t>();
        info.ImmSrc = item.at("ImmSrc").get<uint8_t>();
        info.mask = item.at("mask").get<uint32_t>();
        info.value = item.at("value").get<uint32_t>();
        info.type = item.at("type").get<std::string>()[0]; // Coge el primer char del string
        info.cycles=item.at("cycles").get<uint8_t>();
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
