#pragma once

#include <cstdint>
#include <vector>
#include "CoreTypes.h"
#include "CoreExport.h"

class SIMULATOR_API ControlUnit {
public:
    ControlUnit();
    void set_delay(uint32_t new_delay) { delay = new_delay; }
    uint32_t get_delay() const { return delay; }
    std::vector<InstructionInfo> get_control_table();
    void load_control_table(const std::string& json_path);
    const InstructionInfo* decode(uint32_t instruction);
    uint32_t decode(uint32_t instruction, uint8_t status_register);
    uint32_t decode(uint32_t instruction, bool Z);

private:
    uint32_t delay=5;
    std::vector<InstructionInfo> control_table;
};
