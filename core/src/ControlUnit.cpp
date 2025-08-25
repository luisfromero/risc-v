#include "ControlUnit.h"
#include "ControlTableData.h" // Fichero autogenerado

ControlUnit::ControlUnit() {
    // La tabla de control se inicializa desde el array `control_table_data`
    // que se encuentra en el fichero autogenerado `ControlTableData.h`.
    // Este array se genera a partir de `resources/instructions.json`.
    control_table.assign(std::begin(riscv_sim::control_table_data), std::end(riscv_sim::control_table_data));
}

std::vector<InstructionInfo> ControlUnit::get_control_table()
{
    return control_table;
}

//ToDo
uint32_t ControlUnit::decode(uint32_t instruction, uint8_t funct)
{
    return 0;
}

//ToDo
uint32_t ControlUnit::decode(uint32_t instruction, bool Z)
{
    return 0;
}


//ToDo
const InstructionInfo* ControlUnit::decode(uint32_t instruction) {
    for (const auto& info : control_table) {
        if ((instruction & info.mask) == info.value) {
            return &info;
        }
    }
    return nullptr; // Instrucción no reconocida
}
