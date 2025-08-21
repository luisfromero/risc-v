import 'package:flutter/material.dart';

import 'services/simulation_service.dart';
import 'simulation_mode.dart';

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
  List<Offset> waypoints; // Puntos intermedios para el trazado (opcional)
  bool Function(DatapathState) isActive; // Función para determinar si está activo
  String? valueKey; // Clave para buscar el valor en el mapa de buses (ej: 'pc_bus')
  final int width;
  final int size; // Ancho en bits del bus (ej: 32)
  final bool isControl;
  final bool isState;

  Bus({
    required this.startPointLabel,
    required this.endPointLabel,
    List<Offset>? waypoints,
    required this.isActive,
    this.valueKey,
    this.width = 3,
    this.size = 32,
    this.isControl = false,
    this.isState = false,
  }) : waypoints = waypoints ?? [];

  /// Añade un punto intermedio al bus.
  ///
  /// [waypoint]: Las coordenadas absolutas del punto a añadir.
  void addWayPoint(Offset waypoint) {
    waypoints.add(waypoint);
  }
}

// ChangeNotifier nos permite "notificar" a los widgets cuando algo cambia.
class DatapathState extends ChangeNotifier {
  // Dependencia del servicio de simulación. No sabe si es FFI o API.
  final SimulationService _simulationService;
  DatapathState(this._simulationService);

  // --- ESTADO DEL MODO DE SIMULACIÓN ---
  SimulationMode _simulationMode = SimulationMode.singleCycle;
  SimulationMode get simulationMode => _simulationMode;

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


  // --- GlobalKeys para el layout de los buses ---
  final pcKey = GlobalKey();
  final pcAdderKey = GlobalKey();
  final branchAdderKey = GlobalKey();
  final aluKey = GlobalKey();
  final muxCKey = GlobalKey();
  final mux2Key = GlobalKey();
  final mux3Key = GlobalKey();
  final instructionMemoryKey = GlobalKey();
  final dataMemoryKey = GlobalKey();
  final registerFileKey = GlobalKey();
  final controlUnitKey = GlobalKey();
  final extenderKey = GlobalKey();

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

  // --- ESTADO DEL LAYOUT ---
  Map<String, ConnectionPoint> _connectionPoints = {};
  Map<String, ConnectionPoint> get connectionPoints => _connectionPoints;

  // --- ESTADO DEL HOVER DE BUSES ---
  List<BusHoverInfo> _busHoverInfoList = [];
  List<BusHoverInfo> get busHoverInfoList => _busHoverInfoList;

  // --- ESTADO DE LOS VALORES ---

  int _pcValue = 0x00400000;
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

  final Map<String,int> _control_signals={};

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


  int get pcValue => _pcValue;
  String get hoverInfo => _hoverInfo;
  double get sliderValue => _sliderValue;
  int get criticalTime => _criticalTime;

  int get currentMicroCycle => _currentMicroCycle;
  int get totalMicroCycles => _totalMicroCycles;

  Offset get mousePosition => _mousePosition;
  bool get showConnectionLabels => _showConnectionLabels;
  bool get showBusesLabels => _showBusesLabels;

