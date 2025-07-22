#include "Simulator.h"
#include <iostream>
#include <vector>

int main() {
    // Crea un simulador con 1MB de memoria
    Simulator sim(1024 * 1024); 
    std::cout << "Simulator created successfully." << std::endl;
    std::cout << "Initial PC: 0x" << std::hex << sim.get_pc() << std::endl;
    
    // Aquí podrías añadir código para cargar un programa y ejecutarlo paso a paso
    return 0;
}