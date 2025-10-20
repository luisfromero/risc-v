import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';

import 'generated/control_table.g.dart';
import 'execution_history_manager.dart';
import 'services/simulation_service.dart';
import 'simulation_mode.dart';
import 'geometry.dart';
part 'animations.dart';

class ExecutionRecord {
  final int pc;
  final String instruction;
  bool isActive;
  Color color;

  ExecutionRecord({
    required this.pc,
    required this.instruction,
    this.isActive = true,
    this.color = Colors.transparent,
  });
}

class InstructionMemoryItem {
  final int address;
  final int value;
  final String instruction;

  // El constructor ahora requiere la dirección.
  InstructionMemoryItem({required this.address, required this.value, required this.instruction});

  factory InstructionMemoryItem.fromJson(Map<String, dynamic> json) {
    return InstructionMemoryItem(
      address: 0,// La dirección se asignará en el servicio.
      value: json['value'],
      instruction: json['instruction'],
    );
  }
}

/// Comunica la "causa" de una actualización de estado desde `DatapathState`
/// hacia `ExecutionHistoryManager`. Esto permite al gestor del historial saber
/// cómo debe modificar su log (añadir un registro, quitarlo, borrar todo, etc.).
enum CAUSAS {
  STEP, // Causa genérica para cualquier avance que no sea micro-ciclo
  RESET,
  STEPBACK,
  STEP_MICRO,
  STEPBACK_MICRO
}

int indeterminado=0xdeadbeef;


String toHex(int? value, [int digits=8,bool no0x=false]) {
  // Aplicamos una máscara para obtener la representación en complemento a dos de 32 bits,
  // que es lo que `toRadixString` necesita para números negativos.
  value ??= indeterminado;
  final prefix=no0x?'':'0x';
  if(value==0xdeadbeef) return '??';
  return '$prefix${(value & 0xFFFFFFFF).toRadixString(16).padLeft(digits, '0').toUpperCase()}';
}

/// Un punto de conexión con una etiqueta y una posición global.
class ConnectionPoint {
  final String label;
  final Offset position; // Posición local relativa al área del painter (el Stack)

  ConnectionPoint(this.label, this.position);
}

/// Contiene la información necesaria para mostrar un tooltip sobre un bus.
class BusHoverInfo {
  final Path path; // El trazado del bus para hit-testing preciso.
  final Rect bounds; // El rectángulo que envuelve al bus para una detección rápida.
  final String tooltip; // El texto que se mostrará.
  final double strokeWidth; // El grosor del bus, para un hit-testing más preciso.

  BusHoverInfo(
      {required this.path,
      required this.bounds,
      required this.tooltip,
      required this.strokeWidth});
}

/// Define la estructura de un bus de conexión en el datapath.
class Bus {
  final String startPointLabel; // Etiqueta del punto de inicio (ej: 'PC-1')
  final String endPointLabel;   // Etiqueta del punto final (ej: 'IM-0')
  final List<Offset> waypoints; // Mantenemos la lista fija para compatibilidad.
  final List<Offset> Function(DatapathState)? waypointsBuilder; // Y añadimos el builder dinámico.
  bool Function(DatapathState) isActive; // Función para determinar si está activo
  String? valueKey; // Clave para buscar el valor en el mapa de buses (ej: 'pc_bus')
  bool Function(DatapathState) isHidden; // NUEVO: Función para determinar si el bus debe ocultarse por completo.
  final int width;
  final int size; // Ancho en bits del bus (ej: 32)
  final bool isControl;
  final bool isState;
  final bool isForwardingBus; // NUEVO: Indica si es un bus de forwarding.
  final bool isBranchHazardBus; // NUEVO: Indica si es un bus de branch hazard.
  final bool isLoadHazardBus; // NUEVO: Indica si es un bus de load hazard.
  final Color? color; // NUEVO: Color personalizado para el bus.

  Bus({
    required this.startPointLabel,
    required this.endPointLabel,
    List<Offset>? waypoints,
    this.waypointsBuilder,
    required this.isActive,
    bool Function(DatapathState)? isHidden,
    this.valueKey,
    this.width = 3,
    this.size = 32,
    this.isControl = false,
    this.isState = false,
    this.isForwardingBus = false,
    this.isBranchHazardBus = false,
    this.isLoadHazardBus = false,
    this.color,
  })  : waypoints = waypoints ?? [], // Inicializamos la lista fija.
        isHidden = isHidden ?? ((s) => false);
}





// Clase para representar una entrada en la memoria de instrucciones


// ChangeNotifier nos permite "notificar" a los widgets cuando algo cambia.
class DatapathState extends ChangeNotifier {
  // Dependencia del servicio de simulación. No sabe si es FFI o API.
  final SimulationService _simulationService;
  DatapathState(this._simulationService);

  // --- ESTADO DEL MODO DE SIMULACIÓN ---
  SimulationMode _simulationMode = SimulationMode.singleCycle;
  SimulationMode get simulationMode => _simulationMode;

  // --- HISTORIAL DE EJECUCIÓN ---
  final ExecutionHistoryManager historyManager = ExecutionHistoryManager();
  List<ExecutionRecord> get executionHistory => historyManager.history;

  // --- ESTADO DE LA SIMULACIÓN (TIMING) ---
  int _criticalTime = 100;      // Tiempo total del ciclo, para el slider.
  Map<String, int> _readyAt = {};
  // --- Estado para Multiciclo ---
  int _currentMicroCycle = 0;
  int _totalMicroCycles = 0;


  Map<String, bool> _activePaths = {};

  // --- ESTADO DEL DATAPATH ---
  bool _isPcAdderActive = false;
  bool _isBranchAdderActive = false;
  bool _isAluActive = false;
  bool _isMuxCActive = false;
  bool _isMux2Active = false;
  bool _isMux3Active = false;
  bool _isIMemActive = false;
  bool _isDMemActive = false;
  bool _isRegFileActive = false;
  bool _isExtenderActive = false;
  bool _isIBActive = false; 
  bool _isPCActive = false;

  bool _isControlActive = false; 
  bool _isPCsrcActive = false;


  bool _isLoadHazard = false;
  bool _isBranchHazard = false;
  // --- GlobalKeys para el layout de los buses ---
  final pcKey = GlobalKey();
  final pcAdderKey = GlobalKey();
  final branchAdderKey = GlobalKey();
  final aluKey = GlobalKey();
  final muxCKey = GlobalKey();
  final mux2Key = GlobalKey();
  final mux3Key = GlobalKey();
  final muxFWAKey = GlobalKey();
  final muxFWBKey = GlobalKey();
  final muxFWMKey = GlobalKey();
  final instructionMemoryKey = GlobalKey();
  final dataMemoryKey = GlobalKey();
  final registerFileKey = GlobalKey();
  final controlUnitKey = GlobalKey();
  final extenderKey = GlobalKey();
  final loadHazardUnitKey = GlobalKey();
  final branchHazardUnitKey = GlobalKey();
  final forwardingUnitKey = GlobalKey();


  final stackKey = GlobalKey();
  final ibKey = GlobalKey();

  final pipereg_fd0_Key = GlobalKey();
  final pipereg_fd1_Key = GlobalKey();

  final pipereg_de0_Key = GlobalKey();
  final pipereg_em0_Key = GlobalKey();
  final pipereg_mw0_Key = GlobalKey();
  final pipereg_de1_Key = GlobalKey();
  final pipereg_de2_Key = GlobalKey();
  final pipereg_b_Key = GlobalKey();

  final pipereg_em1_Key = GlobalKey();
  final pipereg_mw1_Key = GlobalKey();

    final pipereg_deControl_Key = GlobalKey();
    final pipereg_emControl_Key = GlobalKey();
    final pipereg_mwControl_Key = GlobalKey();


  // --- ESTADO DEL LAYOUT ---
  Map<String, ConnectionPoint> _connectionPoints = {};
  Map<String, ConnectionPoint> get connectionPoints => _connectionPoints;

  // --- ESTADO DEL HOVER DE BUSES ---
  List<BusHoverInfo> _busHoverInfoList = [];
  List<BusHoverInfo> get busHoverInfoList => _busHoverInfoList;
  
  // --- ESTADO DE LOS VALORES ---

  int _pcValue = 0x00400000;
  int current_pc = 0;
  int _initial_pc = 0;
  set initial_pc(int value) {_initial_pc = value;}

  String _instruction = "c.unimp";
  int _instructionValue = 0;
  int _statusRegister = 0;
  Map<String, int> _registers = {};
  Map<String, int> _busValues = {};

  // --- Pipeline Instruction Strings ---
  String _pipeIfInstruction = "c.unimp";
  String _pipeIdInstruction = "c.unimp";
  String _pipeExInstruction = "c.unimp";
  String _pipeMemInstruction = "c.unimp";
  String _pipeWbInstruction = "c.unimp";

  // --- Pipeline Instruction Info ---
  InstructionInfo _pipeIfInstructionInfo = InstructionInfo();
  InstructionInfo _pipeIdInstructionInfo = InstructionInfo();
  InstructionInfo _pipeExInstructionInfo = InstructionInfo();
  InstructionInfo _pipeMemInstructionInfo = InstructionInfo();
  InstructionInfo _pipeWbInstructionInfo = InstructionInfo();
  InstructionInfo _instructionInfo = InstructionInfo();

  // final Map<String,int> _control_signals={};

  // --- DEFINICIÓN DE BUSES ---
  // La lista de buses ahora es variable y se actualiza según el modo.
  List<Bus> _buses = [];
  List<Bus> get buses => _buses;

  String _hoverInfo = ""; // El texto final que se muestra en el
  bool _isHoveringBus = false; // Para gestionar la prioridad del tooltip del bus.
  double _sliderValue = 0.0; // Nuevo estado para el slider.
  Offset _mousePosition = Offset.zero; // Para las coordenadas del ratón
  bool _showConnectionLabels = false;
  bool _showBusesLabels = true;
  bool _showControl = true;
  bool _showForwarding = false;
  bool _showLHU = false;
  bool _showBHU = false;
  bool _showStaticCodeView = false; // Por defecto, mostramos la vista dinámica (hilo)
  bool _hazardsEnabled = true; // Nuevo estado para controlar los riesgos


  // --- GESTIÓN DE ANIMACIONES Y BREAKPOINTS ---


    // --- ESTADO PARA PLAY/PAUSE (FRONTEND) ---
  bool _isPlaying = false;
  Timer? _timer;

