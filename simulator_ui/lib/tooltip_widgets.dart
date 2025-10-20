//import 'dart:ffi';

import 'package:flutter/material.dart';
import 'package:namer_app/generated/control_table.g.dart';
import 'package:namer_app/simulation_mode.dart';
import 'datapath_state.dart';
import 'dart:typed_data';

final miEstiloTooltip = TextStyle(
  fontFamily: 'RobotoMono',
  fontSize: 12,
  color: Colors.white,
  fontWeight: FontWeight.bold,
  fontFeatures: [const FontFeature.disable('liga')],
);

/// Mapa que contiene las descripciones para los valores de las señales de control.
const Map<String, List<String>> controlSignalOptions = {
  'PCsrc': ['PC+4', 'Branch/JAL Target', 'JALR Target'],
  'ALUsrc': ['Imm extended', 'Rd2 register'],
  'ResSrc': ['Memory read', 'ALU result', 'PC+4'],
  'ImmSrc': ['I-Type', 'S-Type', 'B-Type', 'J-Type', 'U-Type'],
  'MemWr': ['Read', 'Write'],
  'BRwr': ['Disabled', 'Enabled'],
  'ALUctr': [
    'ADD', 'SUB', 'AND', 'OR', 
    'SLT', 'SRL', 'SLL', 'SRA'
  ],
};


Map getSignalValues(DatapathState d) {
  return {'ALUctr':d.busValues['control_ALUctr'],
  'ALUsrc':d.busValues['control_ALUsrc'],
  'BRwr':d.busValues['control_BRwr'],
  'ImmSrc':d.busValues['control_ImmSrc'],
  'MemWr':d.busValues['control_MemWr'],
  'PCsrc':d.busValues['control_PCsrc'],
  'ResSrc':d.busValues['control_ResSrc'],
  };
}

Map getSignalValuesPipe(DatapathState d) {
  return {'ALUctr':d.busValues['Pipe_ALUctr'],
  'ALUsrc':d.busValues['Pipe_ALUsrc'],
  'BRwr':d.busValues['Pipe_BRwr'],
  'ImmSrc':d.busValues['Pipe_ImmSrc'],
  'MemWr':d.busValues['Pipe_MemWr'],
  'PCsrc':d.busValues['Pipe_PCsrc'],
  'ResSrc':d.busValues['Pipe_ResSrc'],
  };
}



// --- Tooltip para el Banco de Registros ---

Widget buildRegisterFileTooltip(DatapathState datapathState) {
  final registers = datapathState.registers;
  final busDa = datapathState.busValues['da_bus'];
  final busDb = datapathState.busValues['db_bus'];
  final busDc = datapathState.busValues['dc_bus'];
  final regWrite = datapathState.busValues['control_BRwr']==1 || datapathState.isPathActive('Pipe_MEM_WB_Control_out');

  List<TextSpan> buildRegisterColumn(int start, int end) {
    List<TextSpan> spans = [];
    for (int i = start; i < end; i++) {
      final value = registers.values.elementAt(i) ;
      final regName = 'x${('$i'.padLeft(2,'0')).padRight(4)}';
      final hexValue = '0x${value.toRadixString(16).padLeft(8, '0').toUpperCase()}';
      
      Color color = Colors.white;
      if (i == busDa) color = Colors.yellow;
      if (i == busDb) color = Colors.lightBlueAccent;
      if (i == busDc && regWrite) color = Colors.redAccent;

      spans.add(TextSpan(
        text: '$regName: $hexValue\n',
        style: miEstiloTooltip.copyWith(color: color),
      ));
    }
    return spans;
  }

  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      RichText(
        text: TextSpan(style: miEstiloTooltip, children: buildRegisterColumn(0, 16)),
      ),
      const SizedBox(width: 16),
      RichText(
        text: TextSpan(style: miEstiloTooltip, children: buildRegisterColumn(16, 32)),
      ),
    ],
  );
}
// --- Tooltip para la Unidad de Control ---

Widget buildControlUnitTooltip(DatapathState datapathState) {
  final simulationMode = datapathState.simulationMode;

  switch (simulationMode) {
    case SimulationMode.singleCycle:
    case SimulationMode.multiCycle:
      return _buildSingleCycleControlTooltip(datapathState);
    case SimulationMode.pipeline:
      return _buildPipelineControlTooltip(datapathState);
    default:
      return const Text('Control Unit');
  }
}

Widget _buildSingleCycleControlTooltip(DatapathState datapathState) {
  final controlWord = datapathState.busValues['control_bus'];

  if (controlWord == null) {
    return const Text('No instruction decoded', style: TextStyle(color: Colors.grey));
  }

  final signals = getSignalValues(datapathState);


  
  final hexWord = '0x${controlWord.toRadixString(16).padLeft(4, '0').toUpperCase()}';

  List<TextSpan> spans = [
    TextSpan(
      text: 'Control Word: $hexWord\n\n',
      style: miEstiloTooltip.copyWith(
        color: Colors.yellow,
        fontWeight: FontWeight.bold,
      ),
    ),
  ];

  signals.forEach((key, value) {
    spans.add(TextSpan(
      text: '${key.padRight(8)}: $value\n',
      style: miEstiloTooltip.copyWith(color: Colors.white),
    ));
  });

  return RichText(text: TextSpan(style: miEstiloTooltip, children: spans));
}

Widget _buildPipelineControlTooltip(DatapathState datapathState) {
  Widget buildStageColumn(String title, String instruction, int? controlWord, List<String> relevantSignals) {
    final instructionName=instruction.padRight(20);
    
    final String controlWordName = '0x${controlWord != null?controlWord.toRadixString(16).padLeft(4, '0').toUpperCase():''}';

    List<TextSpan> spans = [
      TextSpan(
        text: '$title\n',
        style: miEstiloTooltip.copyWith(color: Colors.yellow, fontWeight: FontWeight.bold),
      ),
      TextSpan(
        text: '$instructionName\n----------------\n',
        style: miEstiloTooltip.copyWith(color: Colors.cyan),
      ),
      TextSpan(
        text: '$controlWordName\n----------------\n',
        style: miEstiloTooltip.copyWith(color: Colors.cyan),
      ),
    ];

    if (controlWord != null && instruction != 'nop') {
      final signals = getSignalValuesPipe(datapathState);
      for (var key in relevantSignals) {
        spans.add(TextSpan(
          text: '${key.padRight(8)}: ${signals[key]}\n',
          style: miEstiloTooltip.copyWith(color: Colors.white),
        ));
      }
    } else {
       spans.add(TextSpan(
        text: '(bubble)',
        style: miEstiloTooltip.copyWith(color: Colors.grey, fontStyle: FontStyle.italic),
      ));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: RichText(text: TextSpan(style: miEstiloTooltip, children: spans)),
    );
  }

  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // IF Stage
      buildStageColumn('IF',datapathState.pipeIfInstruction ,datapathState.busValues['control_bus'] , []),

      // ID Stage
      buildStageColumn(
        'ID',
        datapathState.pipeIdInstruction,
        datapathState.busValues['Pipe_ID_EX_Control'],
        ['ImmSrc'],
      ),

      // EX Stage
      buildStageColumn(
        'EX',
        datapathState.pipeExInstruction,
        datapathState.busValues['Pipe_ID_EX_Control_out'],
        ['ALUsrc', 'ALUctr', 'PCsrc'],
      ),

      // MEM Stage
      buildStageColumn(
        'MEM',
        datapathState.pipeMemInstruction,
        datapathState.busValues['Pipe_EX_MEM_Control_out'],
        ['MemWr',],
      ),

      // WB Stage
      buildStageColumn(
        'WB',
        datapathState.pipeWbInstruction,
        datapathState.busValues['Pipe_MEM_WB_Control_out'],
        ['ResSrc', 'BRwr'],
      ),
    ],
  );
}
// --- Tooltip para la Memoria de Instrucciones ---

