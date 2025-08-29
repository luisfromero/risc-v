import 'dart:convert';
import 'dart:ffi'; // Necesario para FFI
import 'dart:io'; // Para comprobar el sistema operativo
import 'dart:typed_data'; // Para Uint8List
import 'package:ffi/ffi.dart';
import 'package:window_manager/window_manager.dart';
import 'simulation_service.dart';
// No es necesario, toDartString viene con ffi.dart
import '../simulation_mode.dart';
import '../generated/program_data.g.dart';
import '../datapath_state.dart';

///////////////////////////////////////////////////////////////////////////////////////
//Opcion chatgpt

typedef SimulatorNewNative = Pointer<Void> Function(Uint64 memSize, Int32 modelType);
typedef SimulatorNew = Pointer<Void> Function(int memSize, int modelType);

typedef SimulatorDeleteNative = Void Function(Pointer<Void>);
typedef SimulatorDelete = void Function(Pointer<Void>);

typedef SimulatorLoadProgramNative = Void Function(Pointer<Void>, Pointer<Uint8>, IntPtr, Int32);
typedef SimulatorLoadProgram = void Function(Pointer<Void>, Pointer<Uint8>, int,int);

typedef SimulatorStepNative = Pointer<Utf8> Function(Pointer<Void>);
typedef SimulatorStep = Pointer<Utf8> Function(Pointer<Void>);

typedef SimulatorStepBackNative = Pointer<Utf8> Function(Pointer<Void>);
typedef SimulatorStepBack = Pointer<Utf8> Function(Pointer<Void>);

typedef SimulatorResetNative = Pointer<Utf8> Function(Pointer<Void>, Int32);
typedef SimulatorReset = Pointer<Utf8> Function(Pointer<Void>, int);

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

// Estructura para la memoria de instrucciones, debe coincidir con la de C++
class InstructionEntry extends Struct {
  @Uint32()
  external int value;

  @Array(256)
  external Array<Uint8> _instructionBytes;
}

// Typedefs para la nueva función de memoria de instrucciones
typedef SimulatorGetIMemNative = IntPtr Function(
    Pointer<Void>, Pointer<InstructionEntry>, IntPtr);
typedef SimulatorGetDMemNative = IntPtr Function(
    Pointer<Void>, Pointer<Uint8>, IntPtr);
typedef SimulatorGetIMem = int Function(
    Pointer<Void>, Pointer<InstructionEntry>, int);
typedef SimulatorGetDMem = int Function(
    Pointer<Void>, Pointer<Uint8>, int);

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
late final SimulatorStepBack simulatorStepBack;
late final SimulatorGetInstructionString simulatorGetInstructionString;
late final SimulatorGetPc simulatorGetPc;
late final SimulatorGetStatusRegister simulatorGetStatusRegister;
late final SimulatorGetAllRegisters simulatorGetAllRegisters;
late final SimulatorGetStateJson simulatorGetStateJson;
late final SimulatorGetIMem simulatorGetIMem;
late final SimulatorGetDMem simulatorGetDMem;

// -------------------------------------------
// Clase Dart para usar el simulador
// -------------------------------------------

class Simulador {
  final Pointer<Void> _sim;

  Simulador({int memSize = 1024 * 1024, int modelType = 3})
      : _sim = simulatorNew(memSize, modelType);

  void dispose() {
    simulatorDelete(_sim);
  }

  List<InstructionMemoryItem> getInstructionMemory() {
    // 1. Primera llamada para obtener el número de instrucciones.
    final count = simulatorGetIMem(_sim, nullptr, 0);
    if (count == 0) {
      return [];
    }

    // 2. Alojar memoria y hacer la segunda llamada para obtener los datos.
    final buffer = calloc<InstructionEntry>(count);
    simulatorGetIMem(_sim, buffer, count);

    // 3. Convertir el buffer de C a una lista de Dart.
    final instructionList = <InstructionMemoryItem>[];
    for (int i = 0; i < count; i++) {
      final entryPtr = buffer+i;
      // El offset de 'instruction' es 4 bytes (después de 'value' de 32 bits).
      final instructionPtr = Pointer<Utf8>.fromAddress(entryPtr.address + 4);
      instructionList.add(InstructionMemoryItem(
        value: entryPtr.ref.value,
        instruction: instructionPtr.toDartString(),
      ));
    }
    calloc.free(buffer);
    return instructionList;
  }