  // --- ESTADO PARA BREAKPOINTS ---
  final Set<int> _breakpoints = {};

  // --- ESTADO PARA DETECCIÓN DE BUCLE ---

  bool hasBreakpoint(int address) => _breakpoints.contains(address);

  void toggleBreakpoint(int address) {
    if (_breakpoints.contains(address)) _breakpoints.remove(address);
    else _breakpoints.add(address);
    notifyListeners(); // Notifica a la UI para que redibuje el punto del breakpoint
  }


  List<InstructionMemoryItem>? instructionMemory;
  Uint8List? dataMemory;

  // --- GETTERS (para que los widgets lean el estado) ---
  String get instruction => _instruction;
  int get instructionValue => _instructionValue;
  int get statusRegister => _statusRegister;
  Map<String, int> get registers => _registers;
  Map<String, int> get busValues => _busValues;
  Map<String, bool> get activePaths => _activePaths;

  String get pipeIfInstruction => _pipeIfInstruction;
  String get pipeIdInstruction => _pipeIdInstruction;
  String get pipeExInstruction => _pipeExInstruction;
  String get pipeMemInstruction => _pipeMemInstruction;
  String get pipeWbInstruction => _pipeWbInstruction;

  // --- Getters for Instruction Info ---
  InstructionInfo get instructionInfo => _instructionInfo;
  InstructionInfo get pipeIfInstructionInfo => _pipeIfInstructionInfo;
  InstructionInfo get pipeIdInstructionInfo => _pipeIdInstructionInfo;
  InstructionInfo get pipeExInstructionInfo => _pipeExInstructionInfo;
  InstructionInfo get pipeMemInstructionInfo => _pipeMemInstructionInfo;
  InstructionInfo get pipeWbInstructionInfo => _pipeWbInstructionInfo;

  bool get isPcAdderActive => _isPcAdderActive;
  bool get isBranchAdderActive => _isBranchAdderActive;
  bool get isAluActive => _isAluActive;
  bool get isMuxCActive => _isMuxCActive;
  bool get isMux2Active => _isMux2Active;
  bool get isMux3Active => _isMux3Active;

bool get isIMemActive => _isIMemActive;
bool get isDMemActive => _isDMemActive;
bool get isRegFileActive => _isRegFileActive;
bool get isExtenderActive => _isExtenderActive;
bool get isIBActive => _isIBActive;
bool get isPCActive => _isPCActive;

bool get isControlActive => _isControlActive;
bool get isPCsrcActive => _isPCsrcActive;

bool get isLoadHazard => _isLoadHazard;
bool get isBranchHazard => _isBranchHazard;

  int get pcValue => _pcValue;
  String get hoverInfo => _hoverInfo;
  double get sliderValue => _sliderValue;
  int get criticalTime => _criticalTime;

  int get currentMicroCycle => _currentMicroCycle;
  int get totalMicroCycles => _totalMicroCycles;

  Offset get mousePosition => _mousePosition;
  bool get showConnectionLabels => _showConnectionLabels;
  bool get showBusesLabels => _showBusesLabels;
  bool get showControl => _showControl;
  bool get showForwarding => _showForwarding;
  bool get showLHU => _showLHU;
  bool get showBHU => _showBHU;
  bool get showStaticCodeView => _showStaticCodeView;
  bool get hazardsEnabled => _hazardsEnabled;
  Set<int> get breakpoints => _breakpoints;
  bool get isPlaying => _isPlaying;


  int get initial_pc => _initial_pc;




  // Inicializa el estado pidiendo los valores iniciales al servicio.
  Future<void> initialize() async {
    try {
      await _simulationService.initialize();
      _updateBuses();
      final initialState = await _simulationService.reset(mode: _simulationMode,initial_pc: 0);
      // Al inicializar, ponemos el slider al final para mostrar el estado completo.

      //Aqui actualizamos las direcciones segun initial_state 

      _sliderValue = initialState.criticalTime.toDouble();
      historyManager.cause=CAUSAS.RESET;
      _updateState(initialState, clearHover: true);
      // Nos aseguramos de que el layout esté construido antes de calcular las posiciones.
      WidgetsBinding.instance.addPostFrameCallback((_) => updateLayoutMetrics());
    } catch (e) {
      // ignore: avoid_print
      print("Error durante la inicialización del simulador: $e");
      // Aquí podrías establecer un estado de error para mostrarlo en la UI.
    }
  }

  // --- MÉTODOS PARA MODIFICAR EL ESTADO ---

  /// Actualiza la lista de información de hover de los buses.
  void setBusHoverInfoList(List<BusHoverInfo> newList) {
    // No es necesario notificar a los listeners aquí, ya que esta lista
    // se usa en el siguiente frame para el hit-testing, no para redibujar
    // un widget directamente. Se actualizará en el próximo `paint` de todas formas.
    _busHoverInfoList = newList;
  }

  // Actualiza el modo de simulación.
  void setSimulationMode(SimulationMode? newMode) {
    if (newMode != null && _simulationMode != newMode) {
      _simulationMode = newMode;
      _updateBuses(); // ¡La clave! Regenera los buses para el nuevo modo.
      // ignore: avoid_print
      pause(); // Detenemos la reproducción automática si se estaba ejecutando.
      _breakpoints.clear(); // Limpiamos los breakpoints al cambiar de modo.
      print("Cambiando a modo: $newMode");
      notifyListeners();
      reset(); // Opcional: resetea la simulación al cambiar de modo.
      // Actualiza el layout después de cambiar el modo y resetear
      WidgetsBinding.instance.addPostFrameCallback((_) => updateLayoutMetrics());
    }
  }

  void setShowConnectionLabels(bool? value) {
    if (value != null && _showConnectionLabels != value) {
      _showConnectionLabels = value;
      notifyListeners();
    }
  }
  void setShowBusesLabels(bool? value) {
    if (value != null && _showBusesLabels != value) {
      _showBusesLabels = value;
      notifyListeners();
    }
  }
  void setControlVisibility(bool? value) {
    if (value != null && _showControl != value) {
      _showControl = value;
      notifyListeners();
    }
  }
  void setForwardingVisibility(bool? value) {
    if (value != null && _showForwarding != value) {
      _showForwarding = value;
      if (value) {
        _showLHU = false;
        _showBHU = false;
      }
      notifyListeners();  
    }
  }
  
  void setStaticCodeView(bool? value) {
    if (value != null && _showStaticCodeView != value) {
      _showStaticCodeView = value;
      notifyListeners();
    }
  }
  void setShowLHU(bool? value) {
    if (value != null && _showLHU != value) {
      _showLHU = value;
      if (value) {
        _showForwarding = false;
        _showBHU = false;
      }
      notifyListeners();  
    }
  }
  void setShowBHU(bool? value) {
    if (value != null && _showBHU != value) {
      _showBHU = value;
      if (value) {
        _showForwarding = false;
        _showLHU = false;
      }
      notifyListeners();  
    }
  }

  void setHazardsEnabled(bool? value) {
    if (value != null && _hazardsEnabled != value) {
      _hazardsEnabled = value;
      notifyListeners();
      // Opcional: resetear al cambiar para que el cambio tenga efecto inmediato.
      reset();
    }
  }


  // Simula la ejecución de un ciclo de reloj
  Future<void> step() async {
    if (_simulationMode == SimulationMode.multiCycle && _totalMicroCycles > 0) {
      _currentMicroCycle++;
      if (_currentMicroCycle >= _totalMicroCycles) {
        // Si completamos los micro-ciclos, pedimos la siguiente instrucción.
        final newState = await _simulationService.step(); 
        historyManager.cause=CAUSAS.STEP;
        _updateState(newState); // Esto resetea _currentMicroCycle a 0 y actualiza el estado.
      } else {
        // Si solo avanzamos un micro-ciclo, actualizamos la vista sin llamar al backend.
        _evaluateActiveComponents();
        historyManager.cause=CAUSAS.STEP_MICRO;
        historyManager.update(this);
        notifyListeners();
      }
    } else {
      // Lógica para monociclo o para el primer paso de multiciclo
      try {

        final newState = await _simulationService.step(); 
        print("Ejecutado step()  ");
        print(newState);
        _sliderValue=newState.criticalTime.toDouble();
        historyManager.cause=CAUSAS.STEP;
        _updateState(newState);
                // --- Lógica de historial ---

      } catch (e) {
        // ignore: avoid_print
        print("Error during step: $e");
      }
    }
  }

  // Retrocede un ciclo de reloj.
  Future<void> stepBack() async {
    // En multiciclo, si no estamos en el primer microciclo, simplemente
    // retrocedemos uno localmente para la visualización.
    if (_simulationMode == SimulationMode.multiCycle && _currentMicroCycle > 0) {
      _currentMicroCycle--;
      _evaluateActiveComponents();
      historyManager.cause=CAUSAS.STEPBACK_MICRO;
      historyManager.update(this);
      notifyListeners();
    } else {
      // Para monociclo, pipeline, o al inicio de una instrucción multiciclo,
      // llamamos al backend para que restaure el estado anterior completo.
      try {
        // --- Lógica de historial ---
        final newState = await _simulationService.stepBack();
        _sliderValue = newState.criticalTime.toDouble();
        historyManager.cause=CAUSAS.STEPBACK;
        _updateState(newState);
      } catch (e) {
        // ignore: avoid_print
        print("Error during stepBack: $e");
      }
    }
  }

  // Resetea el estado a sus valores iniciales.
  Future<void> reset({int initial_pc = 0, String? assemblyCode, Uint8List? binCode}) async {
    final newState = await _simulationService.reset(
        mode: _simulationMode, 
        initial_pc: initial_pc, 
        assemblyCode: assemblyCode, 
        binCode: binCode,
        hazardsEnabled: _hazardsEnabled); // Pasamos el nuevo estado
    print("Ejecutado reset() con modo: $_simulationMode");
    //newState.copyWith(initial_pc: initial_pc);
    _sliderValue = 0.0;
    _sliderValue=newState.criticalTime.toDouble();
    pause(); // Detenemos la reproducción automática al resetear.
    _breakpoints.clear(); // Limpiamos los breakpoints al resetear.

    // --- Lógica de historial ---
    historyManager.cause=CAUSAS.RESET;
    _updateState(newState, clearHover: true);
    
  }

