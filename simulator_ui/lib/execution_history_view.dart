import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../datapath_state.dart';
import '../simulation_mode.dart';
import '../colors.dart';

class ExecutionHistoryView extends StatefulWidget {
  const ExecutionHistoryView({
    super.key,
  });

  @override
  State<ExecutionHistoryView> createState() => _ExecutionHistoryViewState();
}

class _ExecutionHistoryViewState extends State<ExecutionHistoryView> {
  final ScrollController _scrollController = ScrollController();
  SimulationMode? _previousMode;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Escuchamos los cambios del estado para redibujar cuando sea necesario.
    final datapathState = context.watch<DatapathState>();
    final currentMode = datapathState.simulationMode;

    // --- LÓGICA DE AUTO-SCROLL ---
    // Se ejecuta después de que el frame se ha renderizado, asegurando que
    // el ListView tiene su tamaño final y se puede calcular el scroll.
    // Esto se dispara cada vez que `datapathState` notifica un cambio.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      // Si el modo de simulación ha cambiado, resetea el scroll.
      if (_previousMode != currentMode) {
        _scrollController.jumpTo(0);
        _previousMode = currentMode;
      } else if (_scrollController.position.maxScrollExtent > 0) {
        // Si no, aplica el auto-scroll normal hacia el final.
        _scrollController.animateTo(_scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut);
      }
    });

    // Decidimos qué vista mostrar según el modo de simulación.
    if (datapathState.simulationMode == SimulationMode.pipeline) {
      return _buildPipelineView(datapathState);
    } else {
      return _buildHistoryView(datapathState.executionHistory);
    }
  }

  /// Widget para mostrar el historial de ejecución (Monociclo y Multiciclo).
  Widget _buildHistoryView(List<ExecutionRecord> history) {
    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      child: ListView.builder(
        controller: _scrollController,
        itemCount: history.length,
        itemBuilder: (context, index) {
          final record = history[index];
          final datapathState = context.read<DatapathState>();
          bool isHighlighted = false;
          Color? highlightColor;

          if (datapathState.simulationMode == SimulationMode.multiCycle) {
            isHighlighted = record.isActive;
            highlightColor = record.color;
          } else {
            isHighlighted = (index == history.length - 1);
            highlightColor = isHighlighted ? Colors.yellow.withAlpha(80) : null;
          }

          return Container(
            color: highlightColor,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontFamily: 'RobotoMono', fontSize: 11, color: Colors.black),
                children: [
                  TextSpan(
                    text: '${toHex(record.pc, 4,true)}: ', style: TextStyle(fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal, color: Colors.black54),
                  ),
                  TextSpan(
                    text: record.instruction.replaceAll(',',''),
                    style: TextStyle(fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Widget para mostrar el estado actual del pipeline.
  Widget _buildPipelineView(DatapathState state) {
    final history = state.executionHistory;
    // Las 5 etapas actuales, que se mostrarán siempre al final.
    final pipelineStages = [
      // Usamos el PC que se ha propagado a cada etapa para el color.
      {'label': 'WB:', 'instruction': state.pipeWbInstruction.replaceAll(',', ''), 'pc': (state.busValues['Pipe_MEM_WB_NPC_out']??0)-4},
      {'label': 'MEM:', 'instruction': state.pipeMemInstruction.replaceAll(',', ''), 'pc': (state.busValues['Pipe_EX_MEM_NPC_out']??0)-4},
      {'label': 'EX:', 'instruction': state.pipeExInstruction.replaceAll(',', ''), 'pc': (state.busValues['Pipe_ID_EX_NPC_out']??0)-4},
      {'label': 'ID:', 'instruction': state.pipeIdInstruction.replaceAll(',', ''), 'pc': (state.busValues['Pipe_IF_ID_NPC_out']??0)-4},
      {'label': 'IF:', 'instruction': state.pipeIfInstruction.replaceAll(',', ''), 'pc': (state.busValues['npc_bus']??0)-4 },
    ];

    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      child: ListView.builder(
        controller: _scrollController,
        // El total de items es la suma de las instrucciones graduadas + las 5 etapas.
        itemCount: history.length + 5,
        itemBuilder: (context, index) {
          bool isGraduated = index < history.length;

          String label;
          String instructionText;
          bool isBold;
          Color? bgColor;

          if (isGraduated) {
            // Es una instrucción del historial de graduadas.
            final record = history[index];
            label = record.pc.toRadixString(16).padLeft(2, '0');//'---';
            instructionText = record.instruction;
            bgColor = pipelineColorForPC(record.pc).withAlpha(20);
            isBold = false;
          } else {
            // Es una de las 5 etapas del pipeline.
            final stage = pipelineStages[index - history.length];
            label = stage['label']! as String;
            instructionText = stage['instruction']! as String;
            bgColor = pipelineColorForPC(stage['pc'] as int?).withAlpha(  60);
            isBold = true;
          }

          final isBubble = instructionText.contains('nop');

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Container(
              color: bgColor,
              child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontFamily: 'RobotoMono', fontSize: 11,
                  color: isBubble ? Colors.grey[600] : Colors.black,
                  fontStyle: isBubble ? FontStyle.italic : FontStyle.normal,
                ),
                children: [
                  TextSpan(
                    text: label.padRight(4),
                    style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: isBold ? Colors.black54 : Colors.grey[400]),
                  ),
                  TextSpan(text: instructionText),
                ],
              ),
              ),
            ),
          );
        },
      ),
    );
  }
}
