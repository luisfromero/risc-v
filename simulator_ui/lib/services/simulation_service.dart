/// Define el "contrato" que cualquier proveedor de simulación (sea FFI, API, etc.)
/// debe cumplir. La UI solo interactuará con esta clase abstracta.
import '../simulation_mode.dart';

/// Un objeto simple para contener el estado de la simulación en un instante dado.
class SimulationState {
  final String instruction;
  final int instructionValue;
  final int statusRegister;
  final Map<String, int> registers;
  final int pcValue;
  final int criticalTime;
  final Map<String, int> readyAt;
  final Map<String, bool> activePaths;
  final Map<String, int> busValues;
  // --- Campos para Multiciclo ---
  final int totalMicroCycles;
  // --- Campos para Pipeline ---
  final String pipeIfInstructionCptr;
  final String pipeIdInstructionCptr;
  final String pipeExInstructionCptr;
  final String pipeMemInstructionCptr;
  final String pipeWbInstructionCptr;

  SimulationState({
    this.instruction = '',
    this.instructionValue = 0,
    this.statusRegister = 0,
    this.criticalTime = 0,
    this.registers = const {},
    required this.pcValue,
    this.readyAt = const {},
    this.activePaths = const {},
    this.busValues = const {},
    this.totalMicroCycles = 0,
    this.pipeIfInstructionCptr = '',
    this.pipeIdInstructionCptr = '',
    this.pipeExInstructionCptr = '',
    this.pipeMemInstructionCptr = '',
    this.pipeWbInstructionCptr = '',
  });

