import 'simulation_service.dart';
import 'ffi_simulation_service.dart';

SimulationService getSimulationService() {
  return FfiSimulationService();
}