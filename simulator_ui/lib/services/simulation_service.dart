/// Define el "contrato" que cualquier proveedor de simulación (sea FFI, API, etc.)
/// debe cumplir. La UI solo interactuará con esta clase abstracta.

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
      'mux_wb_bus': getReadyAt('C'),          // Mux para Write Back
      'mux_pc_bus': getReadyAt('PC_next'),    // Mux para PC
      'mux_alu_b_bus': getReadyAt('ALU_B'),   // Mux para entrada B del ALU´
      'pcsrc_bus': getReadyAt('PCsrc'),       // Mux para PCsrc'
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
      'mux_wb_bus': getIsActive('C'),
      'mux_pc_bus': getIsActive('PC_next'),
      'mux_alu_b_bus': getIsActive('ALU_B'),
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
      'mux_wb_bus': getValue('C'),
      'mux_pc_bus': getValue('PC_next'),
      'mux_alu_b_bus': getValue('ALU_B'),
      'da_bus':getValue('DA'),
      'db_bus':getValue('DB'),
      'dc_bus':getValue('DC'),
    };

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

  /// Resetea la simulación a su estado inicial.
  Future<SimulationState> reset();
}