Widget buildInstructionMemoryTooltip(DatapathState datapathState) {
  final instructionMemory = datapathState.instructionMemory;
  final pc = datapathState.busValues['pc_bus'];//Pc ya está actualizado
  
  if (instructionMemory==null||instructionMemory.isEmpty) {
    return const Text('(Memory is empty)', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic));
  }

  List<TextSpan> buildInstructionColumn(int start, int end) {
    List<TextSpan> spans = [];
    //spans.add( TextSpan( text: 'Address   Instr (Hex)   Assembly\n',style: miEstiloTooltip.copyWith(color: Colors.white, fontWeight: FontWeight.bold),));
    //spans.add( TextSpan( text: '----------------------------------------\n',style: miEstiloTooltip.copyWith(color: Colors.white),));

    for (int i = start; i < end; i += 4) {
      // Asegurarnos de no leer fuera de los límites
      if ((i ~/ 4) >= instructionMemory.length) continue;

      final address = i;
      final item = instructionMemory[address ~/ 4] ;
      final realaddress = i+ datapathState.initial_pc;
      final hexAddress = '0x${realaddress.toRadixString(16).padLeft(4, '0').toUpperCase()}';
      final hexInstruction = '0x${item.value.toRadixString(16).padLeft(8, '0').toUpperCase()}';
      final assembly = item.instruction.padRight(10);

      Color color = Colors.white;
      if (address == pc) {
        color = Colors.yellow; // Resaltar la instrucción actual
      }

      spans.add(TextSpan(
        text: '$hexAddress: $hexInstruction  $assembly\n',
        style: miEstiloTooltip.copyWith(color: color),
      ));
    }
    return spans;
  }

  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      RichText(
          text:
              TextSpan(style: miEstiloTooltip, children: buildInstructionColumn(0, 128))),
      const SizedBox(width: 16),
      RichText(
          text: TextSpan(
              style: miEstiloTooltip, children: buildInstructionColumn(128, 256))),
    ],
  );
}

// --- Tooltip para la Memoria de Datos ---

Widget buildDataMemoryTooltip(DatapathState datapathState) {
  final dataMemory = datapathState.dataMemory;
  final noPipeline=datapathState.simulationMode != SimulationMode.pipeline;
  final addressBus = noPipeline?(datapathState.busValues['alu_result_bus'] ??0): datapathState.busValues['Pipe_EX_MEM_ALU_result_out'];
  // Determina si la instrucción en la etapa MEM es un 'load'.
  // Un 'load' tiene ResSrc = 0 en la palabra de control de la etapa de memoria.
  final memWrite = datapathState.busValues['control_MemWr']==1 || datapathState.busValues['Pipe_MemWr']==1;
  final memRead = (datapathState.busValues['control_ResSrc']==0 && noPipeline )|| datapathState.busValues['Pipe_Mem_ResSrc']==0;

  if (dataMemory == null || dataMemory.isEmpty) {
    return const Text('(Memory is empty)', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic));
  }

  List<TextSpan> buildDataColumn(int start, int end) {
    List<TextSpan> spans = [];
    spans.add( TextSpan(
      text: 'Address   Value\n',
      style: miEstiloTooltip.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
    ));
    spans.add( TextSpan(
      text: '---------------------\n',
      style: miEstiloTooltip.copyWith(color: Colors.white),
    ));

    // Iteramos sobre las direcciones de memoria que queremos mostrar
    for (int i = start; i < end; i += 4) {
      final address = i;
      // Asegurarnos de no leer fuera de los límites del buffer
      if (address + 4 > dataMemory.lengthInBytes) continue;

      // Leemos una palabra de 32-bit (4 bytes)
      final byteData = dataMemory.buffer.asByteData();
      // Usamos Endian.little, ajústalo si tu simulador usa big-endian
      final value = byteData.getUint32(address, Endian.little);

      final hexAddress = '0x${address.toRadixString(16).padLeft(4, '0').toUpperCase()}';
      final hexValue = '0x${value.toRadixString(16).padLeft(8, '0').toUpperCase()}';
      Color color = Colors.white;
      if (address == addressBus) {
        if (memWrite) {
          color = Colors.redAccent; // Resaltar la escritura
        } else if (memRead) {
          color = Colors.lightBlueAccent; // Resaltar la lectura
        }
      }

      spans.add(TextSpan(
        text: '$hexAddress: $hexValue\n',
        style: miEstiloTooltip.copyWith(color: color),
      ));
    }
    return spans;
  }

  final column1Spans = buildDataColumn(0, 128);
  final column2Spans = buildDataColumn(128, 256);

  if (column1Spans.length <= 2 && column2Spans.length <= 2) {
    column1Spans.add( TextSpan(
        text: '\n(Memory is empty in this range)',
        style: miEstiloTooltip.copyWith(color: Colors.grey, fontStyle: FontStyle.italic)));
    return RichText(text: TextSpan(style: miEstiloTooltip, children: column1Spans));
  }

  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      RichText(text: TextSpan(style: miEstiloTooltip, children: column1Spans)),
      const SizedBox(width: 16),
      RichText(text: TextSpan(style: miEstiloTooltip, children: column2Spans)),
    ],
  );
}


// --- Helpers para Tooltips de Muxes ---

