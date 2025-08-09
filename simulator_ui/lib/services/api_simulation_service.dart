// simulator_ui/lib/services/api_simulation_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'simulation_service.dart';

class ApiSimulationService implements SimulationService {
  final String _baseUrl = 'http://localhost:8000'; // URL de tu API

  @override
  Future<void> initialize() async {
    // Para una API, la inicialización podría ser comprobar si el servidor está vivo.
    // Por ahora, no necesitamos hacer nada.
    return Future.value();
  }

  @override
  Future<SimulationState> step() async {
    final response = await http.get(Uri.parse('$_baseUrl/step'));
    if (response.statusCode == 200) {
      return SimulationState.fromJson(jsonDecode(response.body));
    } else {
      // ignore: avoid_print
      print('Error en la API /step: ${response.statusCode}\n${response.body}');
      throw Exception('Failed to call step API: ${response.statusCode}');
    }
  }

  @override
  Future<SimulationState> reset() async {
    final response = await http.post(Uri.parse('$_baseUrl/reset'));
    if (response.statusCode == 200) {
      return SimulationState.fromJson(jsonDecode(response.body));
    } else {
      // ignore: avoid_print
      print('Error en la API /reset: ${response.statusCode}\n${response.body}');
      throw Exception('Failed to call reset API: ${response.statusCode}');
    }
  }
}