  // Ejecuta la simulación hasta que se encuentre un breakpoint de la lista.
  Future<void> run() async {
    // Si no hay breakpoints, simplemente ejecuta un paso.
    if (_breakpoints.isEmpty) {
      await step();
      return;
    }

    // Si hay breakpoints, pasa la lista completa al backend.
    // El backend se encargará de parar en el primero que encuentre.
      try {
      final newState = await _simulationService.runUntil(_breakpoints.toList());
        _sliderValue = newState.criticalTime.toDouble();
        historyManager.cause = CAUSAS.STEP; // Lo tratamos como un 'step' grande
        _updateState(newState);
      } catch (e) {
        print("Error during runUntil: $e");
      }
  }
  // Método privado para centralizar la actualización del estado de la UI.
  void _updateState(SimulationState simState, {bool clearHover = false}) {
    _instruction = simState.instruction;
    _initial_pc = simState.initial_pc;
    _instructionValue = simState.instructionValue;
    _statusRegister = simState.statusRegister;
    _registers = simState.registers;
    _pcValue = simState.pcValue;
    _readyAt = simState.readyAt;
    _activePaths = simState.activePaths;
    // --- Actualización de estado para Multiciclo ---
    _totalMicroCycles = simState.totalMicroCycles;
    _currentMicroCycle = 0; // Siempre empezamos en el micro-ciclo 0 de una nueva instrucción.
    _busValues = simState.busValues;
    _criticalTime = simState.criticalTime > 0 ? simState.criticalTime : 100;

    _pipeIfInstruction = simState.pipeIfInstructionCptr;
    _pipeIdInstruction = simState.pipeIdInstructionCptr;
    _pipeExInstruction = simState.pipeExInstructionCptr;
    _pipeMemInstruction = simState.pipeMemInstructionCptr;
    _pipeWbInstruction = simState.pipeWbInstructionCptr;

    // Actualizamos la información decodificada de cada instrucción en el pipeline.
    _instructionInfo = InstructionInfo.fromInstruction(_instructionValue);
    _pipeIfInstructionInfo = InstructionInfo.fromInstruction(simState.pipeIfInstructionValue);
    _pipeIdInstructionInfo = InstructionInfo.fromInstruction(simState.pipeIdInstructionValue);
    _pipeExInstructionInfo = InstructionInfo.fromInstruction(simState.pipeExInstructionValue);
    _pipeMemInstructionInfo = InstructionInfo.fromInstruction(simState.pipeMemInstructionValue);
    _pipeWbInstructionInfo = InstructionInfo.fromInstruction(simState.pipeWbInstructionValue);

    _isLoadHazard = simState.isLoadHazard;
    _isBranchHazard = simState.isBranchHazard;

  
    if(simState.instructionMemory!=null) {
      // El estado viene con la memoria de instrucciones (probablemente desde reset()).
      // Este es el lugar centralizado para enriquecer la lista con las direcciones.
      final rawIMem = simState.instructionMemory!;
      final enrichedIMem = [
        for (int i = 0; i < rawIMem.length; i++)
          InstructionMemoryItem(address: simState.initial_pc + (i * 4), value: rawIMem[i].value, instruction: rawIMem[i].instruction)
      ];
      instructionMemory = enrichedIMem;
    }

    //Solo algunos steps vienen con la memoria de datos
    if(simState.dataMemory!=null) {
      //En ciclos posteriores, el estado viene sin las instrucciones. No perdemos la que vino con reset
      dataMemory= simState.dataMemory;
    }

    current_pc = simState.busValues['pc_bus']??0;
    
    // --- Depuración: Imprime el tiempo crítico recibido ---
    // ignore: avoid_print
    print('Nuevo tiempo crítico recibido: $_criticalTime');
    print('Nuevo tiempo crítico recibido: $_readyAt');

    _evaluateActiveComponents();
    // print("Evaluated active components with readyAt: $_readyAt"); // Opcional para depuración
    if (clearHover) _hoverInfo = "";
            
    historyManager.update(this);

    notifyListeners();
  }

  // Actualiza el texto del hover
  void setHoverInfo(String info) {
    // Si el ratón se mueve desde un área vacía a un widget,
    // y un bus ya tiene el hover, no hacemos nada. El bus tiene prioridad.
    if (_isHoveringBus && info.isNotEmpty) {
      return;
    }

    // Si el ratón sale de un widget (info vacía), reseteamos el flag del bus.
    // Esto permite que setMousePosition pueda detectar un bus si el ratón
    // se mueve de un widget a un bus.
    if (info.isEmpty) {
      _isHoveringBus = false;
    }

    _hoverInfo = info;
    notifyListeners();
  }

  // Actualiza la posición del ratón
  void setMousePosition(Offset position) {
    _mousePosition = position;

    // --- Lógica de detección de hover en buses ---
    // Buscamos de atrás hacia adelante para que los buses dibujados encima tengan prioridad.
    for (final bus in _busHoverInfoList.reversed) {
      // Usamos el `bounds` que ya está inflado para una detección rápida.
      if (bus.bounds.contains(position)) {
        _hoverInfo = bus.tooltip;
        _isHoveringBus = true;
        notifyListeners();
        return; // Encontramos un bus, no necesitamos seguir buscando.
      }
    }

    // Si salimos del bucle sin encontrar un bus, pero el estado anterior
    // era un hover de bus, limpiamos la información.
    if (_isHoveringBus) {
      _hoverInfo = "";
      _isHoveringBus = false;
    }

    notifyListeners();
  }

  // Actualiza el valor del slider.
  void setSliderValue(double value) {
    // Redondeamos para evitar problemas de precisión con punto flotante.
    _sliderValue = value.roundToDouble();
    _evaluateActiveComponents();
    notifyListeners();
  }

  // --- LÓGICA INTERNA ---

  /// Recopila todos los `connectionPoints` de los widgets del datapath y los
  /// convierte en un mapa de puntos con coordenadas globales y etiquetas.
  /// Este método debe ser llamado después de que el layout se haya construido.
  void updateLayoutMetrics() {
    final List<ConnectionPoint> allPoints = [];

    // Obtenemos el RenderBox del Stack para poder convertir coordenadas
    // globales (de pantalla) a locales (relativas al Stack).
    final stackContext = stackKey.currentContext;
    if (stackContext == null) return;
    final stackBox = stackContext.findRenderObject() as RenderBox;

    // Helper para no repetir código.
    void extractPoints(GlobalKey key, String labelPrefix) {
      final context = key.currentContext;
      final widget = key.currentWidget;
      if (context == null || widget == null) return;

      final box = context.findRenderObject() as RenderBox;
      // 1. Obtenemos la posición global del widget (relativa a la pantalla).
      final globalPosition = box.localToGlobal(Offset.zero);
      // 2. La convertimos a una posición local (relativa a nuestro Stack).
      final localPosition = stackBox.globalToLocal(globalPosition);
      final size = box.size;

      // Usamos 'dynamic' para acceder a 'connectionPoints' sin tener que
      // hacer un cast para cada tipo de widget.
      final List<Offset> relativePoints = (widget as dynamic).connectionPoints;

      for (int i = 0; i < relativePoints.length; i++) {
        final relativePoint = relativePoints[i];
        // Calcula el punto de conexión final sumando el offset relativo a la posición local del widget.
        final finalPoint = localPosition +
            Offset(relativePoint.dx * size.width, relativePoint.dy * size.height);
        allPoints.add(ConnectionPoint('$labelPrefix-$i', finalPoint));
      }
    }

    // Extraemos los puntos de cada componente.
    extractPoints(pcKey, 'PC');
    extractPoints(pcAdderKey, 'NPC');
    extractPoints(branchAdderKey, 'BR');
    extractPoints(aluKey, 'ALU');
    extractPoints(muxCKey, 'M1');
    extractPoints(mux2Key, 'M2');
    extractPoints(mux3Key, 'M3');
    extractPoints(muxFWAKey, 'MFWA');
    extractPoints(muxFWBKey, 'MFWB');
    extractPoints(muxFWMKey, 'MFWM');
    extractPoints(instructionMemoryKey, 'IM');
    extractPoints(dataMemoryKey, 'DM');
    extractPoints(registerFileKey, 'RF');
    extractPoints(controlUnitKey, 'CU');
    extractPoints(extenderKey, 'EXT');
    extractPoints(ibKey, 'IB');
    
    //Pipeline Registers
    extractPoints(pipereg_fd0_Key, 'FD0');//Fetch decode
    extractPoints(pipereg_fd1_Key, 'FD1');//Fetch decode
    extractPoints(pipereg_de0_Key, 'DE0');//Fetch decode
    extractPoints(pipereg_de1_Key, 'DE1');//Fetch decode
    extractPoints(pipereg_de2_Key, 'DE2');//Fetch decode
    extractPoints(pipereg_em0_Key, 'EM0');//Fetch decode
    extractPoints(pipereg_em1_Key, 'EM1');//Fetch decode
    extractPoints(pipereg_mw0_Key, 'MW0');//Fetch decode
    extractPoints(pipereg_mw1_Key, 'MW1');//Fetch decode

    extractPoints(pipereg_deControl_Key, 'DEControl');
    extractPoints(pipereg_emControl_Key, 'EMControl');
    extractPoints(pipereg_mwControl_Key, 'MWControl');
    
    extractPoints(loadHazardUnitKey, 'LHU');
    extractPoints(branchHazardUnitKey, 'BHU');
    extractPoints(forwardingUnitKey, 'FU');

    _connectionPoints = {for (var p in allPoints) p.label: p};
    notifyListeners();
  }

  /// Calcula un waypoint para crear una esquina de 90 grados entre dos puntos.
  Offset _manhattan(String xLabel, String yLabel) {
    final xPoint = _connectionPoints[xLabel];
    final yPoint = _connectionPoints[yLabel];
    if (xPoint == null || yPoint == null) return Offset.zero; // Fallback

    return Offset(xPoint.position.dx, yPoint.position.dy);
  }

  /// Devuelve la coordenada X de un punto de conexión.
  double x(String label) {
    return _connectionPoints[label]?.position.dx ?? 0;
  }

  /// Devuelve la coordenada Y de un punto de conexión.
  double y(String label) {
    return _connectionPoints[label]?.position.dy ?? 0;
  }




