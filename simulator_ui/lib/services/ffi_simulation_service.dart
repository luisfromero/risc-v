import 'dart:convert';
import 'dart:ffi'; // Necesario para FFI
import 'dart:io'; // Para comprobar el sistema operativo
import 'dart:typed_data'; // Para Uint8List
import 'package:ffi/ffi.dart';
import 'simulation_service.dart';

///////////////////////////////////////////////////////////////////////////////////////
//Opcion chatgpt

typedef SimulatorNewNative = Pointer<Void> Function(Uint64 memSize, Int32 modelType);
typedef SimulatorNew = Pointer<Void> Function(int memSize, int modelType);

typedef SimulatorDeleteNative = Void Function(Pointer<Void>);
typedef SimulatorDelete = void Function(Pointer<Void>);

typedef SimulatorLoadProgramNative = Void Function(Pointer<Void>, Pointer<Uint8>, IntPtr);
typedef SimulatorLoadProgram = void Function(Pointer<Void>, Pointer<Uint8>, int);

typedef SimulatorStepNative = Pointer<Utf8> Function(Pointer<Void>);
typedef SimulatorStep = Pointer<Utf8> Function(Pointer<Void>);

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

// Las funciones se declaran como 'late' y se inicializarán en FfiSimulationService.initialize()
late final DynamicLibrary _simulatorLib;
late final SimulatorNew simulatorNew;
late final SimulatorDelete simulatorDelete;
late final SimulatorLoadProgram simulatorLoadProgram;
late final SimulatorReset simulatorReset;
late final SimulatorStep simulatorStep;
late final SimulatorGetInstructionString simulatorGetInstructionString;
late final SimulatorGetPc simulatorGetPc;
late final SimulatorGetStatusRegister simulatorGetStatusRegister;
late final SimulatorGetAllRegisters simulatorGetAllRegisters;
late final SimulatorGetStateJson simulatorGetStateJson;

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

  void loadProgram(Uint8List programData) {
    final buffer = calloc<Uint8>(programData.length);
    buffer.asTypedList(programData.length).setAll(0, programData);
    simulatorLoadProgram(_sim, buffer, programData.length);
    calloc.free(buffer);
  }

  Map<String, dynamic> step() {
    // 1. Ejecuta un ciclo de reloj en el simulador y obtiene el estado principal del datapath.
    final jsonStr = simulatorStep(_sim).toDartString();
    final json = jsonDecode(jsonStr);

    // 2. Obtiene información adicional del simulador.
    final instruction = simulatorGetInstructionString(_sim).toDartString();
    final pcVal = simulatorGetPc(_sim);
    final statusVal = simulatorGetStatusRegister(_sim);
    final regsList = allRegisters;

    // 3. Agrega esta información al objeto JSON que se devolverá.
    json['instruction'] = instruction;
    json['pc_value'] = pcVal;
    json['status_register'] = statusVal;
    json['registers'] = <String, int>{
      for (int i = 0; i < regsList.length; i++) 'x$i': regsList[i]
    };

    json['control_signals'] = splitControl(json['Control']['value']);
 
    return json;
  }

  Map<String, dynamic> reset() {
    // 1. Resetea el simulador y obtiene el estado principal del datapath.
    // La función C++ reset() ya llama a step(), por lo que el estado
    // del datapath corresponde a la primera instrucción.
    final jsonStr = simulatorReset(_sim).toDartString();
    final json = jsonDecode(jsonStr);

    // 2. Obtiene información adicional del simulador (igual que en step()).
    final instruction = simulatorGetInstructionString(_sim).toDartString();
    final pcVal = simulatorGetPc(_sim);
    final statusVal = simulatorGetStatusRegister(_sim);
    final regsList = allRegisters;

    // 3. Agrega esta información al objeto JSON que se devolverá.
    json['instruction'] = instruction;
    json['pc_value'] = pcVal;
    json['status_register'] = statusVal;
    json['registers'] = <String, int>{
      for (int i = 0; i < regsList.length; i++) 'x$i': regsList[i]
    };

    json['control_signals'] = splitControl(json['Control']['value']);

    return json;
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

/// Desempaqueta la palabra de control de 16 bits en señales individuales.
///
/// La estructura de la palabra de control se basa en la implementación
/// de la función `controlWord` en el backend C++:
///
/// ```cpp
/// uint16_t controlWord(...) {
///     return (info->ALUctr  & 0x7) << 13 |  // 3 bits (15-13)
///            (info->ResSrc  & 0x3) << 11 |  // 2 bits (12-11)
///            (info->ImmSrc  & 0x3) << 9  |  // 2 bits (10-9)
///            (info->PCsrc   & 0x3) << 7  |  // 2 bit  (8-7)
///            (info->BRwr    & 0x1) << 6  |  // 1 bit  (6)
///            (info->ALUsrc  & 0x1) << 5  |  // 1 bit  (5)
///            (info->MemWr   & 0x1) << 4;    // 1 bit  (4)
/// }
/// ```
///
/// Nota: Los bits 0-3 y 8 no se utilizan en esta codificación.
Map<String, int> splitControl(int controlWord) {
  return {
    'ALUctr': (controlWord >> 13) & 0x7,
    'ResSrc': (controlWord >> 11) & 0x3,
    'ImmSrc': (controlWord >> 9) & 0x3,
    'PCsrc': (controlWord >> 7) & 0x3,
    'BRwr': (controlWord >> 6) & 0x1,
    'ALUsrc': (controlWord >> 5) & 0x1,
    'MemWr': (controlWord >> 4) & 0x1,
  };
}

///////////////////////////////////////////////////////////////////////////////////////

/// Implementación del servicio de simulación que usa FFI para comunicarse
/// directamente con una librería nativa (DLL/SO).
class FfiSimulationService implements SimulationService {
  late final SimulatorChatGPT simChatGPT;

  @override
  Future<void> initialize() async {
    // --- LÓGICA REAL DE FFI ---
    final libPath = Platform.isWindows ? 'simulator.dll' : 'libsimulator.so';
    try {
      _simulatorLib = DynamicLibrary.open(libPath);

      // 1. Cargar las funciones de la DLL. Esto debe hacerse DESPUÉS de abrir la librería.
      simulatorNew = _simulatorLib
          .lookup<NativeFunction<SimulatorNewNative>>('Simulator_new')
          .asFunction();
      simulatorDelete = _simulatorLib
          .lookup<NativeFunction<SimulatorDeleteNative>>('Simulator_delete')
          .asFunction();
      simulatorLoadProgram = _simulatorLib
          .lookup<NativeFunction<SimulatorLoadProgramNative>>('Simulator_load_program')
          .asFunction();
      simulatorReset = _simulatorLib
          .lookup<NativeFunction<SimulatorResetNative>>('Simulator_reset')
          .asFunction();
      simulatorStep = _simulatorLib
          .lookup<NativeFunction<SimulatorStepNative>>('Simulator_step')
          .asFunction();
      simulatorGetInstructionString = _simulatorLib
          .lookup<NativeFunction<SimulatorGetInstructionStringNative>>(
              'Simulator_get_instruction_string')
          .asFunction();
      simulatorGetPc = _simulatorLib
          .lookup<NativeFunction<SimulatorGetPcNative>>('Simulator_get_pc')
          .asFunction();
      simulatorGetStatusRegister = _simulatorLib
          .lookup<NativeFunction<SimulatorGetStatusRegisterNative>>(
              'Simulator_get_status_register')
          .asFunction();
      simulatorGetAllRegisters = _simulatorLib
          .lookup<NativeFunction<SimulatorGetAllRegistersNative>>(
              'Simulator_get_all_registers')
          .asFunction();
      simulatorGetStateJson = _simulatorLib
          .lookup<NativeFunction<SimulatorGetStateJsonNative>>('Simulator_get_state_json')
          .asFunction();
    } catch (e) {
      if (e is ArgumentError) {
        // ignore: avoid_print
        print(
            'Error: No se pudo encontrar una función en la librería "$libPath". Asegúrate de que todas las funciones (Simulator_new, Simulator_step, etc.) están exportadas correctamente.');
      } else {
        // ignore: avoid_print
        print(
            'Error: No se pudo cargar la librería desde "$libPath". La ruta es relativa al directorio de trabajo (${Directory.current.path}).');
      }
      rethrow;
    }

    // 2. Crear la instancia del simulador
    simChatGPT = SimulatorChatGPT();

    // 3. Cargar el programa en la memoria del simulador
    try {
      final programFile = File('../core/program.bin');
      if (await programFile.exists()) {
        final programData = await programFile.readAsBytes();
        simChatGPT.loadProgram(programData);
        // ignore: avoid_print
        print('Programa "program.bin" cargado en el simulador.');
      } else {
        // ignore: avoid_print
        print(
            'Advertencia: No se encontró "program.bin". Cargando un programa de prueba por defecto.');

        // Programa de prueba:
        // 0x000: 0x00100093  addi x1, x0, 1
        // 0x004: 0x00200113  addi x2, x0, 2
        // 0x008: 0x002081b3  add  x3, x1, x2
        // 0x00c: 0x0000006f  jal  x0, 0xc  ; loop forever
        final defaultProgram = Uint8List.fromList([
          0x93, 0x00, 0x10, 0x00,
          0x13, 0x01, 0x20, 0x00,
          0xb3, 0x81, 0x20, 0x00,
          0x6f, 0x00, 0x00, 0x00,
        ]);
        simChatGPT.loadProgram(defaultProgram);
      }
    } catch (e) {
      // ignore: avoid_print
      print('Error al cargar "program.bin": $e');
    }

    // ignore: avoid_print
    print("Servicio FFI inicializado (real).");
  }

  @override
  Future<SimulationState> step() async {
    final stateMap = simChatGPT.step();
    return SimulationState.fromJson(stateMap);
  }

  @override
  Future<SimulationState> reset() async {
    final stateMap = simChatGPT.reset();
    return SimulationState.fromJson(stateMap);
  }
}