TextSpan _buildMuxInputLine(String text, bool isSelected, {bool isLast = false}) {
  final selectedStyle = miEstiloTooltip.copyWith(color: Colors.cyan);
  final defaultStyle = miEstiloTooltip.copyWith(color: Colors.white);

  return TextSpan(
    children: [
      TextSpan(
        text: isSelected ? '> ' : '  ',
        style: isSelected ? selectedStyle : defaultStyle,
      ),
      TextSpan(
        text: text + (isLast ? '' : '\n'),
        style: isSelected ? selectedStyle : defaultStyle,
      ),
    ],
  );
}

// --- Tooltip para el Mux del PC ---

Widget buildMuxPcTooltip(DatapathState datapathState) {
  final valor = datapathState.busValues['control_PCsrc'] ?? 0;
  final taken = datapathState.busValues['branch_taken'] ?? 0;

  final isSequential = valor == 0 || (valor == 1 && taken == 0);
  final isBranchOrJal = valor == 1 && taken == 1;
  final isJalr = valor == 2;

  String? val0=toHex(datapathState.busValues['npc_bus']);
  String? val1=toHex(datapathState.busValues['branch_target_bus']);
  String? val2=toHex(datapathState.busValues['alu_result_bus']);


  return RichText(
    text: TextSpan(
      style: miEstiloTooltip,
      children: [
        TextSpan(
          text: 'MuxPC - Next PC Source\n',
          style: miEstiloTooltip.copyWith(fontWeight: FontWeight.bold, color: Colors.yellow),
        ),
        _buildMuxInputLine('PC + 4:   $val0 (Sequential, not taken branch)', isSequential),
        _buildMuxInputLine('PC + Imm: $val1 (Taken branch/JAL)', isBranchOrJal),
        _buildMuxInputLine('RG + Imm: $val2 (JALR)', isJalr, isLast: true),
      ],
    ),
  );
}

// --- Tooltip para el Mux C (escritura en registros) ---

Widget buildMuxCTooltip(DatapathState datapathState) {
  bool isPipelineMode = datapathState.simulationMode == SimulationMode.pipeline;
  bool isMultiCycleMode = datapathState.simulationMode == SimulationMode.multiCycle;
  final selector =  !isPipelineMode?datapathState.busValues['control_ResSrc']:datapathState.busValues['Pipe_ResSrc'];

  int? val0=datapathState.busValues['mem_read_data_bus'];
  int? val1=datapathState.busValues['alu_result_bus'];
  int? val2=datapathState.busValues['npc_bus'];
  
  if(isPipelineMode)
  {
   val0=datapathState.busValues['Pipe_MEM_WB_RM_out'];
   val1=datapathState.busValues['Pipe_MEM_WB_result_out'];
   val2=datapathState.busValues['Pipe_MEM_WB_NPC_out'];
  
  }
  if(isMultiCycleMode)
  {
   val0=datapathState.busValues['Pipe_MEM_WB_RM_out'];
   val1=datapathState.busValues['Pipe_MEM_WB_result_out'];
  }
  
  
  datapathState.busValues['Pipe_EX_MEM_ALU_result_out']?.toRadixString(16).padLeft(8, '0').toUpperCase();

  return RichText(
    text: TextSpan(
      style: miEstiloTooltip,
      children: [
        TextSpan(
          text: 'MuxC - WriteBack source\n',
          style: miEstiloTooltip.copyWith(fontWeight: FontWeight.bold, color: Colors.yellow),
        ),
        _buildMuxInputLine('PC + 4     : ${toHex(val2)} ', selector == 2),
        _buildMuxInputLine('ALU result : ${toHex(val1)}', selector == 1),
        _buildMuxInputLine('Memory read: ${toHex(val0)}', selector == 0),
        _buildMuxInputLine('Unused:      ${toHex(indeterminado)}', selector == 3, isLast: true),
      ],
    ),
  );
}

// --- Tooltip para el Mux B (operando B del ALU) ---

Widget buildMuxBTooltip(DatapathState datapathState) {
  bool isPipelineMode = datapathState.simulationMode == SimulationMode.pipeline;
  bool isSingleCycleMode = datapathState.simulationMode == SimulationMode.singleCycle;

  final selector =  !isPipelineMode?datapathState.busValues['control_ALUsrc']:datapathState.busValues['Pipe_ALUsrc'];
  String val0=toHex(datapathState.busValues['immExt_bus']);
  String val1=toHex(datapathState.busValues['rd2_bus']);
  if(!isSingleCycleMode){
    val0=toHex(datapathState.busValues['Pipe_ID_EX_Imm_out']);
    val1=toHex(datapathState.busValues['Pipe_ID_EX_B_out']);
  }

  return RichText(
    text: TextSpan(
      style: miEstiloTooltip,
      children: [
        TextSpan(
          text: 'MuxB - ALU B source\n',
          style: miEstiloTooltip.copyWith(fontWeight: FontWeight.bold, color: Colors.yellow),
        ),
        _buildMuxInputLine('Rd2 register: $val1', selector == 1),
        _buildMuxInputLine('Imm extended: $val0', selector == 0, isLast: true),
      ],
    ),
  );
}

Widget buildBranchTooltip(DatapathState datapathState)
{
  bool isPipelineMode = datapathState.simulationMode == SimulationMode.pipeline;
  bool isSingleCycleMode = datapathState.simulationMode == SimulationMode.singleCycle;

  final op1=isSingleCycleMode?datapathState.busValues['immExt_bus']:datapathState.busValues['Pipe_ID_EX_Imm_out'];
  final op2=isPipelineMode?datapathState.busValues['pc_bus']:datapathState.busValues['Pipe_ID_EX_PC_out'];
  final res=op1!+op2!;
  return RichText(
    text: TextSpan(
      style: miEstiloTooltip,
      children: [
        TextSpan(
          text: 'Branch target adder',
          style: miEstiloTooltip.copyWith(fontWeight: FontWeight.bold, color: Colors.yellow),
        ),
        TextSpan(
          text: '\n\nOp1: ${toHex(op1)} ($op1, immediate)',
          style: miEstiloTooltip,
        ),
        TextSpan(
          text: '\nOp2: ${toHex(op2)} ($op2, PC)',
          style: miEstiloTooltip,
        ),
        TextSpan(
          text: '\n\nRes: ${toHex(res)} ($res)',
          style: miEstiloTooltip,
        ),
      ],  
    ),
  );
}