  /// Crea un SimulationState a partir de un mapa JSON.
  factory SimulationState.fromJson(Map<String, dynamic> json) {
    // Determina dónde buscar los datos del datapath. La API los anida bajo "datapath",
    // mientras que FFI los deja en la raíz. Este código maneja ambos casos.
    final Map<String, dynamic> datapathJson;
    if (json.containsKey('datapath') && json['datapath'] is Map<String, dynamic>) {
      datapathJson = json['datapath'] as Map<String, dynamic>;
    } else {
      datapathJson = json;
    }

    datapathJson['control_ALUctr'] = datapathJson['Control']['value'] >> 13 & 7;
    datapathJson['control_ResSrc'] = datapathJson['Control']['value'] >> 11 & 3;
    datapathJson['control_ImmSrc'] = datapathJson['Control']['value'] >> 8 & 7;
    datapathJson['control_PCsrc'] = datapathJson['Control']['value'] >> 6 & 3;
    datapathJson['control_BRwr'] = datapathJson['Control']['value'] >> 4 & 1;
    datapathJson['control_ALUsrc'] = datapathJson['Control']['value'] >> 3 & 1;
    datapathJson['control_MemWr'] = datapathJson['Control']['value'] >> 2 & 1;

    // Helper para extraer de forma segura el 'ready_at' de una señal del JSON.
    int getReadyAt(String key) {
      final signal = datapathJson[key];
      if (signal is Map<String, dynamic>) {
        return signal['ready_at'] as int? ?? 0;
      }
      return 0;
    }

    // Helper para extraer de forma segura el 'is_active' de una señal del JSON.
    bool getIsActive(String key) {
      final signal = datapathJson[key];
      if (signal is Map<String, dynamic>) {
        return signal['is_active'] as bool? ?? false;
      }
      return false;
    }

    // Helper para extraer de forma segura el 'value' de una señal del JSON.
    int getValue(String key) {
      final signal = datapathJson[key];
      if (signal is Map<String, dynamic>) {
        return signal['value'] as int? ?? 0;
      }
      return 0;
    }

    // Mapea los nombres de las señales del backend a los nombres de los buses del frontend.
    final Map<String, int> readyAtMap = {
      'pc_bus': getReadyAt('PC'),
      'npc_bus': getReadyAt('PC_plus4'),
      'instruction_bus': getReadyAt('Instr'),
      'control_bus': getReadyAt('Control'),
      'rd1_bus': getReadyAt('A'),
      'rd2_bus': getReadyAt('B'),
      'immediate_bus': getReadyAt('immExt'),
      'alu_result_bus': getReadyAt('ALU_result'),
      'branch_target_bus': getReadyAt('PC_dest'),
      'mem_read_data_bus': getReadyAt('Mem_read_data'),
      'mem_write_data_bus': getReadyAt('Mem_write_data'),
      'mux_wb_bus': getReadyAt('C'),          // Mux para Write Back
      'mux_pc_bus': getReadyAt('PC_next'),    // Mux para PC
      'mux_alu_b_bus': getReadyAt('ALU_B'),   // Mux para entrada B del ALU´
      'pcsrc_bus': getReadyAt('PCsrc'),       // Mux para PCsrc'

      // --- Pipeline Registers ---
      // IF/ID Stage
      'Pipe_IF_ID_Instr': getReadyAt('Pipe_IF_ID_Instr'),
      'Pipe_IF_ID_NPC': getReadyAt('Pipe_IF_ID_NPC'),
      'Pipe_IF_ID_PC': getReadyAt('Pipe_IF_ID_PC'),

      // ID/EX Stage
      'Pipe_ID_EX_Control': getReadyAt('Pipe_ID_EX_Control'),
      'Pipe_ID_EX_NPC': getReadyAt('Pipe_ID_EX_NPC'),
      'Pipe_ID_EX_A': getReadyAt('Pipe_ID_EX_A'),
      'Pipe_ID_EX_B': getReadyAt('Pipe_ID_EX_B'),
      'Pipe_ID_EX_RD': getReadyAt('Pipe_ID_EX_RD'),
      'Pipe_ID_EX_Imm': getReadyAt('Pipe_ID_EX_Imm'),
      'Pipe_ID_EX_PC': getReadyAt('Pipe_ID_EX_PC'),

      // EX/MEM Stage
      'Pipe_EX_MEM_Control': getReadyAt('Pipe_EX_MEM_Control'),
      'Pipe_EX_MEM_NPC': getReadyAt('Pipe_EX_MEM_NPC'),
      'Pipe_EX_MEM_ALU_result': getReadyAt('Pipe_EX_MEM_ALU_result'),
      'Pipe_EX_MEM_B': getReadyAt('Pipe_EX_MEM_B'),
      'Pipe_EX_MEM_RD': getReadyAt('Pipe_EX_MEM_RD'),

      // MEM/WB Stage
      'Pipe_MEM_WB_Control': getReadyAt('Pipe_MEM_WB_Control'),
      'Pipe_MEM_WB_NPC': getReadyAt('Pipe_MEM_WB_NPC'),
      'Pipe_MEM_WB_ALU_result': getReadyAt('Pipe_MEM_WB_ALU_result'),
      'Pipe_MEM_WB_RM': getReadyAt('Pipe_MEM_WB_RM'),
      'Pipe_MEM_WB_RD': getReadyAt('Pipe_MEM_WB_RD'),
    };

    // Mapea las señales del backend para saber si están lógicamente activas.
    final Map<String, bool> activePathsMap = {
      'pc_bus': getIsActive('PC'),
      'npc_bus': getIsActive('PC_plus4'),
      'instruction_bus': getIsActive('Instr'),
      'rd1_bus': getIsActive('A'),
      'rd2_bus': getIsActive('B'),
      'immediate_bus': getIsActive('immExt'),
      'alu_result_bus': getIsActive('ALU_result'),
      'branch_target_bus': getIsActive('PC_dest'),
      'mem_read_data_bus': getIsActive('Mem_read_data'),
      'mem_write_data_bus': getIsActive('Mem_write_data'),
      'mux_wb_bus': getIsActive('C'),
      'mux_pc_bus': getIsActive('PC_next'),
      'mux_alu_b_bus': getIsActive('ALU_B'),

      // --- Pipeline Registers ---
      // IF/ID Stage
      'Pipe_IF_ID_Instr': getIsActive('Pipe_IF_ID_Instr'),
      'Pipe_IF_ID_NPC': getIsActive('Pipe_IF_ID_NPC'),
      'Pipe_IF_ID_PC': getIsActive('Pipe_IF_ID_PC'),

      // ID/EX Stage
      'Pipe_ID_EX_Control': getIsActive('Pipe_ID_EX_Control'),
      'Pipe_ID_EX_NPC': getIsActive('Pipe_ID_EX_NPC'),
      'Pipe_ID_EX_A': getIsActive('Pipe_ID_EX_A'),
      'Pipe_ID_EX_B': getIsActive('Pipe_ID_EX_B'),
      'Pipe_ID_EX_RD': getIsActive('Pipe_ID_EX_RD'),
      'Pipe_ID_EX_Imm': getIsActive('Pipe_ID_EX_Imm'),
      'Pipe_ID_EX_PC': getIsActive('Pipe_ID_EX_PC'),

      // EX/MEM Stage
      'Pipe_EX_MEM_Control': getIsActive('Pipe_EX_MEM_Control'),
      'Pipe_EX_MEM_NPC': getIsActive('Pipe_EX_MEM_NPC'),
      'Pipe_EX_MEM_ALU_result': getIsActive('Pipe_EX_MEM_ALU_result'),
      'Pipe_EX_MEM_B': getIsActive('Pipe_EX_MEM_B'),
      'Pipe_EX_MEM_RD': getIsActive('Pipe_EX_MEM_RD'),

      // MEM/WB Stage
      'Pipe_MEM_WB_Control': getIsActive('Pipe_MEM_WB_Control'),
      'Pipe_MEM_WB_NPC': getIsActive('Pipe_MEM_WB_NPC'),
      'Pipe_MEM_WB_ALU_result': getIsActive('Pipe_MEM_WB_ALU_result'),
      'Pipe_MEM_WB_RM': getIsActive('Pipe_MEM_WB_RM'),
      'Pipe_MEM_WB_RD': getIsActive('Pipe_MEM_WB_RD'),
    };

    final Map<String, int> busValuesMap = {
      'pc_bus': getValue('PC'),
      'npc_bus': getValue('PC_plus4'),
      'instruction_bus': getValue('Instr'),
      'rd1_bus': getValue('A'),
      'rd2_bus': getValue('B'),
      'immediate_bus': getValue('immExt'),
      'alu_result_bus': getValue('ALU_result'),
      'branch_target_bus': getValue('PC_dest'),
      'mem_read_data_bus': getValue('Mem_read_data'),
      'mem_write_data_bus': getValue('Mem_write_data'),
      'mux_wb_bus': getValue('C'),
      'mux_pc_bus': getValue('PC_next'),
      'mux_alu_b_bus': getValue('ALU_B'),
      'da_bus':getValue('DA'),
      'db_bus':getValue('DB'),
      'dc_bus':getValue('DC'),
      'control_PCsrc':getValue('PCsrc'),
      'control_ALUctr':getValue('ALUctr '),
      'control_ResSrc':getValue('ResSrc'),
      'control_ImmSrc':getValue('ImmSrc'),
      'control_PCsrc':datapathJson['control_PCsrc'] as int? ?? 0,
      'control_BRwr':datapathJson['control_BRwr'] as int? ?? 0,
      'control_ALUsrc':datapathJson['control_ALUsrc'] as int? ?? 0,
      'control_MemWr':datapathJson['control_MemWr'] as int? ?? 0,    
      'control_ResSrc':datapathJson['control_ResSrc'] as int? ?? 0,
      'control_ALUctr':datapathJson['control_ALUctr'] as int? ?? 0,
      
      // --- Pipeline Registers ---
      // IF/ID Stage
      'Pipe_IF_ID_Instr': getValue('Pipe_IF_ID_Instr'),
      'Pipe_IF_ID_NPC': getValue('Pipe_IF_ID_NPC'),
      'Pipe_IF_ID_PC': getValue('Pipe_IF_ID_PC'),

      // ID/EX Stage
      'Pipe_ID_EX_Control': getValue('Pipe_ID_EX_Control'),
      'Pipe_ID_EX_NPC': getValue('Pipe_ID_EX_NPC'),
      'Pipe_ID_EX_A': getValue('Pipe_ID_EX_A'),
      'Pipe_ID_EX_B': getValue('Pipe_ID_EX_B'),
      'Pipe_ID_EX_RD': getValue('Pipe_ID_EX_RD'),
      'Pipe_ID_EX_Imm': getValue('Pipe_ID_EX_Imm'),
      'Pipe_ID_EX_PC': getValue('Pipe_ID_EX_PC'),

      // EX/MEM Stage
      'Pipe_EX_MEM_Control': getValue('Pipe_EX_MEM_Control'),
      'Pipe_EX_MEM_NPC': getValue('Pipe_EX_MEM_NPC'),
      'Pipe_EX_MEM_ALU_result': getValue('Pipe_EX_MEM_ALU_result'),
      'Pipe_EX_MEM_B': getValue('Pipe_EX_MEM_B'),
      'Pipe_EX_MEM_RD': getValue('Pipe_EX_MEM_RD'),
      

    };

    // --- Campos para Multiciclo (opcionales) ---
    final int totalMicroCycles = json['totalMicroCycles'] as int? ?? 0;


    return SimulationState(
      // Extrae los nuevos campos del JSON.
      instruction: json['instruction'] as String? ?? '',
      instructionValue: getValue('Instr'),
      criticalTime: json['criticaltime'] as int? ?? 0,
      statusRegister: json['status_register'] as int? ?? 0,
      pcValue: json['pc'] as int? ?? 0,
      registers: Map<String, int>.from(json['registers'] as Map? ?? {}),
      readyAt: readyAtMap,
      activePaths: activePathsMap,
      busValues: busValuesMap,
      totalMicroCycles: totalMicroCycles,
      pipeIfInstructionCptr: json['Pipe_IF_instruction_cptr'] as String? ?? '',
      pipeIdInstructionCptr: json['Pipe_ID_instruction_cptr'] as String? ?? '',
      pipeExInstructionCptr: json['Pipe_EX_instruction_cptr'] as String? ?? '',
      pipeMemInstructionCptr: json['Pipe_MEM_instruction_cptr'] as String? ?? '',
      pipeWbInstructionCptr: json['Pipe_WB_instruction_cptr'] as String? ?? '',
    );
  }