  Uint8List getDataMemory() {
    final buffer = calloc<Uint8>(256);
    try {
      simulatorGetDMem(_sim, buffer, 256);
      // asTypedList crea una vista de la memoria C. fromList crea una copia en Dart.
      return Uint8List.fromList(buffer.asTypedList(256));
    } finally {
      // Es crucial liberar la memoria que alojamos manualmente.
      calloc.free(buffer);
    }
  }




  void loadProgram(Uint8List programData, int mode) {
    final buffer = calloc<Uint8>(programData.length);
    buffer.asTypedList(programData.length).setAll(0, programData);
    simulatorLoadProgram(_sim, buffer, programData.length,mode);
    calloc.free(buffer);
  }

  /// Método auxiliar para enriquecer el JSON base del simulador con datos adicionales.
  Map<String, dynamic> _getFullState(String jsonStr) {
    final json = jsonDecode(jsonStr);

    // Obtiene información adicional del simulador.
    final instruction = simulatorGetInstructionString(_sim).toDartString();
    final pcVal = simulatorGetPc(_sim);
    final statusVal = simulatorGetStatusRegister(_sim);
    final regsList = allRegisters;

    // Agrega esta información al objeto JSON.
    json['instruction'] = instruction;
    json['pc'] = pcVal; // La UI espera 'pc', no 'pc_value'.
    json['status_register'] = statusVal;
    json['registers'] = <String, int>{
      for (int i = 0; i < regsList.length; i++) 'x$i': regsList[i]
    };
 
    return json;
  }

  Map<String, dynamic> step() {
    try {
      final json = simulatorStep(_sim);
      final jsonStr = json.toDartString();
      return _getFullState(jsonStr);
    } catch (e) {
      // ignore: avoid_print
      print("Error during FFI step call: $e");
      rethrow;
    }
  }

  Map<String, dynamic> stepBack() {
    try {
      final json = simulatorStepBack(_sim);
      final jsonStr = json.toDartString();
      return _getFullState(jsonStr);
    } catch (e) {
      // ignore: avoid_print
      print("Error during FFI step_back call: $e");
      rethrow;
    }
  }