Widget buildImmTooltip(DatapathState datapathState)
{
  final int? entrada = datapathState.busValues['imm_bus'];
  final int? salidaDesdeBackend = datapathState.busValues['immExt_bus'];
  final InstructionInfo info = (datapathState.simulationMode==SimulationMode.pipeline)?datapathState.pipeIdInstructionInfo:datapathState.instructionInfo;
  
  if (entrada == null || salidaDesdeBackend == null) {
    return const Text('Waiting for data...', style: TextStyle(color: Colors.grey));
  }
  
  final spans = <TextSpan>[];
  int calculatedSalida = 0;

  // Define colors for different parts of the immediate
  final immColor1 = Colors.cyan;
  final immColor2 = Colors.greenAccent;
  final immColor3 = Colors.orange;
  final immColor4 = Colors.purpleAccent;

  Map<int, Color> instructionColorMap = {};
  Map<int, Color> resultColorMap = {};
  int resultTotalBits = 0;
  String typeName = '';
  
  switch (info.type) {
    case 'I':
      typeName = 'I-Type Immediate';
      // Instruction: imm[11:0] is at bits 31:20
      for (int i = 20; i <= 31; i++) { instructionColorMap[i] = immColor1; }
      // Result: imm[11:0] is at bits 11:0
      for (int i = 0; i <= 11; i++) { resultColorMap[i] = immColor1; }
      resultTotalBits = 12;
      calculatedSalida = (entrada >> 20).toSigned(12);
      break;
    case 'S':
      typeName = 'S-Type Immediate';
      // Instruction: imm[11:5] at 31:25, imm[4:0] at 11:7
      for (int i = 25; i <= 31; i++) { instructionColorMap[i] = immColor1; } // imm[11:5]
      for (int i = 7; i <= 11; i++) { instructionColorMap[i] = immColor2; } // imm[4:0]
      // Result: imm[11:5] at 11:5, imm[4:0] at 4:0
      for (int i = 5; i <= 11; i++) { resultColorMap[i] = immColor1; }
      for (int i = 0; i <= 4; i++) { resultColorMap[i] = immColor2; }
      resultTotalBits = 12;
      calculatedSalida = (((entrada >> 25) & 0x7F) << 5 | ((entrada >> 7) & 0x1F)).toSigned(12);
      break;
    case 'B':
      typeName = 'B-Type Immediate';
      // Instruction: imm[12] at 31, imm[11] at 7, imm[10:5] at 30:25, imm[4:1] at 11:8
      instructionColorMap[31] = immColor1; // imm[12]
      instructionColorMap[7] = immColor2;  // imm[11]
      for (int i = 25; i <= 30; i++) { instructionColorMap[i] = immColor3; } // imm[10:5]
      for (int i = 8; i <= 11; i++) { instructionColorMap[i] = immColor4; } // imm[4:1]
      // Result: imm[12] at 12, imm[11] at 11, imm[10:5] at 10:5, imm[4:1] at 4:1
      resultColorMap[12] = immColor1;
      resultColorMap[11] = immColor2;
      for (int i = 5; i <= 10; i++) { resultColorMap[i] = immColor3; }
      for (int i = 1; i <= 4; i++) { resultColorMap[i] = immColor4; }
      resultTotalBits = 13;
      calculatedSalida = (((entrada >> 31) & 1) << 12 | ((entrada >> 7) & 1) << 11 | ((entrada >> 25) & 0x3F) << 5 | ((entrada >> 8) & 0xF) << 1).toSigned(13);
      break;
    case 'J':
      typeName = 'J-Type Immediate';
      // Instruction: imm[20] at 31, imm[10:1] at 30:21, imm[11] at 20, imm[19:12] at 19:12
      instructionColorMap[31] = immColor1; // imm[20]
      for (int i = 21; i <= 30; i++) { instructionColorMap[i] = immColor2; } // imm[10:1]
      instructionColorMap[20] = immColor3; // imm[11]
      for (int i = 12; i <= 19; i++) { instructionColorMap[i] = immColor4; } // imm[19:12]
      // Result: imm[20] at 20, imm[10:1] at 10:1, imm[11] at 11, imm[19:12] at 19:12
      resultColorMap[20] = immColor1;
      for (int i = 1; i <= 10; i++) { resultColorMap[i] = immColor2; }
      resultColorMap[11] = immColor3;
      for (int i = 12; i <= 19; i++) { resultColorMap[i] = immColor4; }
      resultTotalBits = 21;
      calculatedSalida = (((entrada >> 31) & 1) << 20 | ((entrada >> 12) & 0xFF) << 12 | ((entrada >> 20) & 1) << 11 | ((entrada >> 21) & 0x3FF) << 1).toSigned(21);
      break;
    case 'U':
      typeName = 'U-Type Immediate';
      // Instruction: imm[31:12] at 31:12
      for (int i = 12; i <= 31; i++) { instructionColorMap[i] = immColor1; }
      // Result: imm[31:12] at 31:12
      for (int i = 12; i <= 31; i++) { resultColorMap[i] = immColor1; }
      resultTotalBits = 32;
      calculatedSalida = entrada & 0xFFFFF000;
      break;
    default:
      return Text('Unknown instruction type: ${info.type}', style: miEstiloTooltip);
  }
  
  // Comprobación para detectar bugs entre frontend y backend.
  // Comparamos los valores como si fueran enteros de 32 bits sin signo
  // para manejar correctamente los números negativos, que el backend envía como
  // uint32_t y el frontend calcula como int con signo.
  assert((calculatedSalida & 0xFFFFFFFF) == (salidaDesdeBackend & 0xFFFFFFFF),
      'Immediate calculation mismatch! UI: ${toHex(calculatedSalida)}, Backend: ${toHex(salidaDesdeBackend)} for instruction ${toHex(entrada)}');
  
  spans.add(TextSpan(
    text: '$typeName (${info.instr})\n\n',
    style: miEstiloTooltip.copyWith(fontWeight: FontWeight.bold, color: Colors.yellow),
  ));
  
  spans.add(_buildBinaryRepresentation('Instruction:', entrada, 32, instructionColorMap));
  spans.add(_buildBinaryRepresentation('Result:', salidaDesdeBackend, resultTotalBits, resultColorMap));
  
  return RichText(text: TextSpan(style: miEstiloTooltip, children: spans));
}


Widget buildAluTooltip(DatapathState datapathState)
{
    bool isPipelineMode = datapathState.simulationMode == SimulationMode.pipeline;
  bool isSingleCycleMode = datapathState.simulationMode == SimulationMode.singleCycle;

  final op1=isSingleCycleMode?datapathState.busValues['rd1_bus']:datapathState.busValues['Pipe_ID_EX_A_out'];
  final op2=datapathState.busValues['mux_alu_b_bus'];
  final res=datapathState.busValues['alu_result_bus'];
  final rg=datapathState.busValues['da_bus'];
  final op=!isPipelineMode?datapathState.busValues['control_ALUctr']:datapathState.busValues['Pipe_ALUctr'];
  final ops=['add','sub','and','or','slt','srl','sll','sra'];

  return RichText(
    text: TextSpan(
      style: miEstiloTooltip,
      children: [
        TextSpan(
          text: 'Arithmetic-Logic Unit (ALU) as ${ops[op!]}\n',
          style: miEstiloTooltip.copyWith(fontWeight: FontWeight.bold, color: Colors.yellow),
        ),
        TextSpan(
          text: '\n\nOp1: ${toHex(op1)} ($op1)',
          style: miEstiloTooltip,
        ),
        TextSpan(
          text: '\nOp2: ${toHex(op2)} ($op2)',
          style: miEstiloTooltip,
        ),
        TextSpan(
          text: '\n\nRes: ${toHex(res)} ($res)',
          style: miEstiloTooltip,
        ),
      ],  
    ),
  );
}

