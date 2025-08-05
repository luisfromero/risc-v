import 'dart:convert';
import 'dart:ffi'; // Necesario para FFI
import 'dart:io';   // Para comprobar el sistema operativo
import 'simulation_service.dart';
import 'package:ffi/ffi.dart';

// Definimos los tipos para la función get_state de la DLL.
// Se espera que devuelva un puntero a una cadena de caracteres (char*) con el JSON,
// que en FFI se representa como Pointer<Int8>.
typedef GetStateC = Pointer<Int8> Function();
typedef GetStateDart = Pointer<Int8> Function();

///////////////////////////////////////////////////////////////////////////////////////
//Opcion chatgpt

typedef SimulatorNewNative = Pointer<Void> Function(Uint64 memSize, Int32 modelType);
typedef SimulatorNew = Pointer<Void> Function(int memSize, int modelType);

typedef SimulatorDeleteNative = Void Function(Pointer<Void>);
typedef SimulatorDelete = void Function(Pointer<Void>);

typedef SimulatorStepNative = Pointer<Utf8> Function(Pointer<Void>);
typedef SimulatorStep = Pointer<Utf8>  Function(Pointer<Void>);

typedef SimulatorResetNative = Pointer<Utf8> Function(Pointer<Void>);
typedef SimulatorReset = Pointer<Utf8> Function(Pointer<Void>);

typedef SimulatorGetInstructionStringNative = Pointer<Utf8> Function(Pointer<Void>);
typedef SimulatorGetInstructionString = Pointer<Utf8> Function(Pointer<Void>);

typedef SimulatorGetPcNative = Uint32 Function(Pointer<Void>);
typedef SimulatorGetPc = int Function(Pointer<Void>);

typedef SimulatorGetStatusRegisterNative = Uint32 Function(Pointer<Void>);
typedef SimulatorGetStatusRegister = int Function(Pointer<Void>);

typedef SimulatorGetAllRegistersNative = Void Function(Pointer<Void>, Pointer<Uint32>);
typedef SimulatorGetAllRegisters = void Function(Pointer<Void>, Pointer<Uint32>);

typedef SimulatorGetStateJsonNative = Pointer<Utf8> Function(Pointer<Void>);
typedef SimulatorGetStateJson = Pointer<Utf8> Function(Pointer<Void>);

// -------------------------------------------
// ChatGPT Carga de funciones desde la DLL
// -------------------------------------------

late final DynamicLibrary _simulatorLib;


final SimulatorNew simulatorNew = _simulatorLib
    .lookup<NativeFunction<SimulatorNewNative>>('Simulator_new')
    .asFunction();

final SimulatorDelete simulatorDelete = _simulatorLib
    .lookup<NativeFunction<SimulatorDeleteNative>>('Simulator_delete')
    .asFunction();

final SimulatorReset simulatorReset = _simulatorLib
    .lookup<NativeFunction<SimulatorResetNative>>('Simulator_reset')
    .asFunction();


final SimulatorStep simulatorStep = _simulatorLib
    .lookup<NativeFunction<SimulatorStepNative>>('Simulator_step')
    .asFunction();

final SimulatorGetInstructionString simulatorGetInstructionString = _simulatorLib
    .lookup<NativeFunction<SimulatorGetInstructionStringNative>>('Simulator_get_instruction_string')
    .asFunction();

final SimulatorGetPc simulatorGetPc = _simulatorLib
    .lookup<NativeFunction<SimulatorGetPcNative>>('Simulator_get_pc')
    .asFunction();

final SimulatorGetStatusRegister simulatorGetStatusRegister = _simulatorLib
    .lookup<NativeFunction<SimulatorGetStatusRegisterNative>>('Simulator_get_status_register')
    .asFunction();

final SimulatorGetAllRegisters simulatorGetAllRegisters = _simulatorLib
    .lookup<NativeFunction<SimulatorGetAllRegistersNative>>('Simulator_get_all_registers')
    .asFunction();

final SimulatorGetStateJson simulatorGetStateJson = _simulatorLib
    .lookup<NativeFunction<SimulatorGetStateJsonNative>>('Simulator_get_state_json')
    .asFunction();

// -------------------------------------------
// Clase Dart para usar el simulador
// -------------------------------------------

class SimulatorChatGPT {
  final Pointer<Void> _sim;

  SimulatorChatGPT({int memSize = 1024 * 1024, int modelType = 3})
      : _sim = simulatorNew(memSize, modelType);

  void dispose() {
    simulatorDelete(_sim);
  }

  Map<String, dynamic>   step() {
    final jsonStr = simulatorStep(_sim).toDartString();
    final instruccion=simulatorGetInstructionString(_sim).toDartString();
    final json= jsonDecode(jsonStr);
    json['instruction']=instruccion;
    return json;
  }

  Map<String, dynamic>  reset() {
    final jsonStr = simulatorReset(_sim).toDartString();
        return jsonDecode(jsonStr);
  }

  int get pc => simulatorGetPc(_sim);

  int get status => simulatorGetStatusRegister(_sim);

