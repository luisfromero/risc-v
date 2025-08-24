// simulator_ui/lib/services/api_simulation_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../simulation_mode.dart';
import '../datapath_state.dart';
import 'simulation_service.dart';
import 'dart:typed_data';

class ApiSimulationService implements SimulationService {
  
  final String _baseUrl = 'http://localhost:8000'; // URL de tu API
  SimulationMode _currentMode = SimulationMode.singleCycle;
  // Para mantener el estado actual, incluyendo las memorias que se cargan bajo demanda.
  SimulationState? _currentState;

  @override
  Future<void> initialize() async {
    // Para una API, la inicialización podría ser comprobar si el servidor está vivo.
    // Por ahora, no necesitamos hacer nada.
    return Future.value();
  }

  @override
  Future<SimulationState> step() async {
        if (_currentState == null) {
      throw Exception(
          "El estado del simulador no está inicializado. Llama a reset() primero.");
    }
    // 
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
      final newState = SimulationState.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));

      bool needMemoryUpdate=false;
      if(_currentMode==SimulationMode.pipeline)
        needMemoryUpdate = newState.busValues["Pipe_MemWr"]==1;
      else
        needMemoryUpdate = newState.busValues["control_MemWr"]==1;
      

      if(needMemoryUpdate){
        var estado=await getDataMemory();
      _currentState = newState.copyWith(
        instructionMemory: _currentState?.instructionMemory,
        dataMemory: estado.dataMemory
        );
      }
      else{
      // Conservamos las memorias ya cargadas y actualizamos el estado.
      _currentState = newState.copyWith(
        instructionMemory: _currentState?.instructionMemory,
        dataMemory: _currentState?.dataMemory,
        );
      }


      return _currentState!;
    } else {
      // ignore: avoid_print
      print('Error en la API /step: ${response.statusCode}\n${response.body}');
      throw Exception('Failed to call step API: ${response.statusCode}');
    }
  }

 // api_simulation_service.dart

@override
Future<SimulationState> getDataMemory() async {
  if (_currentState == null) {
    throw Exception(
        "El estado del simulador no está inicializado. Llama a reset() primero.");
  }

  final response = await http.get(Uri.parse('$_baseUrl/memory/data'));
      
  if (response.statusCode == 200) {
    // CORRECTO: Tomamos los bytes directamente de la respuesta.
    final Uint8List dataMemory = response.bodyBytes;
    
    _currentState = _currentState!.copyWith(dataMemory: dataMemory);
    return _currentState!;
  } else {
    print(
        'Error en la API /memory/data: ${response.statusCode}\n${response.body}');
    throw Exception('Failed to call getDataMemory API: ${response.statusCode}');
  }
}
 
  @override
  Future<SimulationState> getInstructionMemory() async
  {
    if (_currentState == null) {
      throw Exception(
          "El estado del simulador no está inicializado. Llama a reset() primero.");
    }
    final response = await http.get(Uri.parse('$_baseUrl/memory/instructions'),
        headers: {'Content-Type': 'application/json'});
    if (response.statusCode == 200) {
      final instructionMemoryList =
          jsonDecode(utf8.decode(response.bodyBytes)) as List;
      final instructionMemory = instructionMemoryList
          .map((item) =>
              InstructionMemoryItem.fromJson(item as Map<String, dynamic>))
          .toList();
      _currentState =
          _currentState!.copyWith(instructionMemory: instructionMemory);
      return _currentState!;
    } else {
      // ignore: avoid_print
      print(
          'Error en la API /memory/instructions: ${response.statusCode}\n${response.body}');
      throw Exception(
          'Failed to call getInstructionMemory API: ${response.statusCode}');
    }
    
  }

  @override
  Future<SimulationState> stepBack() async {
    final response = await http.post(Uri.parse('$_baseUrl/step_back'),
        headers: {'Content-Type': 'application/json'});
    if (response.statusCode == 200) {
      final newState =
          SimulationState.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
      _currentState = newState.copyWith(
        instructionMemory: _currentState?.instructionMemory,
        dataMemory: _currentState?.dataMemory,
      );
      return _currentState!;
    } else {
      // ignore: avoid_print
      print(
          'Error en la API /step_back: ${response.statusCode}\n${response.body}');
      throw Exception('Failed to call step_back API: ${response.statusCode}');
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
      // 1. Obtenemos el estado inicial del simulador.
      final initialState = SimulationState.fromJson(
          jsonDecode(utf8.decode(response.bodyBytes)));

      // 2. Ahora, consultamos la memoria de instrucciones.
      final memResponse =
          await http.get(Uri.parse('$_baseUrl/memory/instructions'));
      if (memResponse.statusCode == 200) {
        final instructionMemoryList =
            jsonDecode(utf8.decode(memResponse.bodyBytes)) as List;
        final instructionMemory = instructionMemoryList
            .map((item) =>
                InstructionMemoryItem.fromJson(item as Map<String, dynamic>))
            .toList();

      final dmemResponse =
          await http.get(Uri.parse('$_baseUrl/memory/data'));
      if (dmemResponse.statusCode == 200) {
        final Uint8List dataMemory = dmemResponse.bodyBytes;
        
            // 3. Combinamos y guardamos el estado actual.
        _currentState =
            initialState.copyWith(instructionMemory: instructionMemory,dataMemory: dataMemory);
        return _currentState!;
      }
      else { // <-- ESTE ES EL BLOQUE QUE FALTABA
        throw Exception(
            'Failed to call /memory/data API: ${dmemResponse.statusCode}');
      }
      } else {
        throw Exception(
            'Failed to call /memory/instructions API: ${memResponse.statusCode}');
      }
    } else {
      // ignore: avoid_print
      print('Error en la API /reset: ${response.statusCode}\n${response.body}');
      throw Exception('Failed to call reset API: ${response.statusCode}');
    }
  }
}