Widget buildPcAdderTooltip(DatapathState datapathState)
{
  return RichText(
    text: TextSpan(
      style: miEstiloTooltip,
      children: [
        TextSpan(
          text: 'NPC\n\n',
          style: miEstiloTooltip.copyWith(fontWeight: FontWeight.bold, color: Colors.yellow),
        ),
        TextSpan(
          text: '${toHex(datapathState.busValues['pc_bus'])} + 4 = \n${toHex(datapathState.busValues['npc_bus'])}'
        ),
      ],  
    ),
  );
}

Widget buildControlBusTooltip(DatapathState datapathState, String signalKey) {
  try {
    // Normalizamos el nombre de la señal para que coincida con las claves de `controlSignalOptions`
    final signalName = signalKey.replaceFirst('control_', '').replaceFirst('Pipe_', '');
    final options = controlSignalOptions[signalName]; // Usamos el mapa correcto
    var currentValue = datapathState.busValues[signalKey];

    if(signalKey=="Pipe_ID_EX_Control")
     {
      currentValue=datapathState.busValues["Pipe_ID_EX_Control"];
      final hexValue = toHex(currentValue, 4); // Formateamos a 4 dígitos hexadecimales
      return Text(
        '$signalKey: $hexValue ($currentValue)', // Mostramos ambos formatos
        style: miEstiloTooltip.copyWith(color: Colors.cyan), // Usamos un color para destacarlo
      );
    }

    if(signalKey=="Pipe_ID_EX_Control_out")
     {
      currentValue=datapathState.busValues["Pipe_ID_EX_Control_out"];
      final hexValue = toHex(currentValue, 4); // Formateamos a 4 dígitos hexadecimales
      return Text(
        '$signalKey: $hexValue ($currentValue)', // Mostramos ambos formatos
        style: miEstiloTooltip.copyWith(color: Colors.cyan), // Usamos un color para destacarlo
      );
    }

    if(signalKey=="Pipe_EX_MEM_Control_out")
     {
      currentValue=datapathState.busValues["Pipe_EX_MEM_Control_out"];
      final hexValue = toHex(currentValue, 4); // Formateamos a 4 dígitos hexadecimales
      return Text(
        '$signalKey: $hexValue ($currentValue)', // Mostramos ambos formatos
        style: miEstiloTooltip.copyWith(color: Colors.cyan), // Usamos un color para destacarlo
      );
    }

    if(signalKey=="Pipe_MEM_WB_Control_out")
     {
      currentValue=datapathState.busValues["Pipe_MEM_WB_Control_out"];
      final hexValue = toHex(currentValue, 4); // Formateamos a 4 dígitos hexadecimales
      return Text(
        '$signalKey: $hexValue ($currentValue)', // Mostramos ambos formatos
        style: miEstiloTooltip.copyWith(color: Colors.cyan), // Usamos un color para destacarlo
      );
    }


    if (options == null || currentValue != null) {
      return Text(
        '$signalKey: $currentValue',
        style: miEstiloTooltip,
      );
    }

    if (currentValue == null) {
      return Text(
        '$signalKey: N/A (options: ${options == null}, value: ${currentValue == null})',
        style: miEstiloTooltip,
      );
    }

    final spans = <TextSpan>[];
    spans.add(TextSpan(
      text: '$signalKey\n',
      style: miEstiloTooltip.copyWith(fontWeight: FontWeight.bold, color: Colors.yellow),
    ));

    for (int i = 0; i < options.length; i++) {
      final optionText = options[i];
      final isSelected = (i == currentValue);
      // El ancho del valor binario debe depender del número de opciones
      final bitWidth = (options.length - 1).toRadixString(2).length;
      final valueStr = i.toRadixString(2).padLeft(bitWidth, '0');

      final selectedStyle = miEstiloTooltip.copyWith(color: Colors.cyan, fontWeight: FontWeight.bold);
      final defaultStyle = miEstiloTooltip.copyWith(color: Colors.white.withAlpha(200));

      spans.add(
        TextSpan(
          children: [
            TextSpan(
              text: isSelected ? '* ' : '  ',
              style: isSelected ? selectedStyle : defaultStyle,
            ),
            TextSpan(
              text: '$valueStr  $optionText\n',
              style: isSelected ? selectedStyle : defaultStyle,
            ),
          ],
        ),
      );
    }

    return RichText(text: TextSpan(children: spans));
  } catch (e) {
    return Text('Error building tooltip for $signalKey:\n$e', style: miEstiloTooltip.copyWith(color: Colors.redAccent));
  }
}

