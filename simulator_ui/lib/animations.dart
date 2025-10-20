part of 'datapath_state.dart';

extension DatapathAnimation on DatapathState {

  /// Inicia o pausa la ejecución automática de pasos en el frontend.
  void togglePlayPause() {
    if (_isPlaying) {
      pause();
    } else {
      play();
    }
  }

  /// Inicia la ejecución automática.
  void play() {
    if (_isPlaying) return;
    _isPlaying = true;
    // Llama a step() cada 500ms.
    _timer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      timerStep();
    });
    notifyListeners(); // Notifica a la UI para que actualice el icono del botón.
  }

  /// Pausa la ejecución automática.
  void pause() {
    _timer?.cancel();
    _isPlaying = false;
    notifyListeners(); // Notifica a la UI para que actualice el icono del botón.
  }

  // Simula la ejecución de un ciclo de reloj
  Future<void> timerStep() async {
    // Guardamos el PC de la instrucción que está en IF *antes* de ejecutar el paso.
    final pcBeforeStep = busValues['pc_bus'] ?? -1;

    await step();

    // 1. Comprobación de breakpoints (común a todos los modos)
    if (_breakpoints.contains(current_pc)) {
      print("Breakpoint hit at ${toHex(current_pc)}. Pausing.");
      pause();
      return;
    }

    // 2. Comprobación de fin de programa o bucle, específica para cada modo.
    switch (_simulationMode) {
      case SimulationMode.singleCycle:
        // En monociclo, cada 'step' gradúa una instrucción.
        // Un bucle se detecta si el PC de la instrucción actual es igual al de la anterior.
        if (historyManager.history.length > 1) {
          final lastRecord = historyManager.history.last;
          final previousRecord = historyManager.history[historyManager.history.length - 2];
          if (lastRecord.pc == previousRecord.pc) {
            print("Single-cycle: Infinite loop or end of program detected at ${toHex(current_pc)}. Pausing.");
            pause();
          }
        }
        break;

      case SimulationMode.multiCycle:
        // En multiciclo, un bucle infinito o fin de programa se detecta si, al empezar
        // una nueva instrucción (microciclo 0), el PC no ha cambiado respecto al
        // inicio de la instrucción anterior.
        if (_currentMicroCycle == 0 && pcBeforeStep != -1 && pcBeforeStep == current_pc) {
          print("Multi-cycle: Infinite loop or end of program detected at ${toHex(current_pc)}. Pausing.");
          pause();
        }
        break;

      case SimulationMode.pipeline:
        // Detectamos un bucle infinito si una instrucción de salto (branch o jump)
        // en la etapa de ejecución (EX) tiene como destino su propia dirección.
        final instructionInEX = _pipeExInstructionInfo;
        final isJumpOrBranch = (instructionInEX.type == 'B' || instructionInEX.type == 'J');
        
        if (isJumpOrBranch) {
          final pcInEX = busValues['Pipe_ID_EX_PC_out'] ?? -1;
          final branchTarget = busValues['branch_target_bus'] ?? -2; // Usamos -2 para evitar falsos positivos con -1
          
          if (pcInEX != -1 && pcInEX == branchTarget) {
            print("Pipeline: Infinite loop (jump to self) detected at ${toHex(pcInEX)}. Pausing.");
            pause();
          }
        }
        break;
      }
  }

}