  List<int> get allRegisters {
    final buffer = calloc<Uint32>(32);
    simulatorGetAllRegisters(_sim, buffer);
    final regs = List<int>.generate(32, (i) => buffer[i]);
    calloc.free(buffer);
    return regs;
  }

  String get currentInstruction {
    return simulatorGetInstructionString(_sim).toDartString();
  }

  Map<String, dynamic> get state {
    final jsonStr = simulatorGetStateJson(_sim).toDartString();
    return jsonDecode(jsonStr);
  }
}

///////////////////////////////////////////////////////////////////////////////////////




/// Implementación del servicio de simulación que usa FFI para comunicarse
/// directamente con una librería nativa (DLL/SO).
class FfiSimulationService implements SimulationService {
  // No hay estado interno. El servicio es un proxy sin estado a la DLL.

  // Usamos 'late final' para indicar que se inicializarán en initialize() y no cambiarán.
  //late final DynamicLibrary _simulatorLib;
  late final void Function() _clockTickFunc;
  late final void Function() _resetFunc;
  late final int Function() _getPcFunc;
  late final GetStateDart _getStateFunc;

  late final SimulatorChatGPT simChatGPT;









  @override
  Future<void> initialize() async {
    // --- LÓGICA REAL DE FFI ---
    // La DLL/SO se espera en una carpeta 'core' al mismo nivel que la carpeta del proyecto 'simulator_ui'
    final libPath = Platform.isWindows ? 'simulator.dll' : 'libsimulator.so';
    try {
      _simulatorLib = DynamicLibrary.open(libPath);

/*
      // Buscamos las funciones en la DLL y las asignamos a nuestras variables.
      _clockTickFunc = _simulatorLib
          .lookup<NativeFunction<Void Function()>>('clock_tick')
          .asFunction<void Function()>();
      _resetFunc = _simulatorLib
          .lookup<NativeFunction<Void Function()>>('reset')
          .asFunction<void Function()>();
      _getPcFunc = _simulatorLib
          .lookup<NativeFunction<Uint32 Function()>>('get_pc')
          .asFunction<int Function()>();
      _getStateFunc = _simulatorLib
          .lookup<NativeFunction<GetStateC>>('get_state')
          .asFunction<GetStateDart>();

*/





          
    } catch (e) {
      if (e is ArgumentError) {
        // ignore: avoid_print
        print('Error: No se pudo encontrar una función en la librería "$libPath". Asegúrate de que todas las funciones (reset, steo, get_pc, get_state) están exportadas correctamente.');
      } else {
        // ignore: avoid_print
        print('Error: No se pudo cargar la librería desde "$libPath". La ruta es relativa al directorio de trabajo (${Directory.current.path}).');
      }
      rethrow;
    }
    // ignore: avoid_print
    print("Servicio FFI inicializado (real).");


//ChatGPT
  simChatGPT = SimulatorChatGPT();



  }

  @override
  Future<SimulationState> step() async {
    final estadoPtr = simChatGPT.step();
    final pc = simChatGPT.pc;
    final status = simChatGPT.status;
    final allRegisters = simChatGPT.allRegisters;
    final currentInstruction = simChatGPT.currentInstruction;
    final state = simChatGPT.state;
    

    SimulationState estado = SimulationState.fromJson(estadoPtr);
        return estado;

    //_clockTickFunc();
    //return _getFullState();
  }

  @override
  Future<SimulationState> reset() async {
    final estadoPtr = simChatGPT.reset();
    // Convertir json en estado?
    SimulationState estado = SimulationState.fromJson(estadoPtr);
    return estado;
  }

  /// Llama a la DLL para obtener el estado completo como un JSON y lo parsea.
  SimulationState _getFullState() {
    // NOTA: Se asume que el puntero devuelto por get_state() es válido hasta
    // la siguiente llamada a una función de la DLL. Si la DLL reserva memoria
    // nueva en cada llamada, se necesitaría una función para liberarla.
    final statePtr = _getStateFunc();
    if (statePtr == nullptr) {
      // ignore: avoid_print
      print('Error: la función get_state() de la DLL ha devuelto un puntero nulo.');
      // Devolvemos un estado por defecto o lanzamos una excepción para no romper la app.
      throw Exception('get_state() returned a null pointer.');
    }

    // La forma canónica de convertir un Pointer<Utf8> a String es:
    //   final jsonString = statePtr.cast<Utf8>().toDartString();
    // Sin embargo, para evitar posibles problemas de compilación con algunas
    // versiones del toolchain, lo hacemos de forma más manual:
    int len = 0;
    while (statePtr.elementAt(len).value != 0) {
      len++;
    }
    final jsonString = utf8.decode(statePtr.asTypedList(len));
    final stateMap = jsonDecode(jsonString) as Map<String, dynamic>;

    final pc = stateMap['pcValue'] as int? ?? 0;
    // ignore: avoid_print
    print("Estado recibido (real): PC ahora es 0x${pc.toRadixString(16)}");

    return SimulationState.fromJson(stateMap);
  }
}