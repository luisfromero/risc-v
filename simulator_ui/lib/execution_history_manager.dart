import 'dart:collection';
import 'dart:math';
import 'package:flutter/material.dart';

import 'datapath_state.dart';
import 'simulation_mode.dart';
import 'colors.dart';

/// Gestiona la lógica del historial de ejecución.
class ExecutionHistoryManager {
  final List<ExecutionRecord> _historyLog = [];
  // --- Estado para la lógica del pipeline ---
  int _stepCounter = 0;
  ExecutionRecord? _instructionToRetire=ExecutionRecord(pc: 0, instruction: "nop");

  CAUSAS cause=CAUSAS.RESET;

  /// Devuelve una vista no modificable del historial.
  List<ExecutionRecord> get history => UnmodifiableListView(_historyLog);

  /// Actualiza el historial según la acción realizada y el modo de simulación.
  void update(DatapathState simState) {
    switch (simState.simulationMode) {
      case SimulationMode.singleCycle:
        _updateSingleCycle(simState);
        break;
      case SimulationMode.multiCycle:
        _updateMultiCycle(simState);
        break;
      case SimulationMode.pipeline:
        _updatePipeline(simState);
        break;
    }
  }

  // --- Lógica para Monociclo ---
  void _updateSingleCycle(DatapathState simState) {
    switch (cause) {
      case CAUSAS.RESET:
        _historyLog.clear();
        if (simState.instruction.isNotEmpty) {
          _historyLog.add(ExecutionRecord(pc: simState.pcValue, instruction: simState.instruction));
        }
        break;
      case CAUSAS.STEP:
        // En monociclo, la instrucción a añadir es la que estaba ANTES del step.
        // El `simState` que recibimos ya es el NUEVO, por lo que no podemos usar `simState.instruction`.
        // Sin embargo, el `DatapathState` todavía tiene el valor antiguo.
        // Por simplicidad y robustez, asumimos que el `step` añade la instrucción del estado actual.
        if (simState.instruction.isNotEmpty) {
          if (_historyLog.isEmpty || _historyLog.last.pc != simState.pcValue) {
             _historyLog.add(ExecutionRecord(pc: simState.pcValue, instruction: simState.instruction));
          }
        }
        break;
      case CAUSAS.STEPBACK:
        if (_historyLog.isNotEmpty) {
          _historyLog.removeLast();
        }
        break;
      default:
        break; // No hace nada en los micro-pasos
    }
  }

  // --- Lógica para Multiciclo ---
  void _updateMultiCycle(DatapathState simState) {
    final Color baseColor = instructionColors[(simState.pcValue ~/ 4) % instructionColors.length];
    switch (cause) {
      case CAUSAS.RESET:
      case CAUSAS.STEP: // Un step completo añade un nuevo bloque de instrucciones
        if (cause == CAUSAS.RESET) _historyLog.clear();


        if (simState.instruction.isNotEmpty) {
          //Limpiamos las anteriores
          for (int i = max(0, _historyLog.length-5); i < _historyLog.length; i++) {
            _historyLog[i].isActive = false;
            _historyLog[i].color = _historyLog[i].color.withAlpha(50);
          }
          for (int i = 0; i < simState.totalMicroCycles; i++) {
            _historyLog.add(ExecutionRecord(
              pc: (simState.busValues['npc_bus']??0)-4,
              instruction: simState.instruction.replaceAll(',', ''),
              isActive: i == 0, 
              color: i == 0 ? baseColor.withAlpha(150) : baseColor.withAlpha(50),
            ));
          }
        }
        break;
      
      case CAUSAS.STEP_MICRO:
      case CAUSAS.STEPBACK_MICRO:
        // Al movernos entre microciclos, solo actualizamos el estado `isActive`.
        // Simplemente modificamos las propiedades de los objetos existentes.
        final instructionStartIndex = _historyLog.length - simState.totalMicroCycles;
        for (int i = max(0, instructionStartIndex-10); i < _historyLog.length; i++) {
          _historyLog[i].isActive = false;
          _historyLog[i].color = _historyLog[i].color.withAlpha(50);
        }
        for (int i = instructionStartIndex; i < _historyLog.length; i++) {
          final record = _historyLog[i];
          record.isActive = (i == instructionStartIndex + simState.currentMicroCycle);
          record.color = record.isActive ? baseColor.withAlpha(150) : baseColor.withAlpha(50);
        }
        break;
      case CAUSAS.STEPBACK:
        // Al retroceder una instrucción completa, eliminamos su bloque de microciclos.
        if (_historyLog.isNotEmpty) {
          final lastPc = _historyLog.last.pc;
          _historyLog.removeWhere((record) => record.pc == lastPc);
        }
        break;
    }
  }

  // --- Lógica para Segmentado (Pipeline) ---
  void _updatePipeline(DatapathState simState) {
    // El historial (_historyLog) solo contiene las instrucciones ya graduadas.
    // Usamos un contador para saber cuándo empiezan a graduarse.
    switch (cause) {
      case CAUSAS.RESET:
        _historyLog.clear();
        _stepCounter = 1; // El simulador siempre empieza con un ciclo ejecutado.
        _instructionToRetire = ExecutionRecord(pc: -16, instruction: "nop");
        break;
      case CAUSAS.STEP:
        _stepCounter++;

        // A partir del paso 6, la instrucción que guardamos en el ciclo anterior se gradúa.
        if (_stepCounter >=1 && _instructionToRetire != null)
         {
          _historyLog.add(_instructionToRetire!);
        }

        // A partir del paso 5, empezamos a "ver" qué instrucción llegará a la etapa de retiro.
        // La instrucción en WB en el estado actual (`simState`) es la que se retirará en el *siguiente* ciclo.
        //if (_stepCounter >= 5) 
        {
          final instructionInWb = simState.pipeWbInstruction;
          if (instructionInWb.isNotEmpty) { // Todas las instrucciones, incluyendo nops y c.unimp, se gradúan.
              final int pcvalue=_stepCounter >= 5 ? (simState.busValues['Pipe_MEM_WB_NPC_out'] ?? 0)-4 : (-(5-_stepCounter)*4);
            _instructionToRetire = ExecutionRecord(
              pc: pcvalue,
              instruction: instructionInWb.replaceAll(',', ''),

            );
          } else {
            _instructionToRetire = ExecutionRecord(pc: 0, instruction: "nop"); // Si es un nop o unimp, no se retirará nada.
          }
        }
        break;
      case CAUSAS.STEPBACK:
        if ( _historyLog.isNotEmpty) {
          _historyLog.removeLast();
        }
        if (_stepCounter > 0) {
          _stepCounter--;
        }
        // Al retroceder, la lógica para _instructionToRetire se re-evaluará en el siguiente 'step'.
        _instructionToRetire = null;
        break;
      default:
        // Los micro-pasos no aplican a pipeline.
        break;
    }
  }
}