Widget buildInstructionFormatTooltip() {
  // Reutiliza la clase _Field que ya existe en este fichero.
  return Container(
    padding: const EdgeInsets.all(12.0),
    constraints: const BoxConstraints(maxWidth: 700),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Formatos de Instrucción RISC-V (RV32I)', style: miEstiloTooltip.copyWith(color: Colors.yellow, fontSize: 14)),
        const SizedBox(height: 12),
        _buildFormatTable(
          title: 'Formato R (Register)',
          fields:  [
            _Field('funct7', 25, 31, Colors.purple),
            _Field('rs2', 20, 24, Colors.orange),
            _Field('rs1', 15, 19, Colors.orange),
            _Field('funct3', 12, 14, Colors.red),
            _Field('rd', 7, 11, Colors.yellow),
            _Field('opcode', 0, 6, Colors.redAccent),
          ],
        ),
        const Divider(height: 16, color: Colors.grey),
        _buildFormatTable(
          title: 'Formato I (Immediate)',
          fields:  [
            _Field('imm[11:0]', 20, 31, Colors.cyan),
            _Field('rs1', 15, 19, Colors.orange),
            _Field('funct3', 12, 14, Colors.red),
            _Field('rd', 7, 11, Colors.yellow),
            _Field('opcode', 0, 6, Colors.redAccent),
          ],
        ),
        const Divider(height: 16, color: Colors.grey),
        _buildFormatTable(
          title: 'Formato S (Store)',
          fields:  [
            _Field('imm[11:5]', 25, 31, Colors.cyan),
            _Field('rs2', 20, 24, Colors.orange),
            _Field('rs1', 15, 19, Colors.orange),
            _Field('funct3', 12, 14, Colors.red),
            _Field('imm[4:0]', 7, 11, Colors.cyan),
            _Field('opcode', 0, 6, Colors.redAccent),
          ],
        ),
        const Divider(height: 16, color: Colors.grey),
        _buildFormatTable(
          title: 'Formato B (Branch)',
          fields:  [
            _Field('12', 31, 31, Colors.cyan),
            _Field('imm[10:5]', 25, 30, Colors.cyan),
            _Field('rs2', 20, 24, Colors.orange),
            _Field('rs1', 15, 19, Colors.orange),
            _Field('funct3', 12, 14, Colors.red),
            _Field('imm[4:1]', 8, 11, Colors.cyan),
            _Field('11', 7, 7, Colors.cyan),
            _Field('opcode', 0, 6, Colors.redAccent),
          ],
        ),
        const Divider(height: 16, color: Colors.grey),
        _buildFormatTable(
          title: 'Formato U (Upper Immediate)',
          fields:  [
            _Field('imm[31:12]', 12, 31, Colors.cyan),
            _Field('rd', 7, 11, Colors.yellow),
            _Field('opcode', 0, 6, Colors.redAccent),
          ],
        ),
        const Divider(height: 16, color: Colors.grey),
        _buildFormatTable(
          title: 'Formato J (Jump)',
          fields:  [
            _Field('20', 31, 31, Colors.cyan),
            _Field('imm[10:1]', 21, 30, Colors.cyan),
            _Field('11', 20, 20, Colors.cyan),
            _Field('imm[19:12]', 12, 19, Colors.cyan),
            _Field('rd', 7, 11, Colors.yellow),
            _Field('opcode', 0, 6, Colors.redAccent),
          ],
        ),
      ],
    ),
  );
}

Widget _buildFormatTable({required String title, required List<_Field> fields}) {
  final headerStyle = miEstiloTooltip.copyWith(fontSize: 10, color: Colors.grey[400]);
  final titleStyle = miEstiloTooltip.copyWith(fontWeight: FontWeight.bold);
  fields.sort((a, b) => b.start.compareTo(a.start));
  List<Widget> headerWidgets = fields.map((field) => Expanded(flex: field.width, child: Text((field.start == field.end) ? '${field.start}' : '${field.end}:${field.start}', style: headerStyle, textAlign: TextAlign.center))).toList();
  List<Widget> cellWidgets = fields.map((field) => Expanded(flex: field.width, child: Container(margin: const EdgeInsets.symmetric(horizontal: 1), padding: const EdgeInsets.symmetric(vertical: 2), decoration: BoxDecoration(color: field.color.withAlpha(50), border: Border.all(color: field.color), borderRadius: BorderRadius.circular(2)), child: Text(field.name, style: miEstiloTooltip.copyWith(color: field.color, fontSize: 11), textAlign: TextAlign.center)))).toList();
  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: titleStyle), const SizedBox(height: 4), Row(children: headerWidgets), const SizedBox(height: 2), Row(children: cellWidgets)]);
}

/// Construye un [TextSpan] que representa un valor binario de 32 bits,
/// resaltando los rangos de bits especificados.
TextSpan _buildBinaryRepresentation(String title, int value, int totalBits, Map<int, Color> colorMap) {
  final binaryString = (value & 0xFFFFFFFF).toRadixString(2).padLeft(32, '0');
  final relevantBinaryString = binaryString.substring(32 - totalBits);
  final spans = <TextSpan>[];

  final defaultColor = Colors.grey.withAlpha(130);

  int lastIndex = 0;
  Color currentColor = colorMap[totalBits - 1] ?? defaultColor;

  for (int i = 0; i < totalBits; i++) {
    final bitIndex = totalBits - 1 - i;
    final Color nextColor = colorMap[bitIndex] ?? defaultColor;
    if (nextColor != currentColor) {
      spans.add(TextSpan(
        text: relevantBinaryString.substring(lastIndex, i),
        style: miEstiloTooltip.copyWith(color: currentColor),
      ));
      lastIndex = i;
      currentColor = nextColor;
    }
  }

  spans.add(TextSpan(
    text: relevantBinaryString.substring(lastIndex),
    style: miEstiloTooltip.copyWith(color: currentColor),
  ));

  return TextSpan(children: [
    TextSpan(text: '$title\n', style: miEstiloTooltip.copyWith(fontWeight: FontWeight.bold)),
    ...spans,
    TextSpan(text: '\n\n'),
  ]);
}


