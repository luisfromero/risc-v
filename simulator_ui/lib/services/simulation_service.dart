/// Define el "contrato" que cualquier proveedor de simulación (sea FFI, API, etc.)
/// debe cumplir. La UI solo interactuará con esta clase abstracta.
library;
//import 'dart:nativewrappers/_internal/vm/lib/ffi_native_type_patch.dart';

//import 'dart:ffi';

import '../generated/control_table.g.dart';
//import 'package:flutter/services.dart';

import '../simulation_mode.dart';
import '../datapath_state.dart';
import 'dart:typed_data';

///';
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

  final int pipeIfInstructionValue;
  final int pipeIdInstructionValue;
  final int pipeExInstructionValue;
  final int pipeMemInstructionValue;
  final int pipeWbInstructionValue;

  final instructionInfo;
  final pipeIfInstructionInfo;
  final pipeIdInstructionInfo;
  final pipeExInstructionInfo;
  final pipeMemInstructionInfo;
  final pipeWbInstructionInfo;

    // Nuevos campos para las memorias
  final List<InstructionMemoryItem>? instructionMemory;
  final Uint8List? dataMemory;

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
    this.pipeIfInstructionValue = 0x00000013,
    this.pipeIdInstructionValue = 0x00000013,
    this.pipeExInstructionValue = 0x00000013,
    this.pipeMemInstructionValue = 0x00000013,
    this.pipeWbInstructionValue = 0x00000013,
    this.instructionMemory,
    this.dataMemory,
    this.instructionInfo,
    this.pipeIfInstructionInfo,
    this.pipeIdInstructionInfo,
    this.pipeExInstructionInfo,
    this.pipeMemInstructionInfo,
    this.pipeWbInstructionInfo,
  });

  SimulationState copyWith({
    List<InstructionMemoryItem>? instructionMemory,
    Uint8List? dataMemory
  }) {
    return SimulationState(
      instruction: instruction,
      instructionValue: instructionValue,
      statusRegister: statusRegister,
      registers: registers,
      pcValue: pcValue,
      criticalTime: criticalTime,
      readyAt: readyAt,
      activePaths: activePaths,
      busValues: busValues,
      totalMicroCycles: totalMicroCycles,
      pipeIfInstructionCptr: pipeIfInstructionCptr,
      pipeIdInstructionCptr: pipeIdInstructionCptr,
      pipeExInstructionCptr: pipeExInstructionCptr,
      pipeMemInstructionCptr: pipeMemInstructionCptr,
      pipeWbInstructionCptr: pipeWbInstructionCptr,
      pipeIfInstructionValue: pipeIfInstructionValue,
      pipeIdInstructionValue: pipeIdInstructionValue,
      pipeExInstructionValue: pipeExInstructionValue,
      pipeMemInstructionValue: pipeMemInstructionValue,
      pipeWbInstructionValue: pipeWbInstructionValue,
      instructionMemory: instructionMemory ?? this.instructionMemory,
      dataMemory: dataMemory ?? this.dataMemory,
      instructionInfo: instructionInfo,
      pipeIfInstructionInfo: pipeIfInstructionInfo,
      pipeIdInstructionInfo: pipeIdInstructionInfo,
      pipeExInstructionInfo: pipeExInstructionInfo,
      pipeMemInstructionInfo: pipeMemInstructionInfo,
      pipeWbInstructionInfo: pipeWbInstructionInfo,
    );
  }

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

    // --- Helpers ---
    // Es crucial definir los helpers ANTES de usarlos.

    // Extrae de forma segura el 'value' de una señal del JSON.
    int getValue(String key) {
      final signal = datapathJson[key];
      if (signal is Map<String, dynamic>) {
        final value = signal['value'];
        if (value is bool) {
          return value ? 1 : 0;
        }
        return value as int? ?? 0;
      }
      return 0;
    }

    // Extrae de forma segura el 'ready_at' de una señal del JSON.
    int getReadyAt(String key) {
      final signal = datapathJson[key];
      if (signal is Map<String, dynamic>) {
        return signal['ready_at'] as int? ?? 0;
      }
      return 0;
    }

    // Extrae de forma segura el 'is_active' de una señal del JSON.
    bool getIsActive(String key) {
      final signal = datapathJson[key];
      if (signal is Map<String, dynamic>) {
        return signal['is_active'] as bool? ?? false;
      }
      return false;
    }

    // Decodifica una señal específica a partir de una palabra de control completa.
    int decodeSignal(String signalName, int controlWord) {
      final field = controlWordLayout[signalName];
      if (field == null) return 0;
      final position = field.position;
      final width = field.width;
      final mask = (1 << width) - 1;
      return (controlWord >> position) & mask;
    }

    // --- Decodificación de la palabra de control principal (Etapa ID) ---
    // Se decodifican las señales de control para la etapa ID y se añaden al mapa
    // para que la UI pueda mostrarlas.
    final int controlWordID = getValue('Control');
    final int control=controlWordID;

    controlWordLayout.forEach((name, field) {
      datapathJson['control_$name'] = decodeSignal(name, controlWordID);
    });

    // --- Decodificación de las palabras de control del Pipeline ---
    // Se decodifican las señales de control que viajan por el pipeline desde
    // la palabra de control del registro de pipeline correspondiente.
    final int controlWordEX = getValue('Pipe_ID_EX_Control_out');
    final int controlWordWB = getValue('Pipe_MEM_WB_Control_out');

    datapathJson['Pipe_PCsrc']   = decodeSignal('PCsrc', controlWordEX);
    datapathJson['Pipe_BRwr']    = decodeSignal('BRwr', controlWordWB);
    datapathJson['Pipe_ALUsrc']  = decodeSignal('ALUsrc', controlWordEX);
    datapathJson['Pipe_ImmSrc']  = decodeSignal('ImmSrc', controlWordID);
    datapathJson['Pipe_ALUctr']  = decodeSignal('ALUctr', controlWordEX);
    datapathJson['Pipe_MemWr']   = decodeSignal('MemWr', getValue('Pipe_EX_MEM_Control_out'));
    datapathJson['Pipe_ResSrc']  = decodeSignal('ResSrc', getValue('Pipe_MEM_WB_Control_out'));

    datapathJson['control_PCsrc']   = decodeSignal('PCsrc', control);
    datapathJson['control_BRwr']    = decodeSignal('BRwr', control);
    datapathJson['control_ALUsrc']  = decodeSignal('ALUsrc', control);
    datapathJson['control_ImmSrc']  = decodeSignal('ImmSrc', control);
    datapathJson['control_ALUctr']  = decodeSignal('ALUctr', control);
    datapathJson['control_MemWr']   = decodeSignal('MemWr', control);
    datapathJson['control_ResSrc']  = decodeSignal('ResSrc', control);


    // Mapea los nombres de las señales del backend a los nombres de los buses del frontend.
    final Map<String, int> readyAtMap = {
      'pc_bus': getReadyAt('PC'),
      'npc_bus': getReadyAt('PC_plus4'),
      'instruction_bus': getReadyAt('Instr'),
      'control_bus': getReadyAt('Control'),
      'rd1_bus': getReadyAt('A'),
      'rd2_bus': getReadyAt('B'),
      'imm_bus': getReadyAt('imm'),
      'immExt_bus': getReadyAt('immExt'),
      'alu_result_bus': getReadyAt('ALU_result'),
      'flagZ': getReadyAt('ALU_zero'),
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
      'Pipe_IF_ID_Instr_out': getReadyAt('Pipe_IF_ID_Instr_out'),
      'Pipe_IF_ID_NPC': getReadyAt('Pipe_IF_ID_NPC'),
      'Pipe_IF_ID_NPC_out': getReadyAt('Pipe_IF_ID_NPC_out'),
      'Pipe_IF_ID_PC': getReadyAt('Pipe_IF_ID_PC'),
      'Pipe_IF_ID_PC_out': getReadyAt('Pipe_IF_ID_PC_out'),



      // ID/EX Stage
      'Pipe_ID_EX_Control': getReadyAt('Pipe_ID_EX_Control'),
      'Pipe_ID_EX_Control_out': getReadyAt('Pipe_ID_EX_Control_out'),
      'Pipe_ID_EX_NPC': getReadyAt('Pipe_ID_EX_NPC'),
      'Pipe_ID_EX_NPC_out': getReadyAt('Pipe_ID_EX_NPC_out'),
      'Pipe_ID_EX_A': getReadyAt('Pipe_ID_EX_A'),
      'Pipe_ID_EX_A_out': getReadyAt('Pipe_ID_EX_A_out'),
      'Pipe_ID_EX_B': getReadyAt('Pipe_ID_EX_B'),
      'Pipe_ID_EX_B_out': getReadyAt('Pipe_ID_EX_B_out'),
      'Pipe_ID_EX_RD': getReadyAt('Pipe_ID_EX_RD'),
      'Pipe_ID_EX_RD_out': getReadyAt('Pipe_ID_EX_RD_out'),
      'Pipe_ID_EX_Imm': getReadyAt('Pipe_ID_EX_Imm'),
      'Pipe_ID_EX_Imm_out': getReadyAt('Pipe_ID_EX_Imm_out'),
      'Pipe_ID_EX_PC': getReadyAt('Pipe_ID_EX_PC'),
      'Pipe_ID_EX_PC_out': getReadyAt('Pipe_ID_EX_PC_out'),




      // EX/MEM Stage
      'Pipe_EX_MEM_Control': getReadyAt('Pipe_EX_MEM_Control'),
      'Pipe_EX_MEM_Control_out': getReadyAt('Pipe_EX_MEM_Control_out'),
      'Pipe_EX_MEM_NPC': getReadyAt('Pipe_EX_MEM_NPC'),
      'Pipe_EX_MEM_NPC_out': getReadyAt('Pipe_EX_MEM_NPC_out'),
      'Pipe_EX_MEM_ALU_result': getReadyAt('Pipe_EX_MEM_ALU_result'),
      'Pipe_EX_MEM_ALU_result_out': getReadyAt('Pipe_EX_MEM_ALU_result_out'),
      'Pipe_EX_MEM_B': getReadyAt('Pipe_EX_MEM_B'),
      'Pipe_EX_MEM_B_out': getReadyAt('Pipe_EX_MEM_B_out'),
      'Pipe_EX_MEM_RD': getReadyAt('Pipe_EX_MEM_RD'),
      'Pipe_EX_MEM_RD_out': getReadyAt('Pipe_EX_MEM_RD_out'),



      // MEM/WB Stage
      'Pipe_MEM_WB_Control': getReadyAt('Pipe_MEM_WB_Control'),
      'Pipe_MEM_WB_Control_out': getReadyAt('Pipe_MEM_WB_Control_out'),
      'Pipe_MEM_WB_NPC': getReadyAt('Pipe_MEM_WB_NPC'),
      'Pipe_MEM_WB_NPC_out': getReadyAt('Pipe_MEM_WB_NPC_out'),
      'Pipe_MEM_WB_ALU_result': getReadyAt('Pipe_MEM_WB_ALU_result'),
      'Pipe_MEM_WB_ALU_result_out': getReadyAt('Pipe_MEM_WB_ALU_result_out'),
      'Pipe_MEM_WB_RM': getReadyAt('Pipe_MEM_WB_RM'),
      'Pipe_MEM_WB_RM_out': getReadyAt('Pipe_MEM_WB_RM_out'),
      'Pipe_MEM_WB_RD': getReadyAt('Pipe_MEM_WB_RD'),
      'Pipe_MEM_WB_RD_out': getReadyAt('Pipe_MEM_WB_RD_out'),
  
    };

    // Mapea las señales del backend para saber si están lógicamente activas.
    final Map<String, bool> activePathsMap = {
      'pc_bus': getIsActive('PC'),
      'npc_bus': getIsActive('PC_plus4'),
      'instruction_bus': getIsActive('Instr'),
      'rd1_bus': getIsActive('A'),
      'rd2_bus': getIsActive('B'),
      'imm_bus': getIsActive('imm'),
      'immExt_bus': getIsActive('immExt'),
      'alu_result_bus': getIsActive('ALU_result'),
      'branch_target_bus': getIsActive('PC_dest'),
      'mem_read_data_bus': getIsActive('Mem_read_data'),
      'mem_write_data_bus': getIsActive('Mem_write_data'),
      'mux_wb_bus': getIsActive('C'),
      'mux_pc_bus': getIsActive('PC_next'),
      'mux_alu_b_bus': getIsActive('ALU_B'),
      'flagZ': getIsActive('ALU_zero'),
      'da_bus': getIsActive('DA'),
      'db_bus': getIsActive('DB'),
      'dc_bus': getIsActive('DC'),


      // --- Pipeline Registers ---
      // IF/ID Stage
      'Pipe_IF_ID_Instr': getIsActive('Pipe_IF_ID_Instr'),
      'Pipe_IF_ID_Instr_out': getIsActive('Pipe_IF_ID_Instr_out'),
      'Pipe_IF_ID_NPC': getIsActive('Pipe_IF_ID_NPC'),
      'Pipe_IF_ID_NPC_out': getIsActive('Pipe_IF_ID_NPC_out'),
      'Pipe_IF_ID_PC': getIsActive('Pipe_IF_ID_PC'),
      'Pipe_IF_ID_PC_out': getIsActive('Pipe_IF_ID_PC_out'),


      // ID/EX Stage
      'Pipe_ID_EX_Control': getIsActive('Pipe_ID_EX_Control'),
      'Pipe_ID_EX_Control_out': getIsActive('Pipe_ID_EX_Control_out'),
      'Pipe_ID_EX_NPC': getIsActive('Pipe_ID_EX_NPC'),
      'Pipe_ID_EX_NPC_out': getIsActive('Pipe_ID_EX_NPC_out'),
      'Pipe_ID_EX_A': getIsActive('Pipe_ID_EX_A'),
      'Pipe_ID_EX_A_out': getIsActive('Pipe_ID_EX_A_out'),
      'Pipe_ID_EX_B': getIsActive('Pipe_ID_EX_B'),
      'Pipe_ID_EX_B_out': getIsActive('Pipe_ID_EX_B_out'),
      'Pipe_ID_EX_RD': getIsActive('Pipe_ID_EX_RD'),
      'Pipe_ID_EX_RD_out': getIsActive('Pipe_ID_EX_RD_out'),
      'Pipe_ID_EX_Imm': getIsActive('Pipe_ID_EX_Imm'),
      'Pipe_ID_EX_Imm_out': getIsActive('Pipe_ID_EX_Imm_out'),
      'Pipe_ID_EX_PC': getIsActive('Pipe_ID_EX_PC'),
      'Pipe_ID_EX_PC_out': getIsActive('Pipe_ID_EX_PC_out'),



      // EX/MEM Stage
      'Pipe_EX_MEM_Control': getIsActive('Pipe_EX_MEM_Control'),
      'Pipe_EX_MEM_Control_out': getIsActive('Pipe_EX_MEM_Control_out'),
      'Pipe_EX_MEM_NPC': getIsActive('Pipe_EX_MEM_NPC'),
      'Pipe_EX_MEM_NPC_out': getIsActive('Pipe_EX_MEM_NPC_out'),
      'Pipe_EX_MEM_ALU_result': getIsActive('Pipe_EX_MEM_ALU_result'),
      'Pipe_EX_MEM_ALU_result_out': getIsActive('Pipe_EX_MEM_ALU_result_out'),
      'Pipe_EX_MEM_B': getIsActive('Pipe_EX_MEM_B'),
      'Pipe_EX_MEM_B_out': getIsActive('Pipe_EX_MEM_B_out'),
      'Pipe_EX_MEM_RD': getIsActive('Pipe_EX_MEM_RD'),
      'Pipe_EX_MEM_RD_out': getIsActive('Pipe_EX_MEM_RD_out'),



      // MEM/WB Stage
      'Pipe_MEM_WB_Control': getIsActive('Pipe_MEM_WB_Control'),
      'Pipe_MEM_WB_Control_out': getIsActive('Pipe_MEM_WB_Control_out'),
      'Pipe_MEM_WB_NPC': getIsActive('Pipe_MEM_WB_NPC'),
      'Pipe_MEM_WB_NPC_out': getIsActive('Pipe_MEM_WB_NPC_out'),
      'Pipe_MEM_WB_ALU_result': getIsActive('Pipe_MEM_WB_ALU_result'),
      'Pipe_MEM_WB_ALU_result_out': getIsActive('Pipe_MEM_WB_ALU_result_out'),
      'Pipe_MEM_WB_RM': getIsActive('Pipe_MEM_WB_RM'),
      'Pipe_MEM_WB_RM_out': getIsActive('Pipe_MEM_WB_RM_out'),
      'Pipe_MEM_WB_RD': getIsActive('Pipe_MEM_WB_RD'),
      'Pipe_MEM_WB_RD_out': getIsActive('Pipe_MEM_WB_RD_out'),
  
    };

    final Map<String, int> busValuesMap = {
      'pc_bus': getValue('PC'),
      'npc_bus': getValue('PC_plus4'),
      'instruction_bus': getValue('Instr'),
      'rd1_bus': getValue('A'),
      'rd2_bus': getValue('B'),
      'imm_bus': getValue('imm'),
      'immExt_bus': getValue('immExt'),
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
      
      //'control_PCsrc':getValue('PCsrc'),
      //'control_ALUctr':getValue('ALUctr '),
      //'control_ResSrc':getValue('ResSrc'),
      //'control_ImmSrc':getValue('ImmSrc'),

      'opcode': getValue('opcode'),
      'funct3': getValue('funct3'),
      'funct7': getValue('funct7'),
      'flagZ': getValue('ALU_zero'),
      'branch_taken': getValue('branch_taken'),

      'control_PCsrc':datapathJson['control_PCsrc'] as int? ?? 0,
      'control_BRwr':datapathJson['control_BRwr'] as int? ?? 0,
      'control_ALUsrc':datapathJson['control_ALUsrc'] as int? ?? 0,
      'control_MemWr':datapathJson['control_MemWr'] as int? ?? 0,    
      'control_ResSrc':datapathJson['control_ResSrc'] as int? ?? 0,
      'control_ALUctr':datapathJson['control_ALUctr'] as int? ?? 0,
      'control_ImmSrc':datapathJson['control_ImmSrc'] as int? ?? 0,


      'control_bus':getValue('Control'),
      'control_IF':getValue('Control'),
      'control_ID':getValue('Pipe_ID_EX_Control'),
      'control_EX':getValue('Pipe_EX_MEM_Control'),
      'control_MEM':getValue('Pipe_MEM_WB_Control'),
      'control_WB':getValue('Pipe_MEM_WB_Control'),

    

      'Pipe_ImmSrc': datapathJson['Pipe_ImmSrc'] as int? ?? 0,
      'Pipe_ResSrc': datapathJson['Pipe_ResSrc'] as int? ?? 0,
      'Pipe_PCsrc': datapathJson['Pipe_PCsrc'] as int? ?? 0,
      'Pipe_BRwr': datapathJson['Pipe_BRwr'] as int? ?? 0,
      'Pipe_ALUsrc': datapathJson['Pipe_ALUsrc'] as int? ?? 0,
      'Pipe_MemWr': datapathJson['Pipe_MemWr'] as int? ?? 0,
      'Pipe_ALUctr': datapathJson['Pipe_ALUctr'] as int? ?? 0,


      
      // --- Pipeline Registers ---
      // IF/ID Stage
      'Pipe_IF_ID_Instr': getValue('Pipe_IF_ID_Instr'),
      'Pipe_IF_ID_Instr_out': getValue('Pipe_IF_ID_Instr_out'),
      'Pipe_IF_ID_NPC': getValue('Pipe_IF_ID_NPC'),
      'Pipe_IF_ID_NPC_out': getValue('Pipe_IF_ID_NPC_out'),
      'Pipe_IF_ID_PC': getValue('Pipe_IF_ID_PC'),
      'Pipe_IF_ID_PC_out': getValue('Pipe_IF_ID_PC_out'),

      // ID/EX Stage
      'Pipe_ID_EX_Control': getValue('Pipe_ID_EX_Control'),
      'Pipe_ID_EX_Control_out': getValue('Pipe_ID_EX_Control_out'),
      'Pipe_ID_EX_NPC': getValue('Pipe_ID_EX_NPC'),
      'Pipe_ID_EX_NPC_out': getValue('Pipe_ID_EX_NPC_out'),
      'Pipe_ID_EX_A': getValue('Pipe_ID_EX_A'),
      'Pipe_ID_EX_A_out': getValue('Pipe_ID_EX_A_out'),
      'Pipe_ID_EX_B': getValue('Pipe_ID_EX_B'),
      'Pipe_ID_EX_B_out': getValue('Pipe_ID_EX_B_out'),
      'Pipe_ID_EX_RD': getValue('Pipe_ID_EX_RD'),
      'Pipe_ID_EX_RD_out': getValue('Pipe_ID_EX_RD_out'),
      'Pipe_ID_EX_Imm': getValue('Pipe_ID_EX_Imm'),
      'Pipe_ID_EX_Imm_out': getValue('Pipe_ID_EX_Imm_out'),
      'Pipe_ID_EX_PC': getValue('Pipe_ID_EX_PC'),
      'Pipe_ID_EX_PC_out': getValue('Pipe_ID_EX_PC_out'),


      // EX/MEM Stage
      'Pipe_EX_MEM_Control': getValue('Pipe_EX_MEM_Control'),
      'Pipe_EX_MEM_Control_out': getValue('Pipe_EX_MEM_Control_out'),
      'Pipe_EX_MEM_NPC': getValue('Pipe_EX_MEM_NPC'),
      'Pipe_EX_MEM_NPC_out': getValue('Pipe_EX_MEM_NPC_out'),
      'Pipe_EX_MEM_ALU_result': getValue('Pipe_EX_MEM_ALU_result'),
      'Pipe_EX_MEM_ALU_result_out': getValue('Pipe_EX_MEM_ALU_result_out'),


      'Pipe_EX_MEM_B': getValue('Pipe_EX_MEM_B'),
      'Pipe_EX_MEM_B_out': getValue('Pipe_EX_MEM_B_out'),
      'Pipe_EX_MEM_RD': getValue('Pipe_EX_MEM_RD'),
      'Pipe_EX_MEM_RD_out': getValue('Pipe_EX_MEM_RD_out'),


      // MEM/WB Stage
      'Pipe_MEM_WB_Control': getValue('Pipe_MEM_WB_Control'), 
      'Pipe_MEM_WB_Control_out': getValue('Pipe_MEM_WB_Control_out'),
      'Pipe_MEM_WB_NPC': getValue('Pipe_MEM_WB_NPC'),
      'Pipe_MEM_WB_NPC_out': getValue('Pipe_MEM_WB_NPC_out'),
      'Pipe_MEM_WB_ALU_result': getValue('Pipe_MEM_WB_ALU_result'),
      'Pipe_MEM_WB_ALU_result_out': getValue('Pipe_MEM_WB_ALU_result_out'),
      'Pipe_MEM_WB_RM': getValue('Pipe_MEM_WB_RM'),
      'Pipe_MEM_WB_RM_out': getValue('Pipe_MEM_WB_RM_out'),
      'Pipe_MEM_WB_RD': getValue('Pipe_MEM_WB_RD'),
      'Pipe_MEM_WB_RD_out': getValue('Pipe_MEM_WB_RD_out'),

      
      

    };

    // --- Campos para Multiciclo (opcionales) ---
    final int totalMicroCycles = json['totalMicroCycles'] as int? ?? 0;


    return SimulationState(
      // Extrae los nuevos campos del JSON.
      instruction: json['instruction'] as String? ?? '',
      instructionValue: getValue('Instr'),
      criticalTime: json['criticalTime'] as int? ?? 0,
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
      pipeIfInstructionValue: json['Pipe_IF_instruction'] as int? ?? 0,
      pipeIdInstructionValue: json['Pipe_ID_instruction'] as int? ?? 0,
      pipeExInstructionValue: json['Pipe_EX_instruction'] as int? ?? 0,
      pipeMemInstructionValue: json['Pipe_MEM_instruction'] as int? ?? 0,
      pipeWbInstructionValue: json['Pipe_WB_instruction'] as int? ?? 0,
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

    /// Resetea la simulación a su estado inicial.
  Future<SimulationState> getDataMemory();

      /// Resetea la simulación a su estado inicial.
  Future<SimulationState> getInstructionMemory();


}