  /// Actualiza la lista de buses según el modo de simulación actual.
  void _updateBuses() {

    
    _buses.clear();
    switch (_simulationMode) {
      case SimulationMode.singleCycle:
        _buses.addAll(_getSingleCycleBuses());
        break;
      case SimulationMode.multiCycle:
        _buses.addAll(_getMultiCycleBuses()); 
        break;
      case SimulationMode.pipeline:
        _buses.addAll(_getPipelineBuses()); // Usamos la misma para multi y pipe por ahora
        break;
    }
    notifyListeners();
  }

  /// Devuelve la lista de buses para el datapath monociclo.
  List<Bus> _getSingleCycleBuses() {
    return [
      Bus(startPointLabel: 'NPC-0', endPointLabel: 'NPC-1', isActive: (s) => true, valueKey: 'npc_bus'),
      Bus(startPointLabel: 'PC-1', endPointLabel: 'PC-2', isActive: (s) => s.isPCActive, valueKey: 'pc_bus'),      
      Bus(startPointLabel: 'PC-2', endPointLabel: 'NPC-2', isActive: (s) => s.isPCActive, 
        waypointsBuilder: (s) => [Offset(x('PC-2'),y('NPC-2'))], 
        valueKey: 'pc_bus'),
      Bus(startPointLabel: 'PC-2', endPointLabel: 'IM-0', isActive: (s) => s.isPCActive, valueKey: 'pc_bus'),      
      Bus(startPointLabel: 'PC-2', endPointLabel: 'BR-1', isActive: (s) => s.isPCActive, 
        waypointsBuilder: (s) => [Offset(x('PC-2'),y('BR-1'))], 
        valueKey: 'pc_bus'),
      Bus(startPointLabel: 'NPC-3', endPointLabel: 'NPC-4', isActive: (s) => s.isPcAdderActive, valueKey: 'npc_bus'),
      Bus(
        startPointLabel: 'NPC-4', endPointLabel: 'M2-0', isActive: (s) => s.isPcAdderActive, valueKey: 'npc_bus',
        waypointsBuilder: (s) {
          final targetPoint = s.connectionPoints['M2-0'];
          if (targetPoint == null) return [];
          return [Offset(x('NPC-4'),y('NPC-4')),  Offset(x('NPC-4'),yNPC), const Offset(xMinimo,yNPC), Offset(xMinimo, y('M2-0'))];
        },
      ),
      Bus(
        startPointLabel: 'NPC-4', endPointLabel: 'M1-0', isActive: (s) => s.isPcAdderActive, valueKey: 'npc_bus',
        waypointsBuilder: (s) {
          final targetPoint = s.connectionPoints['M1-0'];
          if (targetPoint == null) return [];
          return [Offset(x_6,y('NPC-4')), Offset(x_6, y('M1-0'))];
        },
      ),
      Bus(startPointLabel: 'IM-1', endPointLabel: 'IB-0', isActive: (s) => s.isIMemActive, valueKey: 'instruction_bus'),

      Bus(startPointLabel: 'IB-4', endPointLabel: 'RF-0', isActive: (s) => s.isIMemActive,width: 2, valueKey: 'da_bus',size: 5),
      Bus(startPointLabel: 'IB-5', endPointLabel: 'RF-1', isActive: (s) => s.isIMemActive,width: 2, valueKey: 'db_bus',size: 5),
      Bus(startPointLabel: 'IB-6', endPointLabel: 'RF-2', isActive: (s) => s.isIMemActive,width: 2, valueKey: 'dc_bus',size: 5),
      Bus(startPointLabel: 'IB-7', endPointLabel: 'EXT-0', isActive: (s) => s.isIMemActive, valueKey: 'imm_bus'),

      Bus(startPointLabel: 'EXT-2', endPointLabel: 'BR-0', isActive: (s) => s.isExtenderActive, valueKey: 'immExt_bus'),      
      Bus(startPointLabel: 'EXT-3', endPointLabel: 'M3-1', isActive: (s) => s.isExtenderActive, 
        waypointsBuilder: (s) => [Offset(x('EXT-3'),y('M3-1'))], 
        valueKey: 'immExt_bus'),
      Bus(
        startPointLabel: 'BR-2', endPointLabel: 'M2-1', isActive: (s) => s.isBranchAdderActive, valueKey: 'branch_target_bus',
        waypointsBuilder: (s) {
          return [Offset(x('BR-3'),y('BR-3')),  Offset(x('BR-3'),yBrDown), 
          Offset(xMinimo,yBrDown), Offset(xMinimo, y('M2-1'))];
        },
      ),
      Bus(startPointLabel: 'M2-5', endPointLabel: 'PC-0', isActive: (s) => s.isMux2Active, valueKey: 'mux_pc_bus'),
      Bus(startPointLabel: 'RF-5', endPointLabel: 'ALU-0', isActive: (s) => s.isRegFileActive, valueKey: 'rd1_bus'),
      Bus(startPointLabel: 'RF-6', endPointLabel: 'M3-0', isActive: (s) => s.isRegFileActive, valueKey: 'rd2_bus'),
      Bus(startPointLabel: 'RF-7', endPointLabel: 'DM-1', isActive: (s) => s.isRegFileActive,
        waypointsBuilder: (s) => [ Offset(x('RF-7'),y_Bdown), Offset(x_B_mem,y_Bdown),Offset(x_B_mem,y('DM-1'))], 
        valueKey: 'rd2_bus'),
        Bus(startPointLabel: 'M3-3', endPointLabel: 'ALU-1', isActive: (s) => s.isMux3Active, valueKey: 'mux_alu_b_bus'),
      Bus(startPointLabel: 'ALU-4', endPointLabel: 'DM-0', isActive: (s) => s.isAluActive, valueKey: 'alu_result_bus'),
      Bus(
        startPointLabel: 'ALU-5', endPointLabel: 'M1-1', isActive: (s) => s.isAluActive, valueKey: 'alu_result_bus',
        waypointsBuilder: (s) {
          final targetPoint = s.connectionPoints['M1-1'];
          if (targetPoint == null) return [];
          return [Offset(x('ALU-5'),yAluResultUp), Offset(x_5,yAluResultUp), Offset(x_5, y('M1-1'))];
        },
      ),
      Bus(startPointLabel: 'DM-3', endPointLabel: 'M1-2', isActive: (s) => s.isDMemActive, valueKey: 'mem_read_data_bus'),
      Bus(
        startPointLabel: 'M1-5', endPointLabel: 'RF-3', isActive: (s) => s.isMuxCActive, valueKey: 'mux_wb_bus',
        waypointsBuilder: (s) {
          final targetPoint = s.connectionPoints['RF-3'];
          if (targetPoint == null) return [];
          return [ Offset(xMaximo,y('M1-5')),  Offset(xMaximo,yWbDown),  Offset(x_4,yWbDown), Offset(x_4, y('RF-3'))];
        },
      ),


      // Buses de estado

      Bus(startPointLabel: 'ALU-3', endPointLabel: 'CU-7', isActive: (s) => s.isAluActive, 
      waypointsBuilder: (s) => [_manhattan( 'CU-7','ALU-3')], 
      isState: true,size:1,valueKey:"flagZ"),
      Bus(startPointLabel: 'IB-1', endPointLabel: 'CU-1', 
      isActive: (s) => s.isIMemActive, 
      waypointsBuilder: (s) => [_manhattan( 'CU-1','IB-1')], 
      isState: true,valueKey:"opcode",size:7),
      Bus(startPointLabel: 'IB-2', endPointLabel: 'CU-2', isActive: (s) => s.isIMemActive, 
      waypointsBuilder: (s) => [_manhattan( 'CU-2','IB-2')], 
      isState: true,valueKey:"funct3",size:3),
      Bus(startPointLabel: 'IB-3', endPointLabel: 'CU-3', isActive: (s) => s.isIMemActive, 
      waypointsBuilder: (s) => [_manhattan( 'CU-3','IB-3')], 
      isState: true,valueKey:"funct7",size:7),


      Bus(startPointLabel: 'CU-0', endPointLabel: 'M2-4', isActive: (s) => s.isPCsrcActive, 
        waypointsBuilder: (s) => [Offset(xControl1,yCpcSrc),Offset(x('M2-4'),yCpcSrc)], 
        isControl: true,size:2,valueKey: "control_PCsrc"),
      Bus(startPointLabel: 'CU-4', endPointLabel: 'RF-4', isActive: (s) => s.isControlActive,isControl: true,size:1,valueKey: "control_BRwr"),
      Bus(startPointLabel: 'CU-5', endPointLabel: 'M3-2', isActive: (s) => s.isControlActive,isControl: true,size:1,valueKey: "control_ALUsrc"),
      Bus(startPointLabel: 'CU-6', endPointLabel: 'ALU-2', isActive: (s) => s.isControlActive,isControl: true,size:3,valueKey: "control_ALUctr"),
      Bus(startPointLabel: 'CU-8', endPointLabel: 'DM-2', isActive: (s) => s.isControlActive,isControl: true,size:1,valueKey: "control_MemWr"),
      Bus(startPointLabel: 'CU-9', endPointLabel: 'M1-4', isActive: (s) => s.isControlActive,isControl: true,size:2,valueKey: "control_ResSrc"),
      Bus(startPointLabel: 'CU-10', endPointLabel: 'EXT-1', isActive: (s) => s.isControlActive, 
      // El 110 es para desplazar abajo la etiqueta
      waypointsBuilder: (s) => [Offset(x('CU-10'),110),Offset(x('CU-10'),yCimm),Offset(x('EXT-1'),yCimm)], 
      isControl: true,size:3,valueKey: "control_ImmSrc"),

      Bus(startPointLabel: 'ALU-6', endPointLabel: 'M2-2', isActive: (s) => false, 
      waypointsBuilder: (s) => [Offset(x('ALU-6'),yAlu2pcDown),Offset(xMinimo2,yAlu2pcDown),Offset(xMinimo2,y('M2-2'))], valueKey: 'alu_result_bus'),

    ];
  }


  

  /// Devuelve la lista de buses para el datapath segmentado (pipeline).
  List<Bus> _getPipelineBuses() {
    // Copiamos la base del monociclo y la modificamos.
    final pipelineBuses = _getSingleCycleBuses();
    removePipelineDestinationBuses(pipelineBuses); // Elimina buses de propagación de registro destino
    addPipelineBuses(pipelineBuses); // Añade buses de propagación de registro destino
    modifyBuses(pipelineBuses); // Cambia buses de propagación de registro destino
    return pipelineBuses;
  }

