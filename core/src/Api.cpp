#include "Simulator.h"
#include <vector>
// Incluimos el macro de exportación para que las funciones sean visibles en la DLL.
#include "CoreExport.h"

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

    SIMULATOR_API void Simulator_load_program(void* sim_ptr, const uint8_t* program_data, size_t data_size) {
        if (!sim_ptr) return;
        const std::vector<uint8_t> program(program_data, program_data + data_size);
        static_cast<Simulator*>(sim_ptr)->load_program(program);
    }

    SIMULATOR_API void Simulator_step(void* sim_ptr) {
        if (!sim_ptr) return;
        static_cast<Simulator*>(sim_ptr)->step();
    }

    SIMULATOR_API uint32_t Simulator_get_pc(void* sim_ptr) {
        if (!sim_ptr) return 0;
        return static_cast<Simulator*>(sim_ptr)->get_pc();
    }

    SIMULATOR_API DatapathState Simulator_get_datapath_state(void* sim_ptr) {
        if (!sim_ptr) return {0};
        return static_cast<Simulator*>(sim_ptr)->get_datapath_state();
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

}