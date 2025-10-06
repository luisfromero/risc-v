#include "Simulator.h"
#include <vector>
// Incluimos el macro de exportación para que las funciones sean visibles en la DLL.
#include "CoreExport.h"
#include <nlohmann/json.hpp>


using json = nlohmann::json;

// Estructura para la comunicación de la memoria de instrucciones desensamblada.
// El código que llama a la DLL (Python/ctypes) deberá definir una estructura compatible.
struct InstructionEntry {
    uint32_t value;
    char instruction[256];
};


    const char *jsonFromState(DatapathState &state)
    {
        thread_local static std::string json_str;
        json j = {
            {"PC", {{"value", state.bus_PC.value}, {"ready_at", state.bus_PC.ready_at}, {"is_active", state.bus_PC.is_active}}},
            {"Instr", {{"value", state.bus_Instr.value}, {"ready_at", state.bus_Instr.ready_at}, {"is_active", state.bus_Instr.is_active}}},
            {"opcode", {{"value", state.bus_opcode.value}, {"ready_at", state.bus_opcode.ready_at}, {"is_active", state.bus_opcode.is_active}}},
            {"funct3", {{"value", state.bus_funct3.value}, {"ready_at", state.bus_funct3.ready_at}, {"is_active", state.bus_funct3.is_active}}},
            {"funct7", {{"value", state.bus_funct7.value}, {"ready_at", state.bus_funct7.ready_at}, {"is_active", state.bus_funct7.is_active}}},
            {"DA", {{"value", state.bus_DA.value}, {"ready_at", state.bus_DA.ready_at}, {"is_active", state.bus_DA.is_active}}},
            {"DB", {{"value", state.bus_DB.value}, {"ready_at", state.bus_DB.ready_at}, {"is_active", state.bus_DB.is_active}}},
            {"DC", {{"value", state.bus_DC.value}, {"ready_at", state.bus_DC.ready_at}, {"is_active", state.bus_DC.is_active}}},
            {"A", {{"value", state.bus_A.value}, {"ready_at", state.bus_A.ready_at}, {"is_active", state.bus_A.is_active}}},
            {"B", {{"value", state.bus_B.value}, {"ready_at", state.bus_B.ready_at}, {"is_active", state.bus_B.is_active}}},
            {"imm", {{"value", state.bus_imm.value}, {"ready_at", state.bus_imm.ready_at}, {"is_active", state.bus_imm.is_active}}},
            {"immExt", {{"value", state.bus_immExt.value}, {"ready_at", state.bus_immExt.ready_at}, {"is_active", state.bus_immExt.is_active}}},
            {"ALU_A", {{"value", state.bus_ALU_A.value}, {"ready_at", state.bus_ALU_A.ready_at}, {"is_active", state.bus_ALU_A.is_active}}},
            {"ALU_B", {{"value", state.bus_ALU_B.value}, {"ready_at", state.bus_ALU_B.ready_at}, {"is_active", state.bus_ALU_B.is_active}}},
            {"ALU_result", {{"value", state.bus_ALU_result.value}, {"ready_at", state.bus_ALU_result.ready_at}, {"is_active", state.bus_ALU_result.is_active}}},
            {"ALU_zero", {{"value", state.bus_ALU_zero.value}, {"ready_at", state.bus_ALU_zero.ready_at}, {"is_active", state.bus_ALU_zero.is_active}}},
            {"Control", {{"value", state.bus_Control.value}, {"ready_at", state.bus_Control.ready_at}, {"is_active", state.bus_Control.is_active}}},
            {"PCsrc", {{"value", state.bus_PCsrc.value}, {"ready_at", state.bus_PCsrc.ready_at}, {"is_active", state.bus_PCsrc.is_active}}},
            {"ALUsrc", {{"value", state.bus_ALUsrc.value}, {"ready_at", state.bus_ALUsrc.ready_at}, {"is_active", state.bus_ALUsrc.is_active}}},
            {"ResSrc", {{"value", state.bus_ResSrc.value}, {"ready_at", state.bus_ResSrc.ready_at}, {"is_active", state.bus_ResSrc.is_active}}},
            {"ImmSrc", {{"value", state.bus_ImmSrc.value}, {"ready_at", state.bus_ImmSrc.ready_at}, {"is_active", state.bus_ImmSrc.is_active}}},
            {"ALUctr", {{"value", state.bus_ALUctr.value}, {"ready_at", state.bus_ALUctr.ready_at}, {"is_active", state.bus_ALUctr.is_active}}},
            {"BRwr", {{"value", state.bus_BRwr.value}, {"ready_at", state.bus_BRwr.ready_at}, {"is_active", state.bus_BRwr.is_active}}},
            {"MemWr", {{"value", state.bus_MemWr.value}, {"ready_at", state.bus_MemWr.ready_at}, {"is_active", state.bus_MemWr.is_active}}},
            {"Mem_address", {{"value", state.bus_Mem_address.value}, {"ready_at", state.bus_Mem_address.ready_at}, {"is_active", state.bus_Mem_address.is_active}}},
            {"Mem_write_data", {{"value", state.bus_Mem_write_data.value}, {"ready_at", state.bus_Mem_write_data.ready_at}, {"is_active", state.bus_Mem_write_data.is_active}}},
            {"Mem_read_data", {{"value", state.bus_Mem_read_data.value}, {"ready_at", state.bus_Mem_read_data.ready_at}, {"is_active", state.bus_Mem_read_data.is_active}}},
            {"C", {{"value", state.bus_C.value}, {"ready_at", state.bus_C.ready_at}, {"is_active", state.bus_C.is_active}}},
            {"PC_plus4", {{"value", state.bus_PC_plus4.value}, {"ready_at", state.bus_PC_plus4.ready_at}, {"is_active", state.bus_PC_plus4.is_active}}},
            {"PC_dest", {{"value", state.bus_PC_dest.value}, {"ready_at", state.bus_PC_dest.ready_at}, {"is_active", state.bus_PC_dest.is_active}}},
            {"PC_next", {{"value", state.bus_PC_next.value}, {"ready_at", state.bus_PC_next.ready_at}, {"is_active", state.bus_PC_next.is_active}}},
            {"branch_taken", {{"value", state.bus_branch_taken.value}, {"ready_at", state.bus_branch_taken.ready_at}, {"is_active", state.bus_branch_taken.is_active}}},
            {"criticalTime", state.criticalTime},
            {"totalMicroCycles",state.total_micro_cycles},
            {"instruction_cptr",state.instruction_cptr},

            {"Pipe_IF_instruction_cptr",state.Pipe_IF_instruction_cptr},
            {"Pipe_ID_instruction_cptr",state.Pipe_ID_instruction_cptr},
            {"Pipe_EX_instruction_cptr",state.Pipe_EX_instruction_cptr},
            {"Pipe_MEM_instruction_cptr",state.Pipe_MEM_instruction_cptr},
            {"Pipe_WB_instruction_cptr",state.Pipe_WB_instruction_cptr},
            
            {"Pipe_IF_instruction",state.Pipe_IF_instruction},
            {"Pipe_ID_instruction",state.Pipe_ID_instruction},
            {"Pipe_EX_instruction",state.Pipe_EX_instruction},
            {"Pipe_MEM_instruction",state.Pipe_MEM_instruction},
            {"Pipe_WB_instruction",state.Pipe_WB_instruction},
            
            // --- Pipeline Registers ---  Ojo al orden. Debe ser igual en main.py
            {"Pipe_IF_ID_NPC", {{"value", state.Pipe_IF_ID_NPC.value}, {"ready_at", state.Pipe_IF_ID_NPC.ready_at}, {"is_active", state.Pipe_IF_ID_NPC.is_active}}},
            {"Pipe_IF_ID_NPC_out", {{"value", state.Pipe_IF_ID_NPC_out.value}, {"ready_at", state.Pipe_IF_ID_NPC_out.ready_at}, {"is_active", state.Pipe_IF_ID_NPC_out.is_active}}},
            {"Pipe_IF_ID_Instr", {{"value", state.Pipe_IF_ID_Instr.value}, {"ready_at", state.Pipe_IF_ID_Instr.ready_at}, {"is_active", state.Pipe_IF_ID_Instr.is_active}}},
            {"Pipe_IF_ID_Instr_out", {{"value", state.Pipe_IF_ID_Instr_out.value}, {"ready_at", state.Pipe_IF_ID_Instr_out.ready_at}, {"is_active", state.Pipe_IF_ID_Instr_out.is_active}}},
            {"Pipe_IF_ID_PC", {{"value", state.Pipe_IF_ID_PC.value}, {"ready_at", state.Pipe_IF_ID_PC.ready_at}, {"is_active", state.Pipe_IF_ID_PC.is_active}}},
            {"Pipe_IF_ID_PC_out", {{"value", state.Pipe_IF_ID_PC_out.value}, {"ready_at", state.Pipe_IF_ID_PC_out.ready_at}, {"is_active", state.Pipe_IF_ID_PC_out.is_active}}},

            {"Pipe_ID_EX_Control", {{"value", state.Pipe_ID_EX_Control.value}, {"ready_at", state.Pipe_ID_EX_Control.ready_at}, {"is_active", state.Pipe_ID_EX_Control.is_active}}},
            {"Pipe_ID_EX_Control_out", {{"value", state.Pipe_ID_EX_Control_out.value}, {"ready_at", state.Pipe_ID_EX_Control_out.ready_at}, {"is_active", state.Pipe_ID_EX_Control_out.is_active}}},
            {"Pipe_ID_EX_NPC", {{"value", state.Pipe_ID_EX_NPC.value}, {"ready_at", state.Pipe_ID_EX_NPC.ready_at}, {"is_active", state.Pipe_ID_EX_NPC.is_active}}},
            {"Pipe_ID_EX_NPC_out", {{"value", state.Pipe_ID_EX_NPC_out.value}, {"ready_at", state.Pipe_ID_EX_NPC_out.ready_at}, {"is_active", state.Pipe_ID_EX_NPC_out.is_active}}},
            {"Pipe_ID_EX_A", {{"value", state.Pipe_ID_EX_A.value}, {"ready_at", state.Pipe_ID_EX_A.ready_at}, {"is_active", state.Pipe_ID_EX_A.is_active}}},
            {"Pipe_ID_EX_A_out", {{"value", state.Pipe_ID_EX_A_out.value}, {"ready_at", state.Pipe_ID_EX_A_out.ready_at}, {"is_active", state.Pipe_ID_EX_A_out.is_active}}},
            {"Pipe_ID_EX_B", {{"value", state.Pipe_ID_EX_B.value}, {"ready_at", state.Pipe_ID_EX_B.ready_at}, {"is_active", state.Pipe_ID_EX_B.is_active}}},
            {"Pipe_ID_EX_B_out", {{"value", state.Pipe_ID_EX_B_out.value}, {"ready_at", state.Pipe_ID_EX_B_out.ready_at}, {"is_active", state.Pipe_ID_EX_B_out.is_active}}},
            {"Pipe_ID_EX_RD", {{"value", state.Pipe_ID_EX_RD.value}, {"ready_at", state.Pipe_ID_EX_RD.ready_at}, {"is_active", state.Pipe_ID_EX_RD.is_active}}},
            {"Pipe_ID_EX_RD_out", {{"value", state.Pipe_ID_EX_RD_out.value}, {"ready_at", state.Pipe_ID_EX_RD_out.ready_at}, {"is_active", state.Pipe_ID_EX_RD_out.is_active}}},
            {"Pipe_ID_EX_RS1", {{"value", state.Pipe_ID_EX_RS1.value}, {"ready_at", state.Pipe_ID_EX_RS1.ready_at}, {"is_active", state.Pipe_ID_EX_RS1.is_active}}},
            {"Pipe_ID_EX_RS1_out", {{"value", state.Pipe_ID_EX_RS1_out.value}, {"ready_at", state.Pipe_ID_EX_RS1_out.ready_at}, {"is_active", state.Pipe_ID_EX_RS1_out.is_active}}},
            {"Pipe_ID_EX_RS2", {{"value", state.Pipe_ID_EX_RS2.value}, {"ready_at", state.Pipe_ID_EX_RS2.ready_at}, {"is_active", state.Pipe_ID_EX_RS2.is_active}}},
            {"Pipe_ID_EX_RS2_out", {{"value", state.Pipe_ID_EX_RS2_out.value}, {"ready_at", state.Pipe_ID_EX_RS2_out.ready_at}, {"is_active", state.Pipe_ID_EX_RS2_out.is_active}}},
            {"Pipe_ID_EX_Imm", {{"value", state.Pipe_ID_EX_Imm.value}, {"ready_at", state.Pipe_ID_EX_Imm.ready_at}, {"is_active", state.Pipe_ID_EX_Imm.is_active}}},
            {"Pipe_ID_EX_Imm_out", {{"value", state.Pipe_ID_EX_Imm_out.value}, {"ready_at", state.Pipe_ID_EX_Imm_out.ready_at}, {"is_active", state.Pipe_ID_EX_Imm_out.is_active}}},
            {"Pipe_ID_EX_PC", {{"value", state.Pipe_ID_EX_PC.value}, {"ready_at", state.Pipe_ID_EX_PC.ready_at}, {"is_active", state.Pipe_ID_EX_PC.is_active}}},
            {"Pipe_ID_EX_PC_out", {{"value", state.Pipe_ID_EX_PC_out.value}, {"ready_at", state.Pipe_ID_EX_PC_out.ready_at}, {"is_active", state.Pipe_ID_EX_PC_out.is_active}}},

            {"Pipe_EX_MEM_Control", {{"value", state.Pipe_EX_MEM_Control.value}, {"ready_at", state.Pipe_EX_MEM_Control.ready_at}, {"is_active", state.Pipe_EX_MEM_Control.is_active}}},
            {"Pipe_EX_MEM_Control_out", {{"value", state.Pipe_EX_MEM_Control_out.value}, {"ready_at", state.Pipe_EX_MEM_Control_out.ready_at}, {"is_active", state.Pipe_EX_MEM_Control_out.is_active}}},
            {"Pipe_EX_MEM_NPC", {{"value", state.Pipe_EX_MEM_NPC.value}, {"ready_at", state.Pipe_EX_MEM_NPC.ready_at}, {"is_active", state.Pipe_EX_MEM_NPC.is_active}}},
            {"Pipe_EX_MEM_NPC_out", {{"value", state.Pipe_EX_MEM_NPC_out.value}, {"ready_at", state.Pipe_EX_MEM_NPC_out.ready_at}, {"is_active", state.Pipe_EX_MEM_NPC_out.is_active}}},
            {"Pipe_EX_MEM_ALU_result", {{"value", state.Pipe_EX_MEM_ALU_result.value}, {"ready_at", state.Pipe_EX_MEM_ALU_result.ready_at}, {"is_active", state.Pipe_EX_MEM_ALU_result.is_active}}},
            {"Pipe_EX_MEM_ALU_result_out", {{"value", state.Pipe_EX_MEM_ALU_result_out.value}, {"ready_at", state.Pipe_EX_MEM_ALU_result_out.ready_at}, {"is_active", state.Pipe_EX_MEM_ALU_result_out.is_active}}},
            {"Pipe_EX_MEM_B", {{"value", state.Pipe_EX_MEM_B.value}, {"ready_at", state.Pipe_EX_MEM_B.ready_at}, {"is_active", state.Pipe_EX_MEM_B.is_active}}},
            {"Pipe_EX_MEM_B_out", {{"value", state.Pipe_EX_MEM_B_out.value}, {"ready_at", state.Pipe_EX_MEM_B_out.ready_at}, {"is_active", state.Pipe_EX_MEM_B_out.is_active}}},
            {"Pipe_EX_MEM_RD", {{"value", state.Pipe_EX_MEM_RD.value}, {"ready_at", state.Pipe_EX_MEM_RD.ready_at}, {"is_active", state.Pipe_EX_MEM_RD.is_active}}},
            {"Pipe_EX_MEM_RD_out", {{"value", state.Pipe_EX_MEM_RD_out.value}, {"ready_at", state.Pipe_EX_MEM_RD_out.ready_at}, {"is_active", state.Pipe_EX_MEM_RD_out.is_active}}},

            {"Pipe_MEM_WB_Control", {{"value", state.Pipe_MEM_WB_Control.value}, {"ready_at", state.Pipe_MEM_WB_Control.ready_at}, {"is_active", state.Pipe_MEM_WB_Control.is_active}}},
            {"Pipe_MEM_WB_Control_out", {{"value", state.Pipe_MEM_WB_Control_out.value}, {"ready_at", state.Pipe_MEM_WB_Control_out.ready_at}, {"is_active", state.Pipe_MEM_WB_Control_out.is_active}}},
            {"Pipe_MEM_WB_NPC", {{"value", state.Pipe_MEM_WB_NPC.value}, {"ready_at", state.Pipe_MEM_WB_NPC.ready_at}, {"is_active", state.Pipe_MEM_WB_NPC.is_active}}},
            {"Pipe_MEM_WB_NPC_out", {{"value", state.Pipe_MEM_WB_NPC_out.value}, {"ready_at", state.Pipe_MEM_WB_NPC_out.ready_at}, {"is_active", state.Pipe_MEM_WB_NPC_out.is_active}}},
            {"Pipe_MEM_WB_ALU_result", {{"value", state.Pipe_MEM_WB_ALU_result.value}, {"ready_at", state.Pipe_MEM_WB_ALU_result.ready_at}, {"is_active", state.Pipe_MEM_WB_ALU_result.is_active}}},
            {"Pipe_MEM_WB_ALU_result_out", {{"value", state.Pipe_MEM_WB_ALU_result_out.value}, {"ready_at", state.Pipe_MEM_WB_ALU_result_out.ready_at}, {"is_active", state.Pipe_MEM_WB_ALU_result_out.is_active}}},
            {"Pipe_MEM_WB_RM", {{"value", state.Pipe_MEM_WB_RM.value}, {"ready_at", state.Pipe_MEM_WB_RM.ready_at}, {"is_active", state.Pipe_MEM_WB_RM.is_active}}},
            {"Pipe_MEM_WB_RM_out", {{"value", state.Pipe_MEM_WB_RM_out.value}, {"ready_at", state.Pipe_MEM_WB_RM_out.ready_at}, {"is_active", state.Pipe_MEM_WB_RM_out.is_active}}},
            {"Pipe_MEM_WB_RD", {{"value", state.Pipe_MEM_WB_RD.value}, {"ready_at", state.Pipe_MEM_WB_RD.ready_at}, {"is_active", state.Pipe_MEM_WB_RD.is_active}}},
            {"Pipe_MEM_WB_RD_out", {{"value", state.Pipe_MEM_WB_RD_out.value}, {"ready_at", state.Pipe_MEM_WB_RD_out.ready_at}, {"is_active", state.Pipe_MEM_WB_RD_out.is_active}}},

            // --- Señales de Riesgo ---
            {"bus_stall", {{"value", state.bus_stall.value}, {"ready_at", state.bus_stall.ready_at}, {"is_active", state.bus_stall.is_active}}},
            {"bus_flush", {{"value", state.bus_flush.value}, {"ready_at", state.bus_flush.ready_at}, {"is_active", state.bus_flush.is_active}}},

            // --- Señales para Cortocircuitos (Forwarding) ---
            {"bus_ControlForwardA", {{"value", state.bus_ControlForwardA.value}, {"ready_at", state.bus_ControlForwardA.ready_at}, {"is_active", state.bus_ControlForwardA.is_active}}},
            {"bus_ControlForwardB", {{"value", state.bus_ControlForwardB.value}, {"ready_at", state.bus_ControlForwardB.ready_at}, {"is_active", state.bus_ControlForwardB.is_active}}},
            {"bus_ForwardA", {{"value", state.bus_ForwardA.value}, {"ready_at", state.bus_ForwardA.ready_at}, {"is_active", state.bus_ForwardA.is_active}}},
            {"bus_ForwardB", {{"value", state.bus_ForwardB.value}, {"ready_at", state.bus_ForwardB.ready_at}, {"is_active", state.bus_ForwardB.is_active}}},


        };

        json_str = j.dump();
        return json_str.c_str();
    }