  List<Bus> _getMultiCycleBuses() {
    // Copiamos la base del monociclo y la modificamos.
    final pipelineBuses = _getSingleCycleBuses();
    removeMultiCycleBuses(pipelineBuses); // Elimina buses de propagación de registro destino
    addMultiCycleBuses(pipelineBuses); // Añade buses de propagación de registro destino
    modifyBuses(pipelineBuses,isMultiCycle: true); // Cambia buses de propagación de registro destino
    return pipelineBuses;
  }

void modifyBuses(List<Bus> buses,{bool isMultiCycle = false}) {
    Bus bus;
    bus=buses.firstWhere((bus) => bus.startPointLabel == 'IB-4' && bus.endPointLabel == 'RF-0');
    bus.isActive = (s) => s.isPathActive('Pipe_IF_ID_Instr_out');
    bus=buses.firstWhere((bus) => bus.startPointLabel == 'IB-5' && bus.endPointLabel == 'RF-1');
    bus.isActive = (s) => s.isPathActive('Pipe_IF_ID_Instr_out');
    bus=buses.firstWhere((bus) => bus.startPointLabel == 'IB-7' && bus.endPointLabel == 'EXT-0');
    bus.isActive = (s) => s.isPathActive('Pipe_IF_ID_Instr_out');

    bus=buses.firstWhere((bus) => bus.startPointLabel == 'IB-1' && bus.endPointLabel == 'CU-1');
    bus.isActive = (s) => s.isPathActive('Pipe_IF_ID_Instr_out');
    bus=buses.firstWhere((bus) => bus.startPointLabel == 'IB-2' && bus.endPointLabel == 'CU-2');
    bus.isActive = (s) => s.isPathActive('Pipe_IF_ID_Instr_out');
    bus=buses.firstWhere((bus) => bus.startPointLabel == 'IB-3' && bus.endPointLabel == 'CU-3');
    bus.isActive = (s) => s.isPathActive('Pipe_IF_ID_Instr_out');

    bus=buses.firstWhere((bus) => bus.startPointLabel == 'EXT-3' && bus.endPointLabel == 'M3-1');
    bus.isActive = (s) => s.isPathActive('Pipe_ID_EX_Imm_out');
    bus.valueKey = 'Pipe_ID_EX_Imm_out';

    bus=buses.firstWhere((bus) => bus.startPointLabel == 'BR-2' && bus.endPointLabel == 'M2-1');
    bus.isActive = (s) => s.isPathActive('branch_target_bus');
    bus.valueKey = 'branch_target_bus';


    if(isMultiCycle){
    bus=buses.firstWhere((bus) => bus.startPointLabel == 'IB-6' && bus.endPointLabel == 'RF-2');
    bus.isActive = (s) => s.isPathActive('Pipe_IF_ID_Instr_out');
    }

}


  /// Elimina buses en pipeline y multiciclo para ser reemplazados por nuevos buses
  void removeMultiCycleBuses(List<Bus> buses) {

    buses.removeWhere((bus)=>bus.isControl);

    buses.removeWhere((bus) => bus.startPointLabel == 'RF-5' && bus.endPointLabel == 'ALU-0');
    buses.removeWhere((bus) => bus.startPointLabel == 'RF-6' && bus.endPointLabel == 'M3-0');
    buses.removeWhere((bus) => bus.startPointLabel == 'RF-7' && bus.endPointLabel == 'DM-1');
    buses.removeWhere((bus) => bus.startPointLabel == 'DM-3' && bus.endPointLabel == 'M1-2');
    buses.removeWhere((bus) => bus.startPointLabel == 'EXT-2' && bus.endPointLabel == 'BR-0');
    buses.removeWhere((bus) => bus.startPointLabel == 'ALU-4' && bus.endPointLabel == 'DM-0');
    buses.removeWhere((bus) => bus.startPointLabel == 'ALU-5' && bus.endPointLabel == 'M1-1');


  }

  /// Añade buses de propagación de registro destino en pipeline y multiciclo
  void addMultiCycleBuses(List<Bus> buses) {
        buses.addAll([
        
        Bus(startPointLabel: 'RF-5', endPointLabel: 'DE1-0', isActive: (s) => s.isPathActive('rd1_bus'), valueKey: 'rd1_bus'),
        Bus(startPointLabel: 'DE1-4', endPointLabel: 'ALU-0', isActive: (s) => s.isPathActive('Pipe_ID_EX_A_out'), valueKey: 'Pipe_ID_EX_A_out'),

        Bus(startPointLabel: 'RF-6', endPointLabel: 'DE1-1', isActive: (s) => s.isPathActive('rd2_bus'), valueKey: 'rd2_bus'),
        Bus(startPointLabel: 'DE1-5', endPointLabel: 'M3-0', isActive: (s) => s.isPathActive('Pipe_ID_EX_B_out'), valueKey: 'Pipe_ID_EX_B_out'),
        
        Bus(startPointLabel: 'RF-7', endPointLabel: 'EM1-2', isActive: (s) => s.isPathActive('Pipe_ID_EX_B_out'), valueKey: 'Pipe_ID_EX_B_out',
        //waypoints:List.of([Offset(x('RF-7'),331)])),
        waypointsBuilder: (s) => [Offset(x('RF-7'),y('EM1-2'))],
        ),

        Bus(startPointLabel: 'EM1-6', endPointLabel: 'DM-1', isActive: (s) => s.isPathActive('Pipe_EX_MEM_B_out'), valueKey: 'Pipe_EX_MEM_B_out',
        waypoints:List.of([Offset(x_B_mem,y('EM1-6')), Offset(x_B_mem,y('DM-1'))]),
        ),
        
        Bus(startPointLabel: 'DM-3', endPointLabel: 'MW1-1', isActive: (s) => s.isPathActive('Pipe_EX_MEM_B_out'), valueKey: 'mem_read_data_bus'),
        Bus(startPointLabel: 'MW1-4', endPointLabel: 'M1-2', isActive: (s) => s.isPathActive('Pipe_MEM_WB_RM_out'), valueKey: 'Pipe_MEM_WB_RM_out'),
      
      //Bus(startPointLabel: 'EXT-2', endPointLabel: 'BR-0', isActive: (s) => s.isExtenderActive, valueKey: 'immExt_bus'),
        Bus(startPointLabel: 'EXT-2', endPointLabel: 'DE1-3', isActive: (s) => s.isPathActive('immExt_bus'), valueKey: 'immExt_bus'),
        Bus(startPointLabel: 'DE1-7', endPointLabel: 'BR-0', isActive: (s) => s.isPathActive('Pipe_ID_EX_Imm_out'), valueKey: 'Pipe_ID_EX_Imm_out',waypoints:List.of([])),

            //Bus(startPointLabel: 'ALU-5', endPointLabel: 'M1-1', isActive: (s) => s.isAluActive,waypoints: List.of([const Offset(1070,175),const Offset(1250,175),const Offset(1250,248)]), valueKey: 'alu_result_bus'),
        Bus(startPointLabel: 'ALU-5', endPointLabel: 'MW1-0', isActive: (s) => s.isPathActive('Pipe_EX_MEM_ALU_result_out'), valueKey: 'Pipe_EX_MEM_ALU_result_out',
        waypoints:List.of([ Offset(x('ALU-5'),yAluResultUp)])
        ),
        
        Bus(startPointLabel: 'MW1-3', endPointLabel: 'M1-1', isActive: (s) => s.isPathActive('Pipe_MEM_WB_ALU_result_out'), valueKey: 'Pipe_MEM_WB_ALU_result_out',
        waypoints:List.of([Offset(x_5,yAluResultUp),Offset(x_5,y('M1-1'))])),


    //Bus(startPointLabel: 'ALU-4', endPointLabel: 'DM-0', isActive: (s) => s.isAluActive, valueKey: 'alu_result_bus'),
        Bus(startPointLabel: 'ALU-4', endPointLabel: 'EM1-1', isActive: (s) => s.isPathActive('alu_result_bus'), valueKey: 'alu_result_bus'),
        Bus(startPointLabel: 'EM1-5', endPointLabel: 'DM-0', isActive: (s) => s.isPathActive('Pipe_EX_MEM_ALU_result_out'), valueKey: 'Pipe_EX_MEM_ALU_result_out'),

      

        ]);
  }


  /// Elimina buses en modo pipeline para ser reemplazados por nuevos buses
  void removePipelineDestinationBuses(List<Bus> buses) {
    removeMultiCycleBuses(buses);

    //Resueltos
    buses.removeWhere((bus) => bus.startPointLabel == 'IB-6' && bus.endPointLabel == 'RF-2'); //Redibujamos bus para que propage registro destino
    buses.removeWhere((bus) => bus.startPointLabel == 'NPC-4' && bus.endPointLabel == 'M1-0');
    buses.removeWhere((bus) => bus.startPointLabel == 'PC-2' && bus.endPointLabel == 'BR-1');
    //buses.removeWhere((bus) => bus.startPointLabel == 'EXT-2' && bus.endPointLabel == 'BR-0');
    buses.removeWhere((bus) => bus.startPointLabel == 'M2-5' && bus.endPointLabel == 'PC-0');    
  }


