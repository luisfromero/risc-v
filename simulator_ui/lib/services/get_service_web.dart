import 'simulation_service.dart';
import 'api_simulation_service.dart';

SimulationService getSimulationService() {
  return ApiSimulationService();
}