// Interfaz C-style para que Python (ctypes) pueda llamar a nuestro código C++.
// Usamos extern "C" para evitar que el compilador de C++ modifique los nombres de las funciones.
extern "C" {

    SIMULATOR_API void* Simulator_new(size_t mem_size, int model_type) {
        // Creamos una instancia del simulador y devolvemos un puntero opaco (void*).
        // model_type: 3=General, 0=SingleCycle. Ver Simulator.h
        return new (std::nothrow) Simulator(mem_size, static_cast<PipelineModel>(model_type));
    }

    SIMULATOR_API void Simulator_delete(void* sim_ptr) {
        // Liberamos la memoria del simulador.
        delete static_cast<Simulator*>(sim_ptr);
    }

    SIMULATOR_API void Simulator_load_program(void* sim_ptr, const uint8_t* program_data, size_t data_size, int mode_int) {
        if (!sim_ptr) return;
        const std::vector<uint8_t> program(program_data, program_data + data_size);
        static_cast<Simulator*>(sim_ptr)->load_program(program,static_cast<PipelineModel>(mode_int));
    }

    SIMULATOR_API void Simulator_load_program_from_assembly(void* sim_ptr, const char* assembly_code, int mode_int) {
        if (!sim_ptr || !assembly_code) return;
        // Llama a la sobrecarga de load_program que acepta código ensamblador.
        static_cast<Simulator*>(sim_ptr)->load_program(assembly_code, static_cast<PipelineModel>(mode_int));
    }

    SIMULATOR_API size_t Simulator_assemble(void* sim_ptr, const char* assembly_code, uint8_t* buffer_out, size_t buffer_capacity) {
        if (!sim_ptr || !assembly_code) {
            return 0;
        }

        Simulator* simulator = static_cast<Simulator*>(sim_ptr);
        std::vector<uint8_t> machine_code = simulator->assemble(assembly_code);

        // Si se proporciona un buffer, se copian los datos.
        if (buffer_out != nullptr && buffer_capacity > 0) {
            size_t bytes_to_copy = std::min(machine_code.size(), buffer_capacity);
            if (bytes_to_copy > 0) {
                std::memcpy(buffer_out, machine_code.data(), bytes_to_copy);
            }
        }

        // Siempre se devuelve el tamaño total del código máquina.
        // El llamador puede comparar este valor con la capacidad del buffer para detectar truncamiento.
        return machine_code.size();
    }

    SIMULATOR_API const char* Simulator_reset(void* sim_ptr) {
        if (!sim_ptr) return "{}";
        // Llama a reset sin argumentos, usando el valor por defecto (SingleCycle) que hemos definido en Simulator.h
        static_cast<Simulator*>(sim_ptr)->reset();
        DatapathState state = static_cast<Simulator*>(sim_ptr)->get_datapath_state();
        return jsonFromState(state); // fastapi no lo usa; prefiere llamar a state después
    }

    // Nueva función para que la UI pueda especificar el modo al resetear.
    SIMULATOR_API const char* Simulator_reset_with_model(void* sim_ptr, int mode_int, uint32_t initial_pc) {
        if (!sim_ptr) return "{}";
        static_cast<Simulator*>(sim_ptr)->reset(static_cast<PipelineModel>(mode_int), initial_pc);
        DatapathState state = static_cast<Simulator*>(sim_ptr)->get_datapath_state();
        return jsonFromState(state);
    }

    SIMULATOR_API const char*  Simulator_step(void* sim_ptr) {
        if (!sim_ptr) return "{}";
        static_cast<Simulator*>(sim_ptr)->step();
        DatapathState state = static_cast<Simulator*>(sim_ptr)->get_datapath_state();
        return jsonFromState(state); // fastapi no lo usa; prefiere llamar a state después
    }

    SIMULATOR_API const char* Simulator_step_back(void* sim_ptr) {
        if (!sim_ptr) return "{}";
        static_cast<Simulator*>(sim_ptr)->step_back();
        DatapathState state = static_cast<Simulator*>(sim_ptr)->get_datapath_state();
        return jsonFromState(state);
    }

    SIMULATOR_API uint32_t Simulator_get_pc(void* sim_ptr) {
        if (!sim_ptr) return 0;
        return static_cast<Simulator*>(sim_ptr)->get_pc();
    }

    SIMULATOR_API DatapathState Simulator_get_datapath_state(void* sim_ptr) {
        if (!sim_ptr) return {};
        return static_cast<Simulator*>(sim_ptr)->get_datapath_state();
    }

    SIMULATOR_API const char* Simulator_get_state_json(void* sim_ptr) {
        if (!sim_ptr) return "{}";

        DatapathState state = static_cast<Simulator*>(sim_ptr)->get_datapath_state();

        return jsonFromState(state);
    }

    SIMULATOR_API uint32_t Simulator_get_status_register(void* sim_ptr) {
        if (!sim_ptr) return 0;
        return static_cast<Simulator*>(sim_ptr)->get_status_register();
    }

    SIMULATOR_API void Simulator_get_all_registers(void* sim_ptr, uint32_t* buffer_out) {
        if (!sim_ptr || !buffer_out) return;
        const RegisterFile& regs = static_cast<Simulator*>(sim_ptr)->get_registers();
        for (uint8_t i = 0; i < 32; ++i) {
            buffer_out[i] = regs.readA(i);
        }
    }

    SIMULATOR_API const char* Simulator_get_instruction_string(void* sim_ptr) {
        if (!sim_ptr) {
            return "";
        }
        // Usamos 'thread_local' para asegurar que cada hilo (thread) de ejecución
        // tenga su propia copia de la cadena. Esto evita "condiciones de carrera"
        // (race conditions) en un entorno multihilo como un servidor web,
        // donde múltiples peticiones podrían intentar modificar la misma variable
        // estática simultáneamente, causando corrupción de memoria y fallos.
        thread_local static std::string instruction_str;
        instruction_str = static_cast<Simulator*>(sim_ptr)->get_instruction_string();
        return instruction_str.c_str();
    }

    SIMULATOR_API void Simulator_get_d_mem(void* sim_ptr, uint8_t* buffer_out, size_t buffer_size) {
        if (!sim_ptr || !buffer_out) return;

        const auto& d_mem_data = static_cast<Simulator*>(sim_ptr)->get_d_mem();
        
        // Nos aseguramos de no escribir más allá del tamaño del buffer proporcionado.
        size_t bytes_to_copy = std::min(d_mem_data.size(), buffer_size);
        
        if (bytes_to_copy > 0) {
            std::memcpy(buffer_out, d_mem_data.data(), bytes_to_copy);
        }
    }

    SIMULATOR_API size_t Simulator_get_i_mem(void* sim_ptr, InstructionEntry* buffer_out, size_t buffer_capacity_in_entries) {
        if (!sim_ptr) {
            return 0;
        }

        Simulator* simulator = static_cast<Simulator*>(sim_ptr);
        const auto& i_mem_data = simulator->get_i_mem();

        // Si el buffer es nulo o la capacidad es cero, la convención es devolver
        // el número total de entradas que hay, para que el llamador pueda alojar memoria.
        if (!buffer_out || buffer_capacity_in_entries == 0) {
            return i_mem_data.size();
        }
        
        size_t entries_to_copy = std::min(i_mem_data.size(), buffer_capacity_in_entries);

        for (size_t i = 0; i < entries_to_copy; ++i) {
            const auto& pair = i_mem_data[i];
            buffer_out[i].value = pair.first;
            
            // Copiamos la cadena de instrucción, asegurando la terminación nula
            // y evitando desbordamientos de buffer.
            strncpy(buffer_out[i].instruction, pair.second.c_str(), sizeof(InstructionEntry::instruction) - 1);
            buffer_out[i].instruction[sizeof(InstructionEntry::instruction) - 1] = '\0';
        }

        // Devolvemos el número total de entradas que tiene la memoria de instrucciones.
        // El llamador puede comparar este valor con la capacidad del buffer para saber si se truncaron datos.
        return i_mem_data.size();
    }



}