  // Inicializa el estado pidiendo los valores iniciales al servicio.
  Future<void> initialize() async {
    try {
      await _simulationService.initialize();
      _updateBuses();
      final initialState = await _simulationService.reset(mode: _simulationMode);
      // Al inicializar, ponemos el slider al final para mostrar el estado completo.
      _sliderValue = initialState.criticalTime.toDouble();
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


  // Simula la ejecución de un ciclo de reloj
  Future<void> step() async {
    if (_simulationMode == SimulationMode.multiCycle && _totalMicroCycles > 0) {
      _currentMicroCycle++;
      if (_currentMicroCycle >= _totalMicroCycles) {
        // Si completamos los micro-ciclos, pedimos la siguiente instrucción.
        final newState = await _simulationService.step(); // TODO: Aquí hay un error 405
        _updateState(newState); // Esto resetea _currentMicroCycle a 0 y actualiza el estado.
      } else {
        // Si solo avanzamos un micro-ciclo, actualizamos la vista sin llamar al backend.
        _evaluateActiveComponents();
        notifyListeners();
      }
    } else {
      // Lógica para monociclo o para el primer paso de multiciclo
      try {
        final newState = await _simulationService.step(); // TODO: Aquí hay un error 405
        print("Ejecutado step()  ");
        print(newState);
        _sliderValue=newState.criticalTime.toDouble();
        _updateState(newState);
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
      notifyListeners();
    } else {
      // Para monociclo, pipeline, o al inicio de una instrucción multiciclo,
      // llamamos al backend para que restaure el estado anterior completo.
      try {
        final newState = await _simulationService.stepBack();
        _sliderValue = newState.criticalTime.toDouble();
        _updateState(newState);
      } catch (e) {
        // ignore: avoid_print
        print("Error during stepBack: $e");
      }
    }
  }

  // Resetea el estado a sus valores iniciales.
  Future<void> reset() async {
    final newState = await _simulationService.reset(mode: _simulationMode);
    print("Ejecutado reset() con modo: $_simulationMode");
    _sliderValue = 0.0;
    _sliderValue=newState.criticalTime.toDouble();
    _updateState(newState, clearHover: true);
  }

  // Método privado para centralizar la actualización del estado de la UI.
  void _updateState(SimulationState simState, {bool clearHover = false}) {
    _instruction = simState.instruction;
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

    // --- Depuración: Imprime el tiempo crítico recibido ---
    // ignore: avoid_print
    print('Nuevo tiempo crítico recibido: $_criticalTime');
    print('Nuevo tiempo crítico recibido: $_readyAt');

    _evaluateActiveComponents();
    // print("Evaluated active components with readyAt: $_readyAt"); // Opcional para depuración
    if (clearHover) _hoverInfo = "";
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

    _connectionPoints = {for (var p in allPoints) p.label: p};
    notifyListeners();
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
      Bus(startPointLabel: 'PC-2', endPointLabel: 'NPC-2', isActive: (s) => s.isPCActive,waypoints: List.of([const Offset(260,180)]), valueKey: 'pc_bus'),
      Bus(startPointLabel: 'PC-2', endPointLabel: 'IM-0', isActive: (s) => s.isPCActive, valueKey: 'pc_bus'),
      Bus(startPointLabel: 'PC-2', endPointLabel: 'BR-1', isActive: (s) => s.isPCActive,waypoints: List.of([const Offset(260,440)]), valueKey: 'pc_bus'),
      Bus(startPointLabel: 'NPC-3', endPointLabel: 'NPC-4', isActive: (s) => s.isPcAdderActive, valueKey: 'npc_bus'),
      Bus(startPointLabel: 'NPC-4', endPointLabel: 'M2-0', isActive: (s) => s.isPcAdderActive,waypoints: List.of([const Offset(420,80),const Offset(20,80),const Offset(20,228)] ), valueKey: 'npc_bus'),
      Bus(startPointLabel: 'NPC-4', endPointLabel: 'M1-0', isActive: (s) => s.isPcAdderActive,waypoints: List.of([const Offset(1270,150),const Offset(1270,228)] ), valueKey: 'npc_bus'),
      Bus(startPointLabel: 'IM-1', endPointLabel: 'IB-0', isActive: (s) => s.isIMemActive, valueKey: 'instruction_bus'),

      Bus(startPointLabel: 'IB-4', endPointLabel: 'RF-0', isActive: (s) => s.isIMemActive,width: 2, valueKey: 'da_bus',size: 5),
      Bus(startPointLabel: 'IB-5', endPointLabel: 'RF-1', isActive: (s) => s.isIMemActive,width: 2, valueKey: 'db_bus',size: 5),
      Bus(startPointLabel: 'IB-6', endPointLabel: 'RF-2', isActive: (s) => s.isIMemActive,width: 2, valueKey: 'dc_bus',size: 5),
      Bus(startPointLabel: 'IB-7', endPointLabel: 'EXT-0', isActive: (s) => s.isIMemActive, valueKey: 'imm_bus'),

      Bus(startPointLabel: 'EXT-2', endPointLabel: 'BR-0', isActive: (s) => s.isExtenderActive, valueKey: 'immExt_bus'),
      Bus(startPointLabel: 'EXT-3', endPointLabel: 'M3-1', isActive: (s) => s.isExtenderActive,waypoints: List.of([const Offset(820,302)]), valueKey: 'immExt_bus'),
      Bus(startPointLabel: 'BR-2', endPointLabel: 'M2-1', isActive: (s) => s.isBranchAdderActive,waypoints:List.of([const Offset(1000,410),const Offset(1000,500),const Offset(20,500),const Offset(20,248)]  ), valueKey: 'branch_target_bus'),
      Bus(startPointLabel: 'M2-5', endPointLabel: 'PC-0', isActive: (s) => s.isMux2Active, valueKey: 'mux_pc_bus'),
      Bus(startPointLabel: 'RF-5', endPointLabel: 'ALU-0', isActive: (s) => s.isRegFileActive, valueKey: 'rd1_bus'),
      Bus(startPointLabel: 'RF-6', endPointLabel: 'M3-0', isActive: (s) => s.isRegFileActive, valueKey: 'rd2_bus'),
      Bus(startPointLabel: 'RF-7', endPointLabel: 'DM-1', isActive: (s) => s.isRegFileActive,waypoints: List.of([const Offset(770,330),const Offset(1070,330),const Offset(1070,290)]), valueKey: 'rd2_bus'),
      Bus(startPointLabel: 'M3-3', endPointLabel: 'ALU-1', isActive: (s) => s.isMux3Active, valueKey: 'mux_alu_b_bus'),
      Bus(startPointLabel: 'ALU-4', endPointLabel: 'DM-0', isActive: (s) => s.isAluActive, valueKey: 'alu_result_bus'),
      Bus(startPointLabel: 'ALU-5', endPointLabel: 'M1-1', isActive: (s) => s.isAluActive,waypoints: List.of([const Offset(1070,175),const Offset(1250,175),const Offset(1250,248)]), valueKey: 'alu_result_bus'),
      Bus(startPointLabel: 'DM-3', endPointLabel: 'M1-2', isActive: (s) => s.isDMemActive, valueKey: 'mem_read_data_bus'),
      Bus(startPointLabel: 'M1-5', endPointLabel: 'RF-3', isActive: (s) => s.isMuxCActive,waypoints:List.of([const Offset(1410,260),const Offset(1410,520),const Offset(600,520),const Offset(600,296)]  ), valueKey: 'mux_wb_bus'),
      
      Bus(startPointLabel: 'ALU-3', endPointLabel: 'CU-7', isActive: (s) => s.isAluActive,waypoints: List.of([const Offset(1050,242)]),isState: true,size:1,valueKey:"flagZ"),
      Bus(startPointLabel: 'IB-1', endPointLabel: 'CU-1', isActive: (s) => s.isIMemActive,waypoints: List.of([const Offset(480,172)]),isState: true,valueKey:"opcode",size:7),
      Bus(startPointLabel: 'IB-2', endPointLabel: 'CU-2', isActive: (s) => s.isIMemActive,waypoints: List.of([const Offset(560,184)]),isState: true,valueKey:"funct3",size:3),
      Bus(startPointLabel: 'IB-3', endPointLabel: 'CU-3', isActive: (s) => s.isIMemActive,waypoints: List.of([const Offset(615,196)]),isState: true,valueKey:"funct7",size:7),

      Bus(startPointLabel: 'CU-0', endPointLabel: 'M2-4', isActive: (s) => s.isPCsrcActive,waypoints: List.of([const Offset(75,-30)]),isControl: true,size:2,valueKey: "control_PCsrc"),
      Bus(startPointLabel: 'CU-4', endPointLabel: 'RF-4', isActive: (s) => s.isControlActive,isControl: true,size:1,valueKey: "control_BRwr"),
      Bus(startPointLabel: 'CU-5', endPointLabel: 'M3-2', isActive: (s) => s.isControlActive,isControl: true,size:1,valueKey: "control_ALUsrc"),
      Bus(startPointLabel: 'CU-6', endPointLabel: 'ALU-2', isActive: (s) => s.isControlActive,isControl: true,size:3,valueKey: "control_ALUctr"),
      Bus(startPointLabel: 'CU-8', endPointLabel: 'DM-2', isActive: (s) => s.isControlActive,isControl: true,size:1,valueKey: "control_MemWr"),
      Bus(startPointLabel: 'CU-9', endPointLabel: 'M1-4', isActive: (s) => s.isControlActive,isControl: true,size:2,valueKey: "control_ResSrc"),
      Bus(startPointLabel: 'CU-10', endPointLabel: 'EXT-1', isActive: (s) => s.isControlActive,waypoints: List.of([const Offset(1425,-25),const Offset(1425,510),const Offset(670,510)]),isControl: true,size:3,valueKey: "control_ImmSrc"),
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
    bus.isActive = (s) => s.isPathActive('Pipe_IF_ID_Instr');
    bus=buses.firstWhere((bus) => bus.startPointLabel == 'IB-5' && bus.endPointLabel == 'RF-1');
    bus.isActive = (s) => s.isPathActive('Pipe_IF_ID_Instr');
    bus=buses.firstWhere((bus) => bus.startPointLabel == 'IB-7' && bus.endPointLabel == 'EXT-0');
    bus.isActive = (s) => s.isPathActive('Pipe_IF_ID_Instr');

    bus=buses.firstWhere((bus) => bus.startPointLabel == 'IB-1' && bus.endPointLabel == 'CU-1');
    bus.isActive = (s) => s.isPathActive('Pipe_IF_ID_Instr');
    bus=buses.firstWhere((bus) => bus.startPointLabel == 'IB-2' && bus.endPointLabel == 'CU-2');
    bus.isActive = (s) => s.isPathActive('Pipe_IF_ID_Instr');
    bus=buses.firstWhere((bus) => bus.startPointLabel == 'IB-3' && bus.endPointLabel == 'CU-3');
    bus.isActive = (s) => s.isPathActive('Pipe_IF_ID_Instr');

    bus=buses.firstWhere((bus) => bus.startPointLabel == 'EXT-3' && bus.endPointLabel == 'M3-1');
    bus.isActive = (s) => s.isPathActive('Pipe_ID_EX_Imm');
    bus.valueKey = 'Pipe_ID_EX_Imm';

    bus=buses.firstWhere((bus) => bus.startPointLabel == 'BR-2' && bus.endPointLabel == 'M2-1');
    bus.isActive = (s) => s.isPathActive('branch_target_bus');
    bus.valueKey = 'branch_target_bus';


    if(isMultiCycle){
    bus=buses.firstWhere((bus) => bus.startPointLabel == 'IB-6' && bus.endPointLabel == 'RF-2');
    bus.isActive = (s) => s.isPathActive('Pipe_IF_ID_Instr');
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
        Bus(startPointLabel: 'DE1-4', endPointLabel: 'ALU-0', isActive: (s) => s.isPathActive('Pipe_ID_EX_A'), valueKey: 'Pipe_ID_EX_A'),

        Bus(startPointLabel: 'RF-6', endPointLabel: 'DE1-1', isActive: (s) => s.isPathActive('rd2_bus'), valueKey: 'rd2_bus'),
        Bus(startPointLabel: 'DE1-5', endPointLabel: 'M3-0', isActive: (s) => s.isPathActive('Pipe_ID_EX_B'), valueKey: 'Pipe_ID_EX_B'),
        
        Bus(startPointLabel: 'RF-7', endPointLabel: 'EM1-2', isActive: (s) => s.isPathActive('Pipe_ID_EX_B'), valueKey: 'Pipe_ID_EX_B',waypoints:List.of([const Offset(770,331)])),
        Bus(startPointLabel: 'EM1-6', endPointLabel: 'DM-1', isActive: (s) => s.isPathActive('Pipe_EX_MEM_B'), valueKey: 'Pipe_EX_MEM_B',waypoints:List.of([const Offset(1070,331),const Offset(1070,290)])),
        
        Bus(startPointLabel: 'DM-3', endPointLabel: 'MW1-1', isActive: (s) => s.isPathActive('Pipe_EX_MEM_B'), valueKey: 'mem_read_data_bus'),
        Bus(startPointLabel: 'MW1-4', endPointLabel: 'M1-2', isActive: (s) => s.isPathActive('Pipe_MEM_WB_RM'), valueKey: 'Pipe_MEM_WB_RM'),
      
      //Bus(startPointLabel: 'EXT-2', endPointLabel: 'BR-0', isActive: (s) => s.isExtenderActive, valueKey: 'immExt_bus'),
        Bus(startPointLabel: 'EXT-2', endPointLabel: 'DE1-3', isActive: (s) => s.isPathActive('immExt_bus'), valueKey: 'immExt_bus'),
        Bus(startPointLabel: 'DE1-7', endPointLabel: 'BR-0', isActive: (s) => s.isPathActive('Pipe_ID_EX_Imm'), valueKey: 'Pipe_ID_EX_Imm',waypoints:List.of([])),

            //Bus(startPointLabel: 'ALU-5', endPointLabel: 'M1-1', isActive: (s) => s.isAluActive,waypoints: List.of([const Offset(1070,175),const Offset(1250,175),const Offset(1250,248)]), valueKey: 'alu_result_bus'),
        Bus(startPointLabel: 'ALU-5', endPointLabel: 'MW1-0', isActive: (s) => s.isPathActive('Pipe_EX_MEM_ALU_result'), valueKey: 'Pipe_EX_MEM_ALU_result',waypoints:List.of([const Offset(1070,175)])),
        Bus(startPointLabel: 'MW1-3', endPointLabel: 'M1-1', isActive: (s) => s.isPathActive('Pipe_MEM_WB_ALU_result'), valueKey: 'Pipe_MEM_WB_ALU_result',waypoints:List.of([const Offset(1250,175),const Offset(1250,248)])),


    //Bus(startPointLabel: 'ALU-4', endPointLabel: 'DM-0', isActive: (s) => s.isAluActive, valueKey: 'alu_result_bus'),
        Bus(startPointLabel: 'ALU-4', endPointLabel: 'EM1-1', isActive: (s) => s.isPathActive('alu_result_bus'), valueKey: 'alu_result_bus'),
        Bus(startPointLabel: 'EM1-5', endPointLabel: 'DM-0', isActive: (s) => s.isPathActive('Pipe_EX_MEM_ALU_result'), valueKey: 'Pipe_EX_MEM_ALU_result'),

      

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
       Bus(startPointLabel: 'IB-6', endPointLabel: 'DE1-2', isActive: (s) => s.isPathActive('dc_bus'),width: 2, valueKey: 'dc_bus',size: 5,waypoints:List.of([const Offset(545,272),const Offset(545,345)])),
       Bus(startPointLabel: 'DE1-6', endPointLabel: 'EM1-3', isActive: (s) => s.isPathActive('Pipe_ID_EX_RD'),width: 2, valueKey: 'Pipe_ID_EX_RD',size: 5),
       Bus(startPointLabel: 'EM1-7', endPointLabel: 'MW1-2', isActive: (s) => s.isPathActive('Pipe_EX_MEM_RD'),width: 2, valueKey: 'Pipe_EX_MEM_RD',size: 5), // El valor se propaga
       Bus(startPointLabel: 'MW1-5', endPointLabel: 'RF-2', isActive: (s) => s.isPathActive('Pipe_MEM_WB_RD'),width: 2, valueKey: 'Pipe_MEM_WB_RD',size: 5,waypoints:List.of([const Offset(1430,345),const Offset(1430,510),const Offset(590,510),const Offset(590,272)])),

    //Bus(startPointLabel: 'NPC-4', endPointLabel: 'M1-0', isActive: (s) => s.isPcAdderActive,waypoints: List.of([const Offset(1270,150),const Offset(1270,228)] ), valueKey: 'npc_bus'),
      
        Bus(startPointLabel: 'NPC-4', endPointLabel: 'FD0-0', isActive: (s) => true, valueKey: 'npc_bus'),
        Bus(startPointLabel: 'FD0-1', endPointLabel: 'DE0-0', isActive: (s) => s.isPathActive('Pipe_IF_ID_NPC'), valueKey: 'Pipe_IF_ID_NPC'),
        Bus(startPointLabel: 'DE0-1', endPointLabel: 'EM0-0', isActive: (s) => s.isPathActive('Pipe_ID_EX_NPC'), valueKey: 'Pipe_ID_EX_NPC'),
        Bus(startPointLabel: 'EM0-1', endPointLabel: 'MW0-0', isActive: (s) => s.isPathActive('Pipe_EX_MEM_NPC'), valueKey: 'Pipe_EX_MEM_NPC'),
        Bus(startPointLabel: 'MW0-1', endPointLabel: 'M1-0', isActive: (s) => s.isPathActive('Pipe_MEM_WB_NPC'), valueKey: 'Pipe_MEM_WB_NPC',waypoints:List.of([const Offset(1270,150),const Offset(1270,228)])),

    //Bus(startPointLabel: 'PC-2', endPointLabel: 'BR-1', isActive: (s) => s.isPCActive,waypoints: List.of([const Offset(260,440)]), valueKey: 'pc_bus'),

        Bus(startPointLabel: 'PC-2', endPointLabel: 'FD1-0', isActive: (s) => true, valueKey: 'pc_bus',waypoints:List.of([const Offset(260,440)])),
        Bus(startPointLabel: 'FD1-1', endPointLabel: 'DE2-0', isActive: (s) => s.isPathActive('Pipe_IF_ID_PC'), valueKey: 'Pipe_IF_ID_PC'),
        Bus(startPointLabel: 'DE2-1', endPointLabel: 'BR-1', isActive: (s) => s.isPathActive('Pipe_ID_EX_PC'), valueKey: 'Pipe_ID_EX_PC'),



    //Bus(startPointLabel: 'M2-5', endPointLabel: 'PC-0', isActive: (s) => s.isMux2Active, valueKey: 'mux_pc_bus'),
        Bus(startPointLabel: 'M2-5', endPointLabel: 'PC-0', isActive: (s) => s.isMux2Active, valueKey: 'mux_pc_bus'),  //Ejemplo de borrar un mismo bus y sustituirlo por otro para cambiar el comportamiento con el pipeline

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
    // para no ocultar nada por error.
    return _activePaths[componentName] ?? true;
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