  @override
  String toString() {
    // Helper para formatear un mapa en una cadena legible, ideal para depuración.
    String formatMap(Map<String, dynamic> map) {
      if (map.isEmpty) return '    (empty)';
      return map.entries.map((e) {
        var value = e.value;
        if (value is int) {
          return '    ${e.key.padRight(20)}: ${value.toString().padLeft(4)} (0x${value.toRadixString(16)})';
        }
        return '    ${e.key.padRight(20)}: $value';
      }).join('\n');
    }

    return '''
--- SimulationState ---
  Instruction: "$instruction" (0x${instructionValue.toRadixString(16)})
  PC: 0x${pcValue.toRadixString(16)}
  CriticalTime: $criticalTime
  Active Paths:\n${formatMap(activePaths)}\n
  Ready At:\n${formatMap(readyAt)}\n
  Registers: {${registers.length} regs}
-----------------------''';
  }
}

abstract class SimulationService {
  /// Inicializa el servicio (ej. cargar la DLL).
  Future<void> initialize();

  /// Ejecuta un ciclo de reloj y devuelve el nuevo estado.
  Future<SimulationState> step();

  /// Retrocede un ciclo de reloj y devuelve el estado anterior.
  Future<SimulationState> stepBack();

  /// Resetea la simulación a su estado inicial.
  Future<SimulationState> reset({required SimulationMode mode});
}