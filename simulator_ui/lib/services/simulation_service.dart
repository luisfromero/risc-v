/// Define el "contrato" que cualquier proveedor de simulación (sea FFI, API, etc.)
/// debe cumplir. La UI solo interactuará con esta clase abstracta.

/// Un objeto simple para contener el estado de la simulación en un instante dado.
class SimulationState {
  final int pcValue;
  final bool isPcAdderActive;
  final bool isBranchAdderActive;
  final bool isAluActive;
  final bool isMux1Active;
  final bool isMux2Active;
  final bool isMux3Active;
  // Aquí añadiremos más datos en el futuro, como los 'readyAt'.

  SimulationState({
    required this.pcValue,
    this.isPcAdderActive = false,
    this.isBranchAdderActive = false,
    this.isAluActive = false,
    this.isMux1Active = false,
    this.isMux2Active = false,
    this.isMux3Active = false,
  });
}

abstract class SimulationService {
  /// Inicializa el servicio (ej. cargar la DLL).
  Future<void> initialize();

  /// Ejecuta un ciclo de reloj y devuelve el nuevo estado.
  Future<SimulationState> clockTick();

  /// Resetea la simulación a su estado inicial.
  Future<SimulationState> reset();
}