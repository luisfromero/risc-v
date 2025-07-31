import 'package:flutter/material.dart';
import 'services/simulation_service.dart';

// ChangeNotifier nos permite "notificar" a los widgets cuando algo cambia.
class DatapathState extends ChangeNotifier {
  // Dependencia del servicio de simulación. No sabe si es FFI o API.
  final SimulationService _simulationService;
  DatapathState(this._simulationService);

  // --- ESTADO DEL DATAPATH ---
  bool _isPcAdderActive = false;
  bool _isBranchAdderActive = false;
  bool _isAluActive = false;
  bool _isMux1Active = false;
  bool _isMux2Active = false;
  bool _isMux3Active = false;
  int _pcValue = 0x00400000;
  String _hoverInfo = ""; // Texto a mostrar en el hover.
  double _sliderValue = 0.0; // Nuevo estado para el slider.

  // --- GETTERS (para que los widgets lean el estado) ---
  bool get isPcAdderActive => _isPcAdderActive;
  bool get isBranchAdderActive => _isBranchAdderActive;
  bool get isAluActive => _isAluActive;
  bool get isMux1Active => _isMux1Active;
  bool get isMux2Active => _isMux2Active;
  bool get isMux3Active => _isMux3Active;
  int get pcValue => _pcValue;
  String get hoverInfo => _hoverInfo;
  double get sliderValue => _sliderValue;

  // Inicializa el estado pidiendo los valores iniciales al servicio.
  Future<void> initialize() async {
    await _simulationService.initialize();
    final initialState = await _simulationService.reset();
    _updateState(initialState);
  }

  // --- MÉTODOS PARA MODIFICAR EL ESTADO ---

  // Simula la ejecución de un ciclo de reloj
  Future<void> clockTick() async {
    final newState = await _simulationService.clockTick();
    _updateState(newState);

    // Después de un momento, desactivamos para el siguiente ciclo.
    Future.delayed(const Duration(milliseconds: 500), () {
      final currentState = SimulationState(pcValue: _pcValue);
      _updateState(currentState, clearHover: true);
    });
  }

  // Resetea el estado a sus valores iniciales.
  Future<void> reset() async {
    final newState = await _simulationService.reset();
    _updateState(newState);
  }

  // Método privado para centralizar la actualización del estado de la UI.
  void _updateState(SimulationState simState, {bool clearHover = false}) {
    _pcValue = simState.pcValue;
    _isPcAdderActive = simState.isPcAdderActive;
    _isBranchAdderActive = simState.isBranchAdderActive;
    _isAluActive = simState.isAluActive;
    _isMux1Active = simState.isMux1Active;
    _isMux2Active = simState.isMux2Active;
    _isMux3Active = simState.isMux3Active;
    if (clearHover) _hoverInfo = "";
    notifyListeners();
  }

  // Actualiza el texto del hover
  void setHoverInfo(String info) {
    _hoverInfo = info;
    notifyListeners();
  }

  // Actualiza el valor del slider.
  void setSliderValue(double value) {
    _sliderValue = value;
    notifyListeners();
  }

}