// simulator_ui/lib/services/api_simulation_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../simulation_mode.dart';
import '../datapath_state.dart';
import 'simulation_service.dart';
import 'dart:typed_data';

class ApiSimulationService implements SimulationService {
  
  // esta da error de cors que no supe arreglar final String _baseUrl = 'http://riscv-api.ac.uma.es';//
  final String _baseUrl ='http://riscv-api.ac.uma.es'; // URL de tu API
  String? _sessionId; // <-- NUEVO: Para guardar el ID de sesión.
  SimulationMode _currentMode = SimulationMode.singleCycle;
  // Para mantener el estado actual, incluyendo las memorias que se cargan bajo demanda.
  SimulationState? _currentState;

  @override
  Future<void> initialize() async {
    // Ahora la inicialización se encarga de obtener un ID de sesión.
    final response = await http.post(Uri.parse('$_baseUrl/session/start'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _sessionId = data['session_id'];
      // ignore: avoid_print
      print('Nueva sesión de API iniciada: $_sessionId');
    } else {
      throw Exception('Failed to start a new session: ${response.statusCode}');
    }
  }

  // Helper para asegurarse de que la sesión está inicializada.
  void _checkSession() {
    if (_sessionId == null) {
      throw Exception('El servicio de simulación no ha sido inicializado. Llama a initialize() primero.');
    }
  }

  @override
  Future<SimulationState> step() async {
    if (_currentState == null) {
      throw Exception(
          "El estado del simulador no está inicializado. Llama a reset() primero.");
    }
    _checkSession();

    // Guardamos el estado anterior antes de cualquier llamada asíncrona.
    final stateBeforeStep = _currentState!;

    final uri = Uri.parse('$_baseUrl/step').replace(queryParameters: {
      'session_id': _sessionId!,
    });

    final response = await http.post(uri);
    if (response.statusCode != 200) {
      // ignore: avoid_print
      print('Error en la API /step: ${response.statusCode}\n${response.body}');
      throw Exception('Failed to call step API: ${response.statusCode}');
    }

    // Este es el nuevo estado con registros, PC, etc. actualizados, pero memorias vacías/antiguas.
    final newStateFromStep =
        SimulationState.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));

    // Comprobamos si la instrucción ejecutada requiere actualizar la memoria de datos.
    bool needMemoryUpdate = false;
    if (_currentMode == SimulationMode.pipeline) {
      needMemoryUpdate = newStateFromStep.busValues["Pipe_MemWr"] == 1;
    } else {
      needMemoryUpdate = newStateFromStep.busValues["control_MemWr"] == 1;
    }

    // Si es necesario, obtenemos la nueva memoria de datos.
    final dataMemory = needMemoryUpdate
        ? (await getDataMemory()).dataMemory
        : stateBeforeStep.dataMemory;

    // Combinamos el nuevo estado de los registros con las memorias correctas.
    _currentState = newStateFromStep.copyWith(
      instructionMemory: stateBeforeStep.instructionMemory,
      dataMemory: dataMemory,
    );

    return _currentState!;
  }

 // api_simulation_service.dart

@override
Future<SimulationState> getDataMemory() async {
  _checkSession();
  if (_currentState == null) {
    throw Exception(
        "El estado del simulador no está inicializado. Llama a reset() primero.");
  }

  final uri = Uri.parse('$_baseUrl/memory/data').replace(queryParameters: {
    'session_id': _sessionId!,
  });
  final response = await http.get(uri);
      
  if (response.statusCode == 200) {
    // CORRECTO: Tomamos los bytes directamente de la respuesta.
    final Uint8List dataMemory = response.bodyBytes;
    
    _currentState = _currentState!.copyWith(dataMemory: dataMemory);
    return _currentState!;
  } else {
    // ignore: avoid_print
    print(
        'Error en la API /memory/data: ${response.statusCode}\n${response.body}');
    throw Exception('Failed to call getDataMemory API: ${response.statusCode}');
  }
}
 
  @override
  Future<SimulationState> getInstructionMemory() async
  {
    _checkSession();
    if (_currentState == null) {
      throw Exception(
          "El estado del simulador no está inicializado. Llama a reset() primero.");
    }
    final uri = Uri.parse('$_baseUrl/memory/instructions').replace(queryParameters: {
      'session_id': _sessionId!,
    });

    final response = await http.get(uri);
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
    _checkSession();
    final uri = Uri.parse('$_baseUrl/step_back').replace(queryParameters: {
      'session_id': _sessionId!,
    });

    final response = await http.post(uri);
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
  Future<SimulationState> reset({
    required SimulationMode mode,
    int initial_pc = 0,
    String? assemblyCode,
    Uint8List? binCode,
    bool hazardsEnabled = true, // Añadimos el parámetro
  }) async {
    _checkSession();
    _currentMode = mode; // Guardamos el modo actual para usarlo en step()
    // Mapea el enum de Dart al string que espera la API de Python.
    const modelMap = {
      SimulationMode.singleCycle: 'SingleCycle',
      SimulationMode.pipeline: 'PipeLined',
      SimulationMode.multiCycle: 'MultiCycle',
      //SimulationMode.general: 'General',
    };
    final modelName = modelMap[mode] ?? 'SingleCycle';

    final uri = Uri.parse('$_baseUrl/reset').replace(queryParameters: {
      'session_id': _sessionId!,
    });


    final Map<String, dynamic> requestBody = {
      'model': modelName,
      'initial_pc': initial_pc,
      'load_test_program': binCode == null && assemblyCode == null,
      'hazards_enabled': hazardsEnabled, // Y lo incluimos en el cuerpo de la petición
    };

    if (binCode != null && binCode.isNotEmpty) {
      requestBody['bin_code'] = base64Encode(binCode);
    }
    if (assemblyCode != null) {
      requestBody['assembly_code'] = assemblyCode;
    }
    
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    );

    if (response.statusCode == 200) {
      // 1. Obtenemos el estado inicial del simulador (registros, PC, etc.).
      final initialState = SimulationState.fromJson(jsonDecode(utf8.decode(response.bodyBytes)),
          initial_pc: initial_pc);

      // 2. Establecemos un estado base para que las llamadas de memoria funcionen.
      _currentState = initialState;

      // 3. Consultamos las memorias en paralelo para mayor eficiencia.
      final results = await Future.wait([
        getInstructionMemory(),
        getDataMemory(),
      ]);

      // 4. Combinamos el estado inicial con las memorias obtenidas.
      _currentState = initialState.copyWith(
        instructionMemory: results[0].instructionMemory,
        dataMemory: results[1].dataMemory,
      );
      return _currentState!;
    } else {
      // ignore: avoid_print
      print('Error en la API /reset: ${response.statusCode}\n${response.body}');
      throw Exception('Failed to call reset API: ${response.statusCode}');
    }
  }
}
