import 'package:flutter/material.dart';
import 'datapath_state.dart';
import 'dart:typed_data';

// --- Tooltip para el Banco de Registros ---

Widget buildRegisterFileTooltip(DatapathState datapathState) {
  final registers = datapathState.registers;
  final busDa = datapathState.busValues['bus_da'];
  final busDb = datapathState.busValues['bus_db'];
  final busDc = datapathState.busValues['bus_dc'];
  final regWrite = datapathState.isPathActive('control_RegWrite') || datapathState.isPathActive('Pipe_MEM_WB_Control_out');

  List<TextSpan> buildRegisterColumn(int start, int end) {
    List<TextSpan> spans = [];
    for (int i = start; i < end; i++) {
      final value = registers.values.elementAt(i) ;
      final regName = 'x$i'.padRight(4);
      final hexValue = '0x${value?.toRadixString(16).padLeft(8, '0')}';
      
      Color color = Colors.white;
      if (i == busDa) color = Colors.yellow;
      if (i == busDb) color = Colors.lightBlueAccent;
      if (i == busDc && regWrite) color = Colors.redAccent;

      spans.add(TextSpan(
        text: '$regName: $hexValue\n',
        style: TextStyle(color: color, fontFamily: 'monospace', fontSize: 12),
      ));
    }
    return spans;
  }

  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      RichText(
        text: TextSpan(children: buildRegisterColumn(0, 16)),
      ),
      const SizedBox(width: 16),
      RichText(
        text: TextSpan(children: buildRegisterColumn(16, 32)),
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
    spans.add(const TextSpan(
      text: 'Address   Instr (Hex)   Assembly\n',
      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'monospace', fontSize: 12),
    ));
    spans.add(const TextSpan(
      text: '----------------------------------------\n',
      style: TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 12),
    ));

    for (int i = start; i < end; i += 4) {
      // Asegurarnos de no leer fuera de los límites
      if ((i ~/ 4) >= instructionMemory.length) continue;

      final address = i;
      final item = instructionMemory[address ~/ 4];
      final hexAddress = '0x${address.toRadixString(16).padLeft(4, '0')}';
      final hexInstruction = '0x${item.value.toRadixString(16).padLeft(8, '0')}';
      final assembly = item.instruction.padRight(20);

      Color color = Colors.white;
      if (address == pc) {
        color = Colors.yellow; // Resaltar la instrucción actual
      }

      spans.add(TextSpan(
        text: '$hexAddress: $hexInstruction  $assembly\n',
        style: TextStyle(color: color, fontFamily: 'monospace', fontSize: 12),
      ));
    }
    return spans;
  }

  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      RichText(text: TextSpan(children: buildInstructionColumn(0, 128))),
      const SizedBox(width: 16),
      RichText(text: TextSpan(children: buildInstructionColumn(128, 256))),
    ],
  );
}


// --- Tooltip para la Memoria de Datos ---

Widget buildDataMemoryTooltip(DatapathState datapathState) {
  final dataMemory = datapathState.dataMemory;
  final addressBus = datapathState.busValues['bus_ALU_result_out'] ?? datapathState.busValues['Pipe_EX_MEM_ALU_result_out'];
  final memWrite = datapathState.isPathActive('control_MemWr') || datapathState.isPathActive('Pipe_MEM_WB_Control_out_MemWrite');
  final memRead = datapathState.isPathActive('control_MemRead') || datapathState.isPathActive('Pipe_MEM_WB_Control_out_MemRead');// ToDo

  if (dataMemory == null || dataMemory.isEmpty) {
    return const Text('(Memory is empty)', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic));
  }

  List<TextSpan> buildDataColumn(int start, int end) {
    List<TextSpan> spans = [];
    spans.add(const TextSpan(
      text: 'Address   Value\n',
      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'monospace', fontSize: 12),
    ));
    spans.add(const TextSpan(
      text: '---------------------\n',
      style: TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 12),
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

      final hexAddress = '0x${address.toRadixString(16).padLeft(4, '0')}';
      final hexValue = '0x${value.toRadixString(16).padLeft(8, '0')}';
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
        style: TextStyle(color: color, fontFamily: 'monospace', fontSize: 12),
      ));
    }
    return spans;
  }

  final column1Spans = buildDataColumn(0, 128);
  final column2Spans = buildDataColumn(128, 256);

  if (column1Spans.length <= 2 && column2Spans.length <= 2) {
    column1Spans.add(const TextSpan(
        text: '\n(Memory is empty in this range)',
        style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontFamily: 'monospace', fontSize: 12)));
    return RichText(text: TextSpan(children: column1Spans));
  }

  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      RichText(text: TextSpan(children: column1Spans)),
      const SizedBox(width: 16),
      RichText(text: TextSpan(children: column2Spans)),
    ],
  );
}
