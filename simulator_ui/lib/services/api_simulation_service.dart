// simulator_ui/lib/services/api_simulation_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../simulation_mode.dart';
import 'simulation_service.dart';

class ApiSimulationService implements SimulationService {
  final String _baseUrl = 'http://localhost:8000'; // URL de tu API
  SimulationMode _currentMode = SimulationMode.singleCycle;

  @override
  Future<void> initialize() async {
    // Para una API, la inicialización podría ser comprobar si el servidor está vivo.
    // Por ahora, no necesitamos hacer nada.
    return Future.value();
  }

  @override
  Future<SimulationState> step() async {
    // Para el modo multiciclo, es probable que el backend necesite saber el modo
    // en cada paso para devolver el número total de microciclos.
    const modelMap = {
      SimulationMode.singleCycle: 'SingleCycle',
      SimulationMode.pipeline: 'PipeLined',
      SimulationMode.multiCycle: 'MultiCycle',
    };
    final modelName = modelMap[_currentMode] ?? 'SingleCycle';

    final response = await http.post(Uri.parse('$_baseUrl/step'),
        headers: {'Content-Type': 'application/json'}, body: jsonEncode({'model': modelName}));
    if (response.statusCode == 200) {
      return SimulationState.fromJson(jsonDecode(response.body));
    } else {
      // ignore: avoid_print
      print('Error en la API /step: ${response.statusCode}\n${response.body}');
      throw Exception('Failed to call step API: ${response.statusCode}');
    }
  }

  @override
  Future<SimulationState> reset({required SimulationMode mode}) async {
    _currentMode = mode; // Guardamos el modo actual para usarlo en step()
    // Mapea el enum de Dart al string que espera la API de Python.
    const modelMap = {
      SimulationMode.singleCycle: 'SingleCycle',
      SimulationMode.pipeline: 'PipeLined',
      SimulationMode.multiCycle: 'MultiCycle',
      //SimulationMode.general: 'General',
    };
    final modelName = modelMap[mode] ?? 'SingleCycle';

    final response = await http.post(
      Uri.parse('$_baseUrl/reset'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'model': modelName}),
    );
    if (response.statusCode == 200) {
      return SimulationState.fromJson(jsonDecode(response.body));
    } else {
      // ignore: avoid_print
      print('Error en la API /reset: ${response.statusCode}\n${response.body}');
      throw Exception('Failed to call reset API: ${response.statusCode}');
    }
  }
}