Widget buildControlTableTooltip() {
  final headerStyle = miEstiloTooltip.copyWith(color: Colors.yellow, fontWeight: FontWeight.bold);
  final instrStyle = miEstiloTooltip.copyWith(color: Colors.cyan);
  final valueStyle = miEstiloTooltip;

  // Extraer el layout de la palabra de control y ordenarlo por posición de bit.
  final controlFields = controlWordLayout.entries.toList()
    ..sort((a, b) => b.value.position.compareTo(a.value.position));

  // Crear las cabeceras de la tabla
  List<TableCell> headers = [
    TableCell(child: Padding(padding: const EdgeInsets.all(4.0), child: Text('Instruction', style: headerStyle))),
    TableCell(child: Padding(padding: const EdgeInsets.all(4.0), child: Text('Opcode', style: headerStyle))),
    TableCell(child: Padding(padding: const EdgeInsets.all(4.0), child: Text('Funct3', style: headerStyle))),
    TableCell(child: Padding(padding: const EdgeInsets.all(4.0), child: Text('Funct7', style: headerStyle))),
  ];

  // Añadir cabeceras para cada señal de control
  int currentBit = 15; // Asumimos una palabra de control de 16 bits, empezamos por el MSB
  for (var field in controlFields) {
    final signalInfo = field.value;
    final signalEndBit = signalInfo.position + signalInfo.width - 1;

    // Comprobar si hay un hueco entre el bit actual y el final de esta señal
    if (currentBit > signalEndBit) {
      int gapWidth = currentBit - signalEndBit;
      headers.add(TableCell(child: Padding(padding: const EdgeInsets.all(4.0), child: Text('Unused', style: headerStyle.copyWith(color: Colors.grey)))));
    }

    // Añadir la cabecera de la señal de control
    headers.add(TableCell(child: Padding(padding: const EdgeInsets.all(4.0), child: Text(field.key, style: headerStyle))));

    // Actualizar el bit actual a la posición justo debajo de la señal actual
    currentBit = signalInfo.position - 1;
  }
  // Comprobar si queda algún hueco al final (LSB)
  if (currentBit >= 0) {
    headers.add(TableCell(child: Padding(padding: const EdgeInsets.all(4.0), child: Text('Unused', style: headerStyle.copyWith(color: Colors.grey)))));
  }

  headers.add(TableCell(child: Padding(padding: const EdgeInsets.all(4.0), child: Text('Control Word', style: headerStyle))));

  // Crear las filas de la tabla
  List<TableRow> rows = [TableRow(children: headers)];

  for (var instrInfo in controlTable) {
    List<TableCell> cells = [];

    // Función para extraer campos de la instrucción
    String getField(String fieldName, int fullMask, int shift) {
      // Usamos la máscara completa de la instrucción para ver si el campo es relevante.
      // Si el campo no está en la máscara, no se aplica.
      if ((instrInfo.mask & fullMask) == 0) return '-';
      return '0x${((instrInfo.value & fullMask) >> shift).toRadixString(16)}';
    }

    // Mnemónico
    cells.add(TableCell(child: Padding(padding: const EdgeInsets.all(4.0), child: Text(instrInfo.instr, style: instrStyle))));
    
    // Opcode, Funct3, Funct7
    cells.add(TableCell(child: Padding(padding: const EdgeInsets.all(4.0), child: Text(getField('opcode', 0x7F, 0), style: valueStyle, textAlign: TextAlign.center))));
    cells.add(TableCell(child: Padding(padding: const EdgeInsets.all(4.0), child: Text(getField('funct3', 0x7000, 12), style: valueStyle, textAlign: TextAlign.center))));
    cells.add(TableCell(child: Padding(padding: const EdgeInsets.all(4.0), child: Text(getField('funct7', 0xFE000000, 25), style: valueStyle, textAlign: TextAlign.center))));

    // Añadir valores para las señales de control y los huecos
    currentBit = 15;
    for (var field in controlFields) {
      final signalInfo = field.value;
      final signalEndBit = signalInfo.position + signalInfo.width - 1;

      // Rellenar el hueco con ceros si existe
      if (currentBit > signalEndBit) {
        int gapWidth = currentBit - signalEndBit;
        cells.add(TableCell(child: Padding(padding: const EdgeInsets.all(4.0), child: Text('0' * gapWidth, style: valueStyle.copyWith(color: Colors.grey), textAlign: TextAlign.center))));
      }

      // Obtener y añadir el valor de la señal de control
      final signalName = field.key;
      final signalWidth = signalInfo.width;
      int rawValue;
      switch (signalName) {
        case 'PCsrc': rawValue = instrInfo.pcSrc; break;
        case 'BRwr': rawValue = instrInfo.brWr ? 1 : 0; break;
        case 'ALUsrc': rawValue = instrInfo.aluSrc; break;
        case 'ALUctr': rawValue = instrInfo.aluCtr; break;
        case 'MemWr': rawValue = instrInfo.memWr ? 1 : 0; break;
        case 'ResSrc': rawValue = instrInfo.resSrc; break;
        case 'ImmSrc': rawValue = instrInfo.immSrc; break;
        default: rawValue = -2;
      }

      String valueStr;
      if (rawValue == -1) {
        valueStr = 'x' * signalWidth;
      } else {
        valueStr = rawValue.toRadixString(2).padLeft(signalWidth, '0');
      }
      cells.add(TableCell(child: Padding(padding: const EdgeInsets.all(4.0), child: Text(valueStr, style: valueStyle, textAlign: TextAlign.center))));

      currentBit = signalInfo.position - 1;
    }
    // Rellenar el hueco final si existe
    if (currentBit >= 0) {
      cells.add(TableCell(child: Padding(padding: const EdgeInsets.all(4.0), child: Text('0' * (currentBit + 1), style: valueStyle.copyWith(color: Colors.grey), textAlign: TextAlign.center))));
    }

    // Palabra de control completa
    final controlWord = instrInfo.controlWord;
    final hexControlWord = '0x${controlWord.toRadixString(16).padLeft(4, '0').toUpperCase()}';

    // --- MODIFICACIÓN: Añadir borde separador ---
    // Envolvemos el contenido de la celda Funct7 en un Container para añadirle un borde derecho.
    final funct7CellChild = cells[3].child;
    cells[3] = TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Container(
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: Colors.grey.shade500, width: 2.0)),
        ),
        child: funct7CellChild,
      ),
    );
    cells.add(TableCell(child: Padding(padding: const EdgeInsets.all(4.0), child: Text(hexControlWord, style: valueStyle))));

    rows.add(TableRow(children: cells));
  }

  return Container(
    padding: const EdgeInsets.all(8.0),
    child: Table(
      border: TableBorder.all(color: Colors.grey.shade700, width: 1),
      columnWidths: {
        0: const IntrinsicColumnWidth(), // Instruction
        1: const FixedColumnWidth(60),  // Opcode
        2: const FixedColumnWidth(60),  // Funct3
        3: const FixedColumnWidth(60),  // Funct7
        // El resto de columnas se ajustan a su contenido
        for (int i = 4; i < headers.length; i++)
          i: const IntrinsicColumnWidth(),
      },

      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: rows,
    ),
  );
}