  void addPipelineBuses(List<Bus> buses) {

        addMultiCycleBuses(buses);
        buses.addAll([
      
       // --- Propagación del registro de destino (rd) ---
       Bus(startPointLabel: 'IB-6', endPointLabel: 'DE1-2', isActive: (s) => s.isPathActive('dc_bus'),width: 2, valueKey: 'dc_bus',size: 5,
       waypoints:List.of([ Offset(x_PipeDCinicial,y('IB-6')), Offset(x_PipeDCinicial,y('DE1-2'))])),
       Bus(startPointLabel: 'DE1-6', endPointLabel: 'EM1-3', isActive: (s) => s.isPathActive('Pipe_ID_EX_RD_out'),width: 2, valueKey: 'Pipe_ID_EX_RD_out',size: 5),
       Bus(startPointLabel: 'EM1-7', endPointLabel: 'MW1-2', isActive: (s) => s.isPathActive('Pipe_EX_MEM_RD_out'),width: 2, valueKey: 'Pipe_EX_MEM_RD_out',size: 5), // El valor se propaga
       Bus(startPointLabel: 'MW1-5', endPointLabel: 'RF-2', isActive: (s) => s.isPathActive('Pipe_MEM_WB_RD_out'),width: 2, valueKey: 'Pipe_MEM_WB_RD_out',size: 5,
       waypoints:List.of([ Offset(x_dcPipe2,y('MW1-5')),const Offset(x_dcPipe2,y_PipeDCfinal),const Offset(x_PipeDCfinal,y_PipeDCfinal), Offset(x_PipeDCfinal,y('RF-2'))])),

    //Bus(startPointLabel: 'NPC-4', endPointLabel: 'M1-0', isActive: (s) => s.isPcAdderActive,waypoints: List.of([const Offset(1270,150),const Offset(1270,228)] ), valueKey: 'npc_bus'),
      
        Bus(startPointLabel: 'NPC-4', endPointLabel: 'FD0-0', isActive: (s) => true, valueKey: 'npc_bus'),
        Bus(startPointLabel: 'FD0-1', endPointLabel: 'DE0-0', isActive: (s) => s.isPathActive('Pipe_IF_ID_NPC_out'), valueKey: 'Pipe_IF_ID_NPC_out'),
        Bus(startPointLabel: 'DE0-1', endPointLabel: 'EM0-0', isActive: (s) => s.isPathActive('Pipe_ID_EX_NPC_out'), valueKey: 'Pipe_ID_EX_NPC_out'),
        Bus(startPointLabel: 'EM0-1', endPointLabel: 'MW0-0', isActive: (s) => s.isPathActive('Pipe_EX_MEM_NPC_out'), valueKey: 'Pipe_EX_MEM_NPC_out'),
        Bus(startPointLabel: 'MW0-1', endPointLabel: 'M1-0', isActive: (s) => s.isPathActive('Pipe_MEM_WB_NPC_out'), valueKey: 'Pipe_MEM_WB_NPC_out',
        waypoints:List.of([Offset(x_6,y('NPC-3')), Offset(x_6,y('M1-0'))])),

    //Bus(startPointLabel: 'PC-2', endPointLabel: 'BR-1', isActive: (s) => s.isPCActive,waypoints: List.of([const Offset(260,440)]), valueKey: 'pc_bus'),

        Bus(startPointLabel: 'PC-2', endPointLabel: 'FD1-0', isActive: (s) => true, valueKey: 'pc_bus',
        waypoints:List.of([const Offset(xPcUp,yPipePC1)])),
        Bus(startPointLabel: 'FD1-1', endPointLabel: 'DE2-0', isActive: (s) => s.isPathActive('Pipe_IF_ID_PC_out'), valueKey: 'Pipe_IF_ID_PC_out'),
        Bus(startPointLabel: 'DE2-1', endPointLabel: 'BR-1', isActive: (s) => s.isPathActive('Pipe_ID_EX_PC_out'), valueKey: 'Pipe_ID_EX_PC_out'),



    //Bus(startPointLabel: 'M2-5', endPointLabel: 'PC-0', isActive: (s) => s.isMux2Active, valueKey: 'mux_pc_bus'),
        Bus(startPointLabel: 'M2-5', endPointLabel: 'PC-0', isActive: (s) => s.isMux2Active, valueKey: 'mux_pc_bus'),  //Ejemplo de borrar un mismo bus y sustituirlo por otro para cambiar el comportamiento con el pipeline


    // Nuevos buses de control


      

    ]);


    buses.addAll([
      Bus(startPointLabel: 'CU-4', endPointLabel: 'DEControl-0', isActive: (s) => s.isPathActive("Pipe_IF_ID_NPC_out"),valueKey: 'Pipe_ID_EX_Control',waypoints: List.of([_manhattan('CU-4', 'DEControl-0')]),isControl: true,size:16),
      Bus(startPointLabel: 'DEControl-1', endPointLabel: 'EMControl-0', isActive: (s) => s.isPathActive("Pipe_ID_EX_NPC_out"),valueKey: 'Pipe_ID_EX_Control_out',isControl: true,size:16),
      Bus(startPointLabel: 'EMControl-1', endPointLabel: 'MWControl-0', isActive: (s) => s.isPathActive("Pipe_EX_MEM_NPC_out"),valueKey: 'Pipe_EX_MEM_Control_out',isControl: true,size:3),


      Bus(startPointLabel: 'CU-10', endPointLabel: 'EXT-1', isActive: (s) => s.isPathActive("Pipe_IF_ID_Instr_out"),
        waypoints: List.of([Offset(x('CU-10'),100),Offset(x('CU-10'),yCimm), Offset(x('EXT-1'),yCimm)]),
        isControl: true,size:3,valueKey: "Pipe_ImmSrc"),
      Bus(startPointLabel: 'EMControl-2', endPointLabel: 'DM-2', isActive: (s) => s.isPathActive("Pipe_EX_MEM_NPC_out"),valueKey: 'Pipe_MemWr',
      waypoints: List.of([_manhattan('DM-2', 'EMControl-2') ]),isControl: true,size:3),
      Bus(startPointLabel: 'MWControl-1', endPointLabel: 'RF-4', isActive: (s) => s.isPathActive("Pipe_EX_MEM_NPC_out"),valueKey: 'Pipe_BRwr',
      waypoints: List.of([Offset(x_5, y('MWControl-1')),const Offset(x_5, y_controlWrite),Offset(x('RF-4'), y_controlWrite) ]),
      isControl: true,size:3),
      Bus(startPointLabel: 'MWControl-1', endPointLabel: 'M1-4', isActive: (s) => s.isPathActive("Pipe_EX_MEM_NPC_out"),valueKey: 'Pipe_ResSrc',
      waypointsBuilder:  (s) => [s._manhattan('M1-4', 'MWControl-1')],isControl: true,size:2),

      //Creo que están repetidas por error
      //Bus(startPointLabel: 'CU-10', endPointLabel: 'EXT-1', isActive: (s) => s.isPathActive("Pipe_IF_ID_Instr_out"),waypoints: List.of([const Offset(x7,0),const Offset(x7,100),const Offset(x7,y7),const Offset(670,y7)]),isControl: true,size:3,valueKey: "control_ImmSrc"),
      //Bus(startPointLabel: 'EMControl-2', endPointLabel: 'DM-2', isActive: (s) => s.isPathActive("Pipe_EX_MEM_NPC_out"),valueKey: 'control_MemWr',waypoints: List.of([const Offset(1140, 95) ]),isControl: true,size:1),
      //Bus(startPointLabel: 'MWControl-1', endPointLabel: 'RF-4', isActive: (s) => s.isPathActive("Pipe_MEM_WB_Control_out"),valueKey: 'control_BRwr',waypoints: List.of([const Offset(1250, 85),const Offset(1250, 115),const Offset(660, 115) ]),isControl: true,size:1),
      //Bus(startPointLabel: 'MWControl-1', endPointLabel: 'M1-4', isActive: (s) => s.isPathActive("Pipe_MEM_WB_Control_out"),valueKey: 'control_ResSrc',
      //waypointsBuilder:  (s) => [s._manhattan('M1-4', 'MWControl-1')],isControl: true,size:2),

      Bus(startPointLabel: 'DEControl-2', endPointLabel: 'ALU-2', isActive: (s) => s.isPathActive("Pipe_ID_EX__Control_out"),valueKey: 'Pipe_ALUctr',waypoints: List.of([_manhattan('ALU-2', 'DEControl-2') ]),isControl: true,size:3),
      Bus(startPointLabel: 'DEControl-2', endPointLabel: 'M2-4', isActive: (s) => s.isPathActive("Pipe_ID_EX_Control_out"),valueKey: 'Pipe_PCsrc',
      waypoints: List.of([Offset(x_controlPipe_Pcsrc, y('DEControl-2')),Offset(x_controlPipe_Pcsrc, yPc4Up), Offset(x('M2-4'), yPc4Up) ]),
      isControl: true,size:3),
      
      //Creo que sobra
      //Bus(startPointLabel: 'DEControl-2', endPointLabel: 'ALU-2', isActive: (s) => s.isPathActive("Pipe_ID_EX_Control_out"),valueKey: 'control_ALUctr', waypoints: List.of([_manhattan('ALU-2', 'DEControl-2')]),isControl: true,size:3),
      
      Bus(startPointLabel: 'DEControl-2', endPointLabel: 'M3-2', isActive: (s) => s.isPathActive("Pipe_ID_EX_Control_out"),valueKey: 'Pipe_ALUsrc',
      waypoints: List.of([_manhattan('M3-2', 'DEControl-2')]),isControl: true,size:1),
      //Este no se de donde ha salido:
      //Bus(startPointLabel: 'DEControl-2', endPointLabel: 'M3-2', isActive: (s) => s.isPathActive("Pipe_ID_EX_NPC_out"),valueKey: 'Pipe_ALUsrc',waypoints: List.of([const Offset(820, 100) ]),isControl: true,size:3),
      //Bus(startPointLabel: 'DEControl-2', endPointLabel: 'M2-4', isActive: (s) => s.isPathActive("Pipe_ID_EX_Control_out"),valueKey: 'control_PCsrc',waypoints: List.of([const Offset(870, 100),const Offset(870, 60),const Offset(75, 60) ]),isControl: true,size:2),
    ]);
    
    // --- Buses para las Unidades de Hazard (Solo visibles cuando hay un hazard) ---
    
    buses.addAll([
      // --- Load Hazard Unit (Riesgo de Carga) ---
      Bus(  /****/
        startPointLabel: 'DEControl-1', // Salida de Flush
        endPointLabel: 'LHU-2',   // Hacia el registro IF/ID para anularlo        
        isHidden: (s) => !(s.showLHU || s.isLoadHazard),
        isActive: (s) => true,
        valueKey: 'Pipe_ID_EX_Control_out',
        isLoadHazardBus: true,
        isControl: true, size: 1, // Salida: señal de flush
        waypointsBuilder: (s) => [s._manhattan('LHU-2', 'DEControl-1')],

      ),


      Bus(
        startPointLabel: 'DE1-8', // rd desde ID/EX
        endPointLabel: 'LHU-1',        
        isHidden: (s) => !(s.showLHU || s.isLoadHazard),
        isActive: (s) => true,
        valueKey: 'Pipe_ID_EX_RD_out',
        isLoadHazardBus: true,
        isState: true, 
        size: 5, // Entrada: registro destino de la instrucción en EX
        waypointsBuilder: (s) => [s._manhattan('LHU-1', 'DE1-8')],

      ),
      Bus(
        startPointLabel: 'CU-5', // Instrucción en decode
        endPointLabel: 'LHU-4',        
        isHidden: (s) => !(s.showLHU || s.isLoadHazard),
        isActive: (s) => true,
        valueKey: 'da_bus',
        isLoadHazardBus: true,
        isControl: true, 
        size: 5, // Entrada: registro fuente 1 de la instrucción en ID
        waypointsBuilder: (s) => [s._manhattan('CU-5', 'LHU-4')],
      ),
      Bus(
        startPointLabel: 'LHU-0',
        endPointLabel: 'PC-3', // Congela el PC        
        isHidden: (s) => !(s.showLHU || s.isLoadHazard),
        isActive: (s) => true,
        valueKey: 'bus_stall',
        isLoadHazardBus: true,
        isControl: true, 
        size: 1, // Salida: señal de stall
        //waypoints: const [Offset(215, 35)],
        waypointsBuilder: (s) => [s._manhattan('PC-3', 'LHU-0')],
      ),

      // --- Branch Hazard Unit (Riesgo de Salto) ---
      
      Bus(
        startPointLabel: 'BHU-1', // 
        endPointLabel: 'BHU-0',   //        isHidden: (s) => !s.isBranchHazard,        
        isHidden: (s) => !(s.showBHU || s.isBranchHazard),
        isActive: (s) => s.isBranchHazard,
        valueKey: 'flagZ',
        isState: true, size: 1, // Entrada: señal de salto tomado
      ),
      Bus(   /****/
        startPointLabel: 'DEControl-1', // Salida de Flush
        endPointLabel: 'BHU-2',   // Hacia el registro IF/ID para anularlo        
        isHidden: (s) => !(s.showBHU || s.isBranchHazard),
        isActive: (s) => s.isBranchHazard,
        valueKey: 'Pipe_ID_EX_Control_out',
        isBranchHazardBus: true,
        isControl: true, 
        size: 1, // Salida: señal de flush
        waypointsBuilder: (s) => [s._manhattan('BHU-2', 'DEControl-1')],

      ),
      // --- Branch Hazard Unit ---
      Bus(
        startPointLabel: 'BHU-4', // Salida de Flush
        endPointLabel: 'FD0-2',   // Hacia el registro IF/ID para anularlo        
        isHidden: (s) => !(s.showBHU || s.isBranchHazard),
        isActive: (s) => s.isBranchHazard,
        valueKey: 'bus_flush',
        isControl: true, 
        isBranchHazardBus: true,
        size: 1,
        //waypoints: const [Offset(527.5, 35)],
        waypointsBuilder: (s) => [s._manhattan('FD0-2', 'BHU-4')],

      ),

      Bus(  //Valores registro fuente en ex
        startPointLabel: 'DE1-8', // 
        endPointLabel: 'FU-0',   //        isHidden: (s) => !s.isBranchHazard,

        isHidden: (s) => !(s.showBHU || s.isBranchHazard),
        isActive: (s) => true,
        valueKey: 'Pipe_ID_EX_RD_out',
        isState: true, 
        isBranchHazardBus: true,
        size: 3, // Entrada: señal de salto tomado
        waypointsBuilder: (s) => [s._manhattan('FU-0', 'DE1-8')],

      ),

      Bus(
        startPointLabel: 'BHU-5',
        endPointLabel: 'PC-3', // Congela el PC        
        isHidden: (s) => !(s.showBHU || s.isBranchHazard),
        isActive: (s) => true,
        valueKey: 'bus_flush',
        isBranchHazardBus: true,
        isControl: true, 
        size: 1, // Salida: señal de stall
        //waypoints: const [Offset(215, 35)],
        waypointsBuilder: (s) => [s._manhattan('PC-3', 'BHU-5')],
      ),



    ]);


///Buses de forwarding. Solo visibles cuando hay un hazard de datos que se puede resolver con forwarding.
///
    buses.addAll([

      // Los 5 buses de datos
      Bus(
        startPointLabel: 'ALU-5', // Aparentemente, ALU, pero es la salida del pipelie Ex / Mem
        endPointLabel: 'MFWA-0',   // Mux Forwarding a
        isHidden: (s) => !(s.showForwarding || s.busValues['bus_ControlForwardA'] == 1),
        isActive: (s) => s.busValues['bus_ControlForwardA'] == 1, // Se activa si el mux selecciona esta entrada
        valueKey: 'bus_ForwardA',
        isControl: false, 
        isForwardingBus: true,
        color: const Color.fromARGB(255, 138, 161, 255),
        size: 32,
        waypoints:  [Offset(x('ALU-5'), yFwdA),Offset(xFwdMem, yFwdA),Offset(xFwdMem, yMuxFwdA0)],
      ),

      Bus(
        startPointLabel: 'ALU-5', // Aparentemente, ALU, pero es la salida del pipelie Ex / Mem
        endPointLabel: 'MFWB-0',   // Mux Forwarding b
        isHidden: (s) => !(s.showForwarding || s.busValues['bus_ControlForwardB'] == 1),
        isActive: (s) => s.busValues['bus_ControlForwardB'] == 1, // Se activa si el mux selecciona esta entrada
        valueKey: 'bus_ForwardB',
        isControl: false, 
        isForwardingBus: true,
        color: const Color.fromARGB(255, 138, 161, 255),
        size: 32,
        waypoints:  [Offset(x('ALU-5'), yFwdA),Offset(xFwdMem, yFwdA),Offset(xFwdMem, yMuxFwdB0)],
      ),

      Bus(
        startPointLabel: 'M1-6', // Pipeline Mem / Wb
        endPointLabel: 'MFWA-2',   // Mux de la alu
        isHidden: (s) => !(s.showForwarding || (s.busValues['bus_ControlForwardA'] == 2)),
        isActive: (s) => s.busValues['bus_ControlForwardA'] == 2, // Se activa si el mux selecciona esta entrada
        valueKey: 'bus_ForwardA',
        isControl: false, 
        isForwardingBus: true,
        color: const Color.fromARGB(255, 236, 170, 247),
        size: 32,
        waypoints:  [Offset(x('M1-6'), yFwdB),Offset(xFwdWr, yFwdB),Offset(xFwdWr, yMuxFwdA1)],
      ),

      Bus(
        startPointLabel: 'M1-6', // Pipeline Mem /wb
        endPointLabel: 'MFWB-2',   // Mux de la alu
        isHidden: (s) => !(s.showForwarding || (s.busValues['bus_ControlForwardB'] == 2)),
        isActive: (s) => s.busValues['bus_ControlForwardB'] == 2, // Se activa si el mux selecciona esta entrada
        valueKey: 'bus_ForwardB',
        isControl: false, 
        isForwardingBus: true,
        color: const Color.fromARGB(255, 236, 170, 247),
        size: 32,
        waypoints:  [Offset(x('M1-6'), yFwdB),Offset(xFwdWr, yFwdB),Offset(xFwdWr, yMuxFwdB1)],
      ),
      
      Bus(
        startPointLabel: 'M1-6', // Pipeline Mem /wb
        endPointLabel: 'MFWM-2',   // Mux de la alu
        isHidden: (s) => !(s.showForwarding || (s.busValues['bus_ControlForwardM'] == 1)),
        isActive: (s) => s.busValues['bus_ControlForwardM'] == 1, // Se activa si el mux selecciona esta entrada
        valueKey: 'bus_ForwardM',
        isControl: false, 
        isForwardingBus: true,
        color: const Color.fromARGB(255, 236, 170, 247),
        size: 32,
        waypoints:  [Offset(x('M1-6'), yFwdB),Offset(xMuxFwdM-10, yFwdB),Offset(xMuxFwdM-10, yMuxFwdM1)],
      ),


      // Los buses de datos de salida
      Bus(
        startPointLabel: 'MFWA-3', // Salida de mux forward a   
        endPointLabel: 'ALU-0',   // Entrada a de la ALU
        isHidden: (s) => !(s.showForwarding || (s.busValues['bus_ControlForwardA'] != 0 && s.busValues['bus_ControlForwardA'] != null)),
        isActive: (s) => (s.busValues['bus_ControlForwardA'] != 0 && s.busValues['bus_ControlForwardA'] != null),
        valueKey: 'bus_ForwardA',
        isControl: false, 
        isForwardingBus: true,
        color: const Color.fromARGB(255, 10, 235, 93),
        size: 32,
        waypoints: const [],
      ),
      Bus(
        startPointLabel: 'MFWB-3', // Salida de mux forward b
        endPointLabel: 'ALU-1',   // Entrada b de la ALU
        isHidden: (s) => !(s.showForwarding || (s.busValues['bus_ControlForwardB'] != 0 && s.busValues['bus_ControlForwardB'] != null)),
        isActive: (s) => (s.busValues['bus_ControlForwardB'] != 0 && s.busValues['bus_ControlForwardB'] != null),
        valueKey: 'bus_ForwardB',
        isControl: false, 
        isForwardingBus: true,
        color: const Color.fromARGB(255, 10, 235, 93),
        size: 32,
        waypoints: const [],
      ),
      Bus(
        startPointLabel: 'MFWM-3', // Salida de mux forward b
        endPointLabel: 'DM-1',   // Entrada b de la ALU
        isHidden: (s) => !(s.showForwarding || (s.busValues['bus_ControlForwardM'] != 0 && s.busValues['bus_ControlForwardM'] != null)),
        isActive: (s) => (s.busValues['bus_ControlForwardM'] != 0 && s.busValues['bus_ControlForwardM'] != null),
        valueKey: 'bus_ForwardM',
        isControl: false, 
        isForwardingBus: true,
        color: const Color.fromARGB(255, 10, 235, 93),
        size: 32,
        waypoints: const [],
      ),


      //Entradas (Buses de estado) forwarding unit

      Bus(  //Valores registro fuente en ex
        startPointLabel: 'DE1-8', // 
        endPointLabel: 'FU-0',   //        isHidden: (s) => !s.isBranchHazard,
        isHidden: (s) => !(s.showForwarding || (s.busValues['bus_ControlForwardB'] == 1 || s.busValues['bus_ControlForwardA'] == 1)),
        isActive: (s) => true,
        valueKey: 'Pipe_ID_EX_RS1_RS2_out',
        isState: true, 
        isForwardingBus: true,
        size: 10, // Entrada: señal de salto tomado
        waypointsBuilder: (s) => [s._manhattan('FU-0', 'DE1-8')],

      ),                        

      Bus( //Instruccion en ex que necesita los registros /****/
        startPointLabel: 'DEControl-1', // 
        endPointLabel: 'FU-1',   //        isHidden: (s) => !s.isBranchHazard,
        isHidden: (s) => !(s.showForwarding || (s.busValues['bus_ControlForwardB'] != 0 || s.busValues['bus_ControlForwardA'] != 0)),
        isActive: (s) => true,
        valueKey: 'Pipe_ID_EX_Control_out',
        isControl: true, 
        isForwardingBus: true,
        waypointsBuilder: (s) => [s._manhattan('FU-1', 'DEControl-1')],
        size: 16, // Entrada: señal de salto tomado
      ),



      Bus(
        startPointLabel: 'MWControl-2', //  Palabra de control de la instruccion en escritura
        endPointLabel: 'FU-3',   //        isHidden: (s) => !s.isBranchHazard,
        isHidden: (s) => !(s.showForwarding || s.busValues['bus_ControlForwardA'] == 2 || s.busValues['bus_ControlForwardB'] == 2|| s.busValues['bus_ControlForwardM'] == 1),
        isActive: (s) => true,
        valueKey: 'Pipe_MEM_WB_Control_out',
        isControl: true, 
        isForwardingBus: true,
        size: 16, // Entrada: señal de salto tomado
        // Usamos el builder para calcular el waypoint dinámicamente.
        waypointsBuilder: (s) => [s._manhattan('MWControl-2', 'FU-3')],
      ),

      Bus(
        startPointLabel: 'EMControl-3', //  Palabr de control de la instruccion en Mamoria 
        endPointLabel: 'FU-4',   //        isHidden: (s) => !s.isBranchHazard,
        isHidden: (s) => !(s.showForwarding || s.busValues['bus_ControlForwardA'] == 1 || s.busValues['bus_ControlForwardB'] == 1|| s.busValues['bus_ControlForwardM'] == 1),
        isActive: (s) => true,
        valueKey: 'Pipe_EX_MEM_Control_out',
        isControl: true, 
        isForwardingBus: true,
        size: 16, 
        waypointsBuilder: (s) => [s._manhattan('EMControl-3', 'FU-4')],
      ),
      
      // Salida: control de los muxes de forward

      Bus(
        startPointLabel: 'FU-5', // 
        endPointLabel: 'MFWA-4',   //        isHidden: (s) => !s.isBranchHazard,
        isHidden: (s) => !(s.showForwarding || s.busValues['bus_ControlForwardA'] == 1 || s.busValues['bus_ControlForwardA'] == 2),
        isActive: (s) => true,
        valueKey: 'bus_ControlForwardA',
        isControl: true, 
        isForwardingBus: true,
        size: 1, // Entrada: señal de salto tomado
        //waypointsBuilder: (s) => [s._manhattan('MFWA-4', 'FU-5')],
      ),

      Bus(
        startPointLabel: 'FU-5', // 
        endPointLabel: 'MFWB-4',   //        isHidden: (s) => !s.isBranchHazard,
        isHidden: (s) => !(s.showForwarding || s.busValues['bus_ControlForwardB'] == 1 || s.busValues['bus_ControlForwardB'] == 2),
        isActive: (s) => true,
        valueKey: 'bus_ControlForwardB',
        isControl: true, 
        isForwardingBus: true,
        size: 1, // Entrada: señal de salto tomado
        //waypointsBuilder: (s) => [s._manhattan('MFWB-4', 'FU-5')],
      ),

      Bus(
        startPointLabel: 'FU-6', // 
        endPointLabel: 'MFWM-4',   //        isHidden: (s) => !s.isBranchHazard,
        isHidden: (s) => !(s.showForwarding || s.busValues['bus_ControlForwardM'] == 1),
        isActive: (s) => true,
        valueKey: 'bus_ControlForwardM',
        isControl: true, 
        isForwardingBus: true,
        size: 1, // 
        waypointsBuilder: (s) => [s._manhattan('MFWM-4', 'FU-6')],
      ),


    ]);
  }

  



