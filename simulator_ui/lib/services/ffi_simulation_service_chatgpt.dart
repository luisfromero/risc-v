import 'dart:ffi';
import 'dart:io';
import 'dart:convert';
import 'package:ffi/ffi.dart';

// Carga de la librería dinámica
final DynamicLibrary _lib = Platform.isWindows
    ? DynamicLibrary.open('simulator.dll')
    : DynamicLibrary.open('libsimulator.so'); // ajusta según tu plataforma

// -------------------------------------------
// Typedefs nativos y funciones Dart
// -------------------------------------------

typedef SimulatorNewNative = Pointer<Void> Function(Uint64 memSize, Int32 modelType);
typedef SimulatorNew = Pointer<Void> Function(int memSize, int modelType);

typedef SimulatorDeleteNative = Void Function(Pointer<Void>);
typedef SimulatorDelete = void Function(Pointer<Void>);

typedef SimulatorStepNative = Void Function(Pointer<Void>);
typedef SimulatorStep = void Function(Pointer<Void>);

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
// Carga de funciones desde la DLL
// -------------------------------------------

final SimulatorNew simulatorNew = _lib
    .lookup<NativeFunction<SimulatorNewNative>>('Simulator_new')
    .asFunction();

final SimulatorDelete simulatorDelete = _lib
    .lookup<NativeFunction<SimulatorDeleteNative>>('Simulator_delete')
    .asFunction();

final SimulatorStep simulatorStep = _lib
    .lookup<NativeFunction<SimulatorStepNative>>('Simulator_step')
    .asFunction();

final SimulatorGetInstructionString simulatorGetInstructionString = _lib
    .lookup<NativeFunction<SimulatorGetInstructionStringNative>>('Simulator_get_instruction_string')
    .asFunction();

final SimulatorGetPc simulatorGetPc = _lib
    .lookup<NativeFunction<SimulatorGetPcNative>>('Simulator_get_pc')
    .asFunction();

final SimulatorGetStatusRegister simulatorGetStatusRegister = _lib
    .lookup<NativeFunction<SimulatorGetStatusRegisterNative>>('Simulator_get_status_register')
    .asFunction();

final SimulatorGetAllRegisters simulatorGetAllRegisters = _lib
    .lookup<NativeFunction<SimulatorGetAllRegistersNative>>('Simulator_get_all_registers')
    .asFunction();

final SimulatorGetStateJson simulatorGetStateJson = _lib
    .lookup<NativeFunction<SimulatorGetStateJsonNative>>('Simulator_get_state_json')
    .asFunction();

// -------------------------------------------
// Clase Dart para usar el simulador
// -------------------------------------------

class Simulator {
  final Pointer<Void> _sim;

  Simulator({int memSize = 1024 * 1024, int modelType = 3})
      : _sim = simulatorNew(memSize, modelType);

  void dispose() {
    simulatorDelete(_sim);
  }

  void step() {
    simulatorStep(_sim);
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