/// Construye un widget que muestra una instrucción de 32 bits formateada
/// con colores y etiquetas para cada campo, según su tipo (R, I, S, B, J, U).
Widget buildFormattedInstruction(InstructionInfo info, int instruction) {
  final opcodeColor = Colors.red[700]!;
  final rdColor = Colors.yellow;
  final rs1Color = const Color.fromARGB(255, 197, 183, 55);
  final rs2Color = Colors.yellow;
  final funct3Color = Colors.red[400]!;
  final funct7Color = Colors.red[300]!;
  final immColor = Colors.blue;

  List<_Field> fields = [];

  switch (info.type) {
    case 'R':
      fields = [
        _Field('funct7', 25, 31, funct7Color),
        _Field('rs2', 20, 24, rs2Color),
        _Field('rs1', 15, 19, rs1Color),
        _Field('funct3', 12, 14, funct3Color),
        _Field('rd', 7, 11, rdColor),
        _Field('op_code', 0, 6, opcodeColor),
      ];
      break;
    case 'I':
      fields = [
        _Field('imm[11:0]', 20, 31, immColor),
        _Field('rs1', 15, 19, rs1Color),
        _Field('funct3', 12, 14, funct3Color),
        _Field('rd', 7, 11, rdColor),
        _Field('op_code', 0, 6, opcodeColor),
      ];
      break;
    case 'S':
      fields = [
        _Field('imm[11:5]', 25, 31, immColor),
        _Field('rs2', 20, 24, rs2Color),
        _Field('rs1', 15, 19, rs1Color),
        _Field('funct3', 12, 14, funct3Color),
        _Field('imm[4:0]', 7, 11, immColor),
        _Field('op_code', 0, 6, opcodeColor),
      ];
      break;
    case 'B':
      fields = [
        _Field('A', 31, 31, immColor),
        _Field('CCCCCC', 25, 30, immColor),
        _Field('rs2', 20, 24, rs2Color),
        _Field('rs1', 15, 19, rs1Color),
        _Field('funct3', 12, 14, funct3Color),
        _Field('DDDD', 8, 11, immColor),
        _Field('B', 7, 7, immColor),
        _Field('op_code', 0, 6, opcodeColor),
      ];
      break;
    case 'U':
      fields = [
        _Field('imm[31:12]', 12, 31, immColor),
        _Field('rd', 7, 11, rdColor),
        _Field('op_code', 0, 6, opcodeColor),
      ];
      break;
    case 'J':
      fields = [
        _Field('A', 31, 31, immColor),
        _Field('DDDDDDDDDD', 21, 30, immColor),
        _Field('C', 20, 20, immColor),
        _Field('BBBBBBBBB', 12, 19, immColor),
        _Field('rd', 7, 11, rdColor),
        _Field('op_code', 0, 6, opcodeColor),
      ];
      break;
    default:
      return RichText(text: TextSpan(text: (instruction & 0xFFFFFFFF).toRadixString(2).padLeft(32, '0'), style: miEstiloTooltip));
  }

  final binaryString = (instruction & 0xFFFFFFFF).toRadixString(2).padLeft(32, '0');
  final bitSpans = <TextSpan>[];
  final labelSpans = <TextSpan>[];

  fields.sort((a, b) => b.start.compareTo(a.start));

  for (final field in fields) {
    final startIndex = 31 - field.end;
    final endIndex = 31 - field.start + 1;
    final bitSubstring = binaryString.substring(startIndex, endIndex);

    bitSpans.add(TextSpan(text: bitSubstring, style: miEstiloTooltip.copyWith(color: field.color, fontSize: 24)));
    labelSpans.add(TextSpan(text: _padCenter(field.name, field.width), style: miEstiloTooltip.copyWith(color: field.color, fontSize: 24)));
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      RichText(text: TextSpan(style: miEstiloTooltip, children: bitSpans)),
      RichText(text: TextSpan(style: miEstiloTooltip, children: labelSpans)),
    ],
  );
}


/// Clase auxiliar para definir un campo dentro de una instrucción.
class _Field {
  final String name;
  final int start;
  final int end;
  final Color color;

  _Field(this.name, this.start, this.end, this.color);

  int get width => end - start + 1;
}

/// Centra un texto dentro de un ancho dado, rellenando con espacios.
String _padCenter(String text, int width) {
  if (text.length >= width) {
    return text.substring(0, width);
  }
  int padding = width - text.length;
  int left = padding ~/ 2;
  int right = padding - left;
  return (' ' * left) + text + (' ' * right);
}

/// Construye el tooltip para el Mux de Forwarding A.
Widget buildMuxFwdATooltip(DatapathState datapathState) {
  final forwardA = datapathState.busValues['bus_ControlForwardA'] ?? 0;
  final value = datapathState.busValues['bus_ForwardA'];

  String sourceDescription;
  switch (forwardA) {
    case 1:
      sourceDescription = "1: Resultado de la etapa MEM (ALU)";
      break;
    case 2:
      sourceDescription = "2: Resultado de la etapa WB";
      break;
    default:
      sourceDescription = "0: Valor del registro (sin forwarding)";
      break;
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text('Mux Forwarding A (MFWA)', style: miEstiloTooltip.copyWith(fontWeight: FontWeight.bold, fontSize: 14)),
      const SizedBox(height: 8),
      Text('Selección: $forwardA ($sourceDescription)', style: miEstiloTooltip),
      const SizedBox(height: 4),
      Text('Valor de salida: ${toHex(value)}', style: miEstiloTooltip),
      const SizedBox(height: 8),
      Text('Este mux selecciona la entrada para el operando A de la ALU.', style: miEstiloTooltip.copyWith(fontSize: 11, fontStyle: FontStyle.italic)),
    ],
  );
}

/// Construye el tooltip para el Mux de Forwarding B.
Widget buildMuxFwdBTooltip(DatapathState datapathState) {
  final forwardB = datapathState.busValues['bus_ControlForwardB'] ?? 0;
  final value = datapathState.busValues['bus_ForwardB'];

  String sourceDescription;
  switch (forwardB) {
    case 1:
      sourceDescription = "1: Resultado de la etapa MEM (ALU)";
      break;
    case 2:
      sourceDescription = "2: Resultado de la etapa WB";
      break;
    default:
      sourceDescription = "0: Valor del registro (sin forwarding)";
      break;
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text('Mux Forwarding B (MFWB)', style: miEstiloTooltip.copyWith(fontWeight: FontWeight.bold, fontSize: 14)),
      const SizedBox(height: 8),
      Text('Selección: $forwardB ($sourceDescription)', style: miEstiloTooltip),
      const SizedBox(height: 4),
      Text('Valor de salida: ${toHex(value)}', style: miEstiloTooltip),
      const SizedBox(height: 8),
      Text('Este mux selecciona la entrada para el operando B de la ALU.', style: miEstiloTooltip.copyWith(fontSize: 11, fontStyle: FontStyle.italic)),
    ],
  );
}

/// Construye el tooltip para el Mux de Forwarding M (Memoria).
Widget buildMuxFwdMTooltip(DatapathState datapathState) {
  final forwardM = datapathState.busValues['bus_ControlForwardM'] ?? 0;
  final value = datapathState.busValues['bus_ForwardM'];

  String sourceDescription;
  switch (forwardM) {
    case 1:
      sourceDescription = "1: Resultado de la etapa WB";
      break;
    default:
      sourceDescription = "0: Valor del registro (sin forwarding)";
      break;
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text('Mux Forwarding Mem (MFWM)', style: miEstiloTooltip.copyWith(fontWeight: FontWeight.bold, fontSize: 14)),
      const SizedBox(height: 8),
      Text('Selección: $forwardM ($sourceDescription)', style: miEstiloTooltip),
      const SizedBox(height: 4),
      Text('Valor de salida: ${toHex(value)}', style: miEstiloTooltip),
      const SizedBox(height: 8),
      Text('Adelanta el dato a escribir en memoria para instrucciones SW.', style: miEstiloTooltip.copyWith(fontSize: 11, fontStyle: FontStyle.italic)),
    ],
  );
}