  // Evalúa qué componentes están activos en función del valor del slider y el mapa _readyAt.
  void _evaluateActiveComponents() {
    if (_simulationMode == SimulationMode.multiCycle) {
      // Lógica para Multiciclo: se basa en el micro-ciclo actual.
      // Usamos el `ready_at` que ahora contiene el número de microciclo.
      _isPCActive = isComponentReady('pc_bus');
      _isPcAdderActive = isComponentReady('npc_bus');
      _isIMemActive = isComponentReady('instruction_bus');
      _isIBActive = isComponentReady('instruction_bus');
      _isControlActive = isComponentReady('control_bus');
      _isPCsrcActive = isComponentReady('pcsrc_bus');
      _isRegFileActive = isComponentReady('rd1_bus') || isComponentReady('rd2_bus');
      _isExtenderActive = isComponentReady('immExt_bus');
      _isAluActive = isComponentReady('alu_result_bus');
      _isBranchAdderActive = isComponentReady('branch_target_bus');
      // La memoria de datos está activa si se lee O se escribe, y la ruta correspondiente está activa.
      _isDMemActive = (isComponentReady('mem_read_data_bus')&& _isInstruction('lw')) || (isComponentReady('mem_write_data_bus')&& _isInstruction('sw'));
      _isMuxCActive = isComponentReady('mux_wb_bus');
      _isMux2Active = isComponentReady('mux_pc_bus');
      _isMux3Active = isComponentReady('mux_alu_b_bus');
    } 
    if (_simulationMode == SimulationMode.pipeline) {
      _isIBActive = isComponentReady('Pipe_IF_ID_Instr');
      _isRegFileActive = _isIBActive;
      _isExtenderActive=_isRegFileActive;
      _isControlActive=_isRegFileActive;
      _isMux3Active = isComponentReady('mux_alu_b_bus');
      _isMuxCActive = isComponentReady('mux_wb_bus');
      _isAluActive = isComponentReady('alu_result_bus');
      _isDMemActive = isComponentReady('mem_read_data_bus');
      _isBranchAdderActive = isComponentReady('branch_target_bus');



    }
    if (_simulationMode == SimulationMode.singleCycle) {
      // Lógica original para Monociclo: se basa en el slider.
      _evaluateSingleCycleActiveComponents();
    }
  }