  Map<String, dynamic> reset(int mode) {
    try {
      final jsonStr = simulatorReset(_sim, mode).toDartString();
      
      return _getFullState(jsonStr);
    } catch (e) {
      // ignore: avoid_print
      print("Error during FFI reset call: $e");
      rethrow;
    }
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
  late final Simulador simulador;
    SimulationState? _currentState;


  @override
  Future<SimulationState> getInstructionMemory() async {
   var stateMap = simulador.state;
   var iMem = simulador.getInstructionMemory();
   return SimulationState.fromJson(stateMap).copyWith(instructionMemory: iMem);
  }

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
          // Nota: He cambiado el nombre para no romper la función original.
          .lookup<NativeFunction<SimulatorResetNative>>('Simulator_reset_with_model')
          .asFunction();
      simulatorStep = _simulatorLib
          .lookup<NativeFunction<SimulatorStepNative>>('Simulator_step')
          .asFunction();
      simulatorStepBack = _simulatorLib
          .lookup<NativeFunction<SimulatorStepBackNative>>('Simulator_step_back')
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
      simulatorGetIMem = _simulatorLib
          .lookup<NativeFunction<SimulatorGetIMemNative>>('Simulator_get_i_mem')
          .asFunction();
      simulatorGetDMem = _simulatorLib
          .lookup<NativeFunction<SimulatorGetDMemNative>>('Simulator_get_d_mem')
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
    simulador = Simulador();

    // 3. Cargar el programa en la memoria del simulador
    try {
      final programFile = File('../core/program.bin');
      if (await programFile.exists()) {
        final programData = await programFile.readAsBytes();
        simulador.loadProgram(programData,0);
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
        final defaultProgramOld = Uint8List.fromList([
          0x93, 0x00, 0x10, 0x00,
          0x13, 0x01, 0x20, 0x00,
          0xb3, 0x81, 0x20, 0x00,
          0x6f, 0x00, 0x00, 0x00,
        ]);


        // --- Programa de prueba por defecto ---
        // Contiene instrucciones R, I, S, B (taken y not taken) y J.
        // 0x00400000: addi x1, x0, 10
        // 0x00400004: lui  x2, 0x10010
        // 0x00400008: sw   x1, 0(x2)
        // 0x0040000c: lw   x3, 0(x2)
        // 0x00400010: add  x4, x1, x3
        // 0x00400014: add  x5, x1, x3
        // 0x00400018: beq  x0, x1, +12  ; branch_fail (NOT TAKEN)
        // 0x0040001c: addi x6, x0, 100
        // 0x00400020: beq  x4, x5, +8   ; branch_success (TAKEN)
        // 0x00400024: branch_fail: addi x7, x0, 200
        // 0x00400028: branch_success: addi x8, x0, 300
        // 0x0040002c: jal  x0, -44      ; loop to start
        Uint8List defaultProgram = Uint8List.fromList([
          0x93, 0x00, 0xA0, 0x00, // 0x00A00093
          0x13, 0x01, 0x40, 0x01, // 0x01400113
          0x23, 0x20, 0x11, 0x00, // 0x00112023
          0x83, 0x21, 0x01, 0x00, // 0x00012183
          0x37, 0x11, 0x40, 0x00, // 
          0x33, 0x02, 0x30, 0x00, // 0x00308233
          0xb3, 0x82, 0x30, 0x00, // 0x003082b3
          0x63, 0x06, 0x10, 0x00, // 0x00100663
          0x13, 0x03, 0x40, 0x06, // 0x06400313
          0x63, 0x04, 0x52, 0x00, // 0x00520463
          0x93, 0x03, 0x80, 0x0C, // 0x0C800393
          0x13, 0x04, 0xC0, 0x12, // 0x12C00413
          0x6F, 0xF0, 0x5F, 0xFD, // 0xFD5FF06F
        ]);
        defaultProgram = Uint8List.fromList(defaultProgramD);
        
          
        simulador.loadProgram(defaultProgram,0);
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
    final stateMap = simulador.step(); //Llamamos a la dll
    var state= SimulationState.fromJson(stateMap);
    var dMem= simulador.getDataMemory(); //llamamos a la dll. No merece la pena ahorrar y hacerlo solo con sw, ya que no es via api
    //pero se podría fácilmente hacer
    state=state.copyWith(dataMemory: dMem);
    return state;
  }

  @override
  Future<SimulationState> stepBack() async {
    final stateMap = simulador.stepBack();
    var state= SimulationState.fromJson(stateMap);
    var dMem= simulador.getDataMemory(); //llamamos a la dll. No merece la pena ahorrar y hacerlo solo con sw, ya que no es via api
    //pero se podría fácilmente hacer
    state=state.copyWith(dataMemory: dMem);
    return state;
  }
// ffi_simulation_service.dart

  @override
  Future<SimulationState> reset({required SimulationMode mode}) async {
    final stateMap = simulador.reset(mode.index);
    final initialState = SimulationState.fromJson(stateMap);
    
    // Obtenemos las memorias por separado
    final iMem = simulador.getInstructionMemory();
    final dMem = simulador.getDataMemory();

    // Creamos el estado completo combinando todo
    final fullState = initialState.copyWith(instructionMemory: iMem, dataMemory: dMem);

    // Guardamos el estado completo en nuestra variable de instancia
    _currentState = fullState;

    // Devolvemos el estado que acabamos de guardar
    return _currentState!;
  }

// ffi_simulation_service.dart

@override
Future<SimulationState> getDataMemory() async {
  // Primero, comprobamos que el estado ya se haya inicializado con reset()
  if (_currentState == null) {
    throw Exception(
        "El estado del simulador no está inicializado. Llama a reset() primero.");
  }
  
  // Obtenemos ÚNICAMENTE la memoria de datos actualizada desde la DLL
  final newDMem = simulador.getDataMemory();
  
  // Usamos copyWith para crear un nuevo estado que es idéntico al anterior,
  // pero con la memoria de datos actualizada.
  _currentState = _currentState!.copyWith(dataMemory: newDMem);
  
  // Devolvemos el estado recién actualizado.
  return _currentState!;
}
}
