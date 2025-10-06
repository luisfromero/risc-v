#include <iostream>
#include <vector>
#include <string>
#include <sstream>
#include <stdexcept>
#include <cstdint>
#include <ostream>
#include <algorithm>
#include <unordered_map>
#include <map>
#include <cctype>
#include "CoreExport.h"

// Estructura para almacenar la información de codificación de una instrucción.
struct InstructionData {
    std::string mnemonic;
    std::string type;
    std::string opcode;
    std::string funct3;
    std::string funct7;
};

/**
 * @class RISCVAssembler
 * @brief Ensambla un programa completo en ensamblador RISC-V a su representación en código máquina.
 *
 * Esta clase implementa un ensamblador de dos pasadas similar a la lógica
 * de un notebook de Python de referencia. Maneja limpieza de código,
 * resolución de etiquetas y ensamblado final.
 */
class SIMULATOR_API RISCVAssembler {
public:
    RISCVAssembler(std::ostream* log_stream = nullptr);


    /**
     * @brief Ensambla un programa completo de código ensamblador.
     * @param source_code El código fuente completo como una cadena de texto.
     * @return Un vector de bytes con el código máquina resultante en formato little-endian.
     * @throws std::runtime_error si ocurre un error de sintaxis o de ensamblado.
     */
    std::vector<uint8_t> assemble_program(const std::string& source_code);

    /**
     * @brief Devuelve la tabla de símbolos generada en la primera pasada.
     * @return Una referencia constante al mapa de etiquetas y sus direcciones.
     * @note Debe llamarse después de `assemble_program`.
     */
    const std::map<std::string, uint32_t>& get_symbol_table() const;

private:
    std::ostream* m_log;

    // Base de datos de instrucciones y mapa de registros.
    std::vector<InstructionData> instruction_db;
    std::unordered_map<std::string, std::string> reg_map;
    std::map<std::string, uint32_t> symbol_table;

    // Fases del ensamblador
    std::vector<std::string> preprocess(const std::string& source_code);
    std::vector<std::string> first_pass(const std::vector<std::string>& clean_lines);
    std::vector<std::string> second_pass(const std::vector<std::string>& instructions);
    std::vector<uint32_t> third_pass(const std::vector<std::string>& final_code);

    // Ensambla una única línea de código ya procesada
    uint32_t assemble_line(const std::string& instruction_str);
    
    // Funciones auxiliares para el ensamblado
    const InstructionData& getInstructionData(const std::string& mnemonic);
    int get_register_num(const std::string& reg);

    // Funciones de ensamblado por tipo de formato
    uint32_t ensamblarR(const std::vector<std::string>& partes, const InstructionData& instr_data);
    uint32_t ensamblarI(const std::vector<std::string>& partes, const InstructionData& instr_data);
    uint32_t ensamblarS(const std::vector<std::string>& partes, const InstructionData& instr_data);
    uint32_t ensamblarSB(const std::vector<std::string>& partes, const InstructionData& instr_data);
    uint32_t ensamblarUJ(const std::vector<std::string>& partes, const InstructionData& instr_data);
    uint32_t ensamblarU(const std::vector<std::string>& partes, const InstructionData& instr_data);
};