  void _evaluateSingleCycleActiveComponents() {
      _isPCActive = _isComponentReadySlider('pc_bus') && _isPathActiveSingleCycle('pc_bus');
      _isPcAdderActive = _isComponentReadySlider('npc_bus') && _isPathActiveSingleCycle('npc_bus');
      _isIMemActive = _isComponentReadySlider('instruction_bus') && _isPathActiveSingleCycle('instruction_bus');
      _isIBActive = _isComponentReadySlider('instruction_bus') && _isPathActiveSingleCycle('instruction_bus');
      _isControlActive = _isComponentReadySlider('control_bus');
      _isPCsrcActive = _isComponentReadySlider('pcsrc_bus');
      _isRegFileActive = (_isComponentReadySlider('rd1_bus') && _isPathActiveSingleCycle('rd1_bus')) ||
                         (_isComponentReadySlider('rd2_bus') && _isPathActiveSingleCycle('rd2_bus'));
      _isExtenderActive = _isComponentReadySlider('immExt_bus') && _isPathActiveSingleCycle('immExt_bus');
      _isAluActive = _isComponentReadySlider('alu_result_bus') && _isPathActiveSingleCycle('alu_result_bus');
      _isBranchAdderActive = _isComponentReadySlider('branch_target_bus') && _isPathActiveSingleCycle('branch_target_bus');
      // Para 'sw', el bus de lectura no está activo, pero la memoria sí.
      // Usamos el bus de resultado de la ALU como señal de tiempo para 'sw', ya que proporciona la dirección.
      _isDMemActive = (_isComponentReadySlider('mem_read_data_bus') || _isComponentReadySlider('alu_result_bus')) && _isMemoryInstruction();
      _isMuxCActive = _isComponentReadySlider('mux_wb_bus') && _isPathActiveSingleCycle('mux_wb_bus');
      _isMux2Active = _isComponentReadySlider('mux_pc_bus');
      _isMux3Active = _isComponentReadySlider('mux_alu_b_bus');
  }

  // Helper para comprobar si un componente está listo.
  bool _isComponentReadySlider(String componentName) {
    // Si el componente no está en el mapa, se asume que no está activo.
    // Un valor por defecto mayor que cualquier tiempo crítico posible.
    final readyAtTime = _readyAt[componentName] ?? (_criticalTime + 1);
    return _sliderValue >= readyAtTime;
  }

  // Helper para multiciclo
  bool isComponentReady(String componentName) {
    final readyAtCycle = _readyAt[componentName] ?? 999; // Un ciclo inalcanzable
    return _currentMicroCycle >= readyAtCycle;
  }



  // Helper para comprobar si una ruta es lógicamente activa.
  bool _isPathActiveSingleCycle(String componentName) {
    // Si el backend no nos informa sobre una ruta, asumimos que es activa por defecto
    return _activePaths[componentName] ?? false;
  }
  bool isPathActive(String componentName) {
    if(simulationMode==SimulationMode.pipeline)
    {
      // En pipeline, las rutas activas se determinan por el estado de los registros de pipeline.
      return _activePaths[componentName] ?? true;
    }
    if(simulationMode==SimulationMode.multiCycle){
    // En multiciclo, las rutas activas se determinan por el estado de los microciclos.
      final readyAtCycle = _readyAt[componentName] ?? 999;
      final isActive = _activePaths[componentName] ?? false;
      return isActive && readyAtCycle <= _currentMicroCycle;

    }
    return isComponentReady(componentName);
  }

  // Helper para comprobar si la instrucción actual es de acceso a memoria.
  bool _isMemoryInstruction() {
    // Comprueba si la instrucción actual es una operación de memoria (load o store).
    final instructionName = _instruction.split(' ').first.toLowerCase();
    const memoryInstructions = {'lw', 'sw', 'lb', 'sb', 'lh', 'sh', 'lbu', 'lhu'};
    return memoryInstructions.contains(instructionName);
  }
  bool _isInstruction(String mnemo)
  {
    final instructionName = _instruction.split(' ').first.toLowerCase();
    return instructionName==mnemo.toLowerCase();
  }
}