import 'package:flutter/material.dart';
import 'services/simulation_service.dart';
import 'simulation_mode.dart';

/// Define la estructura de un bus de conexión en el datapath.
class Bus {
  final String startPointLabel; // Etiqueta del punto de inicio (ej: 'PC-1')
  final String endPointLabel;   // Etiqueta del punto final (ej: 'IM-0')
  List<Offset> waypoints; // Puntos intermedios para el trazado (opcional)
  final bool Function(DatapathState) isActive; // Función para determinar si está activo
  final String? valueKey; // Clave para buscar el valor en el mapa de buses (ej: 'pc_bus')
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
  final pipereg_b_Key = GlobalKey();

  final pipereg_em1_Key = GlobalKey();
  final pipereg_mw1_Key = GlobalKey();


  int _pcValue = 0x00400000;
  String _instruction = "";
  int _instructionValue = 0;
  int _statusRegister = 0;
  Map<String, int> _registers = {};
  Map<String, int> _busValues = {};

  final Map<String,int> _control_signals={};

  // --- DEFINICIÓN DE BUSES ---
  // La lista de buses ahora es variable y se actualiza según el modo.
  List<Bus> _buses = [];
  List<Bus> get buses => _buses;

  String _hoverInfo = ""; // Texto a mostrar en el hover.
  double _sliderValue = 0.0; // Nuevo estado para el slider.
  Offset _mousePosition = Offset.zero; // Para las coordenadas del ratón
  bool _showConnectionLabels = false;

  // --- GETTERS (para que los widgets lean el estado) ---
  String get instruction => _instruction;
  int get instructionValue => _instructionValue;
  int get statusRegister => _statusRegister;
  Map<String, int> get registers => _registers;
  Map<String, int> get busValues => _busValues;
  Map<String, bool> get activePaths => _activePaths;

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

  // Inicializa el estado pidiendo los valores iniciales al servicio.
  Future<void> initialize() async {
    try {
      await _simulationService.initialize();
      _updateBuses();
      final initialState = await _simulationService.reset(mode: _simulationMode);
      // Al inicializar, ponemos el slider al final para mostrar el estado completo.
      _sliderValue = initialState.criticalTime.toDouble();
      _updateState(initialState, clearHover: true);
    } catch (e) {
      // ignore: avoid_print
      print("Error durante la inicialización del simulador: $e");
      // Aquí podrías establecer un estado de error para mostrarlo en la UI.
    }
  }

  // --- MÉTODOS PARA MODIFICAR EL ESTADO ---

  // Actualiza el modo de simulación.
  void setSimulationMode(SimulationMode? newMode) {
    if (newMode != null && _simulationMode != newMode) {
      _simulationMode = newMode;
      _updateBuses(); // ¡La clave! Regenera los buses para el nuevo modo.
      // ignore: avoid_print
      print("Cambiando a modo: $newMode");
      notifyListeners();
      reset(); // Opcional: resetea la simulación al cambiar de modo.
    }
  }

  void setShowConnectionLabels(bool? value) {
    if (value != null && _showConnectionLabels != value) {
      _showConnectionLabels = value;
      notifyListeners();
    }
  }

  // Simula la ejecución de un ciclo de reloj
  Future<void> step() async {
    if (_simulationMode == SimulationMode.multiCycle && _totalMicroCycles > 0) {
      _currentMicroCycle++;
      if (_currentMicroCycle >= _totalMicroCycles) {
        // Si completamos los micro-ciclos, pedimos la siguiente instrucción.
        final newState = await _simulationService.step();
        _updateState(newState); // Esto resetea _currentMicroCycle a 0 y actualiza el estado.
      } else {
        // Si solo avanzamos un micro-ciclo, actualizamos la vista sin llamar al backend.
        _evaluateActiveComponents();
        notifyListeners();
      }
    } else {
      // Lógica para monociclo o para el primer paso de multiciclo
      try {
        final newState = await _simulationService.step();
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
    _hoverInfo = info;
    notifyListeners();
  }

  // Actualiza la posición del ratón
  void setMousePosition(Offset position) {
    _mousePosition = position;
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

  /// Actualiza la lista de buses según el modo de simulación actual.
  void _updateBuses() {
    _buses.clear();
    switch (_simulationMode) {
      case SimulationMode.singleCycle:
        _buses.addAll(_getSingleCycleBuses());
        break;
      case SimulationMode.multiCycle:
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
      Bus(startPointLabel: 'IB-7', endPointLabel: 'EXT-0', isActive: (s) => s.isIMemActive, valueKey: 'instruction_bus'),
      Bus(startPointLabel: 'EXT-2', endPointLabel: 'BR-0', isActive: (s) => s.isExtenderActive, valueKey: 'immediate_bus'),
      Bus(startPointLabel: 'EXT-3', endPointLabel: 'M3-1', isActive: (s) => s.isExtenderActive,waypoints: List.of([const Offset(820,302)]), valueKey: 'immediate_bus'),
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
      Bus(startPointLabel: 'ALU-3', endPointLabel: 'CU-7', isActive: (s) => s.isAluActive,waypoints: List.of([const Offset(1050,242)]),isState: true),
      Bus(startPointLabel: 'IB-1', endPointLabel: 'CU-1', isActive: (s) => s.isIMemActive,waypoints: List.of([const Offset(488,172)]),isState: true),
      Bus(startPointLabel: 'IB-2', endPointLabel: 'CU-2', isActive: (s) => s.isIMemActive,waypoints: List.of([const Offset(553,184)]),isState: true),
      Bus(startPointLabel: 'IB-3', endPointLabel: 'CU-3', isActive: (s) => s.isIMemActive,waypoints: List.of([const Offset(617,196)]),isState: true),
      Bus(startPointLabel: 'CU-0', endPointLabel: 'M2-4', isActive: (s) => s.isPCsrcActive,waypoints: List.of([const Offset(75,-30)]),isControl: true),
      Bus(startPointLabel: 'CU-4', endPointLabel: 'RF-4', isActive: (s) => s.isControlActive,isControl: true),
      Bus(startPointLabel: 'CU-5', endPointLabel: 'M3-2', isActive: (s) => s.isControlActive,isControl: true),
      Bus(startPointLabel: 'CU-6', endPointLabel: 'ALU-2', isActive: (s) => s.isControlActive,isControl: true),
      Bus(startPointLabel: 'CU-8', endPointLabel: 'DM-2', isActive: (s) => s.isControlActive,isControl: true),
      Bus(startPointLabel: 'CU-9', endPointLabel: 'M1-4', isActive: (s) => s.isControlActive,isControl: true),
      Bus(startPointLabel: 'CU-10', endPointLabel: 'EXT-1', isActive: (s) => s.isControlActive,waypoints: List.of([const Offset(1425,-30),const Offset(1425,510),const Offset(670,510)]),isControl: true),
    ];
  }

  /// Devuelve la lista de buses para el datapath segmentado (pipeline).
  List<Bus> _getPipelineBuses() {
    // Copiamos la base del monociclo y la modificamos.
    // ¡Aquí es donde se ve la potencia de este enfoque!
    final pipelineBuses = _getSingleCycleBuses();

    // Ejemplo: Redirigir el bus del sumador del PC para que pase por el registro de pipeline NPC1.
    // 1. Eliminamos el bus directo del sumador al Mux.
    //pipelineBuses.removeWhere((bus) => bus.startPointLabel == 'NPC-4' && bus.endPointLabel == 'M2-0');
    
    pipelineBuses.removeWhere((bus) => bus.startPointLabel == 'IB-6' && bus.endPointLabel == 'RF-2'); //Redibujamos bus para que propage registro destino

    if(false){
    
    pipelineBuses.removeWhere((bus) => bus.startPointLabel == 'NPC-4' && bus.endPointLabel == 'M1-0'); //Redibujamos bus para que propage registro destino
    pipelineBuses.removeWhere((bus) => bus.startPointLabel == 'EXT-2' && bus.endPointLabel == 'BR-0'); //Redibujamos bus para que propage registro destino
    pipelineBuses.removeWhere((bus) => bus.startPointLabel == 'PC-2' && bus.endPointLabel == 'BR-1'); //Redibujamos bus para que propage registro destino
    pipelineBuses.removeWhere((bus) => bus.startPointLabel == 'RF-5' && bus.endPointLabel == 'ALU-0'); //Redibujamos bus para que propage registro destino
    pipelineBuses.removeWhere((bus) => bus.startPointLabel == 'RF-6' && bus.endPointLabel == 'M3-0'); //Redibujamos bus para que propage registro destino
    pipelineBuses.removeWhere((bus) => bus.startPointLabel == 'RF-7' && bus.endPointLabel == 'DM-1'); //Redibujamos bus para que propage registro destino
    pipelineBuses.removeWhere((bus) => bus.startPointLabel == 'ALU-4' && bus.endPointLabel == 'DM-0'); //Redibujamos bus para que propage registro destino
    pipelineBuses.removeWhere((bus) => bus.startPointLabel == 'ALU-5' && bus.endPointLabel == 'M1-1'); //Redibujamos bus para que propage registro destino
    pipelineBuses.removeWhere((bus) => bus.startPointLabel == 'DM-3' && bus.endPointLabel == 'M1-2'); //Redibujamos bus para que propage registro destino
    }

    pipelineBuses.addAll([
       // solo para ver por donde Bus(startPointLabel: 'IB-6', endPointLabel: 'RF-2', isActive: (s) => s.isIMemActive,width: 2, valueKey: 'dc_bus',size: 5,waypoints:List.of([const Offset(545,272),const Offset(545,345),const Offset(1430,345),const Offset(1430,510),const Offset(590,510),const Offset(590,272)])),
       Bus(startPointLabel: 'IB-6', endPointLabel: 'DE1-2', isActive: (s) => s.isIMemActive,width: 2, valueKey: 'dc_bus',size: 5,waypoints:List.of([const Offset(545,272),const Offset(545,345)])),
       Bus(startPointLabel: 'DE1-6', endPointLabel: 'EM1-3', isActive: (s) => s.isIMemActive,width: 2, valueKey: 'dc_bus',size: 5),
       Bus(startPointLabel: 'EM1-7', endPointLabel: 'MW1-2', isActive: (s) => s.isIMemActive,width: 2, valueKey: 'dc_bus',size: 5),
       Bus(startPointLabel: 'MW1-5', endPointLabel: 'RF-2', isActive: (s) => s.isIMemActive,width: 2, valueKey: 'dc_bus',size: 5,waypoints:List.of([const Offset(1430,345),const Offset(1430,510),const Offset(590,510),const Offset(590,272)])),

    ]);

    pipelineBuses.removeWhere((bus)=>bus.isControl);

    // 2. Añadimos los nuevos buses que pasan por el registro.
    //if(true)
    pipelineBuses.addAll([
      // Sumador del PC -> Registro NPC1
      //Bus(startPointLabel: 'NPC-4',endPointLabel: 'FD0-0',isActive: (s) => s.isPcAdderActive,valueKey: 'npc_bus',),
      // Registro NPC1 -> Mux del PC
      //Bus(startPointLabel: 'FD0-1',endPointLabel: 'M2-0',isActive: (s) => s.isPcAdderActive, valueKey: 'npc_bus',waypoints: [const Offset(535, 80), const Offset(20, 80), const Offset(20, 228)],),
    ]);

    return pipelineBuses;
  }





  // Evalúa qué componentes están activos en función del valor del slider y el mapa _readyAt.
  void _evaluateActiveComponents() {
    if (_simulationMode == SimulationMode.multiCycle) {
      // Lógica para Multiciclo: se basa en el micro-ciclo actual.
      // Usamos el `ready_at` que ahora contiene el número de microciclo.
      _isPCActive = _isComponentReady('pc_bus');
      _isPcAdderActive = _isComponentReady('npc_bus');
      _isIMemActive = _isComponentReady('instruction_bus');
      _isIBActive = _isComponentReady('instruction_bus');
      _isControlActive = _isComponentReady('control_bus');
      _isPCsrcActive = _isComponentReady('pcsrc_bus');
      _isRegFileActive = _isComponentReady('rd1_bus') || _isComponentReady('rd2_bus');
      _isExtenderActive = _isComponentReady('immediate_bus');
      _isAluActive = _isComponentReady('alu_result_bus');
      _isBranchAdderActive = _isComponentReady('branch_target_bus');
      // La memoria de datos está activa si se lee O se escribe, y la ruta correspondiente está activa.
      _isDMemActive = (_isComponentReady('mem_read_data_bus')&& _isInstruction('lw')) || (_isComponentReady('mem_write_data_bus')&& _isInstruction('sw'));
      _isMuxCActive = _isComponentReady('mux_wb_bus');
      _isMux2Active = _isComponentReady('mux_pc_bus');
      _isMux3Active = _isComponentReady('mux_alu_b_bus');
    } else {
      // Lógica original para Monociclo: se basa en el slider.
      _evaluateSingleCycleActiveComponents();
    }
  }

  void _evaluateSingleCycleActiveComponents() {
      _isPCActive = _isComponentReadySlider('pc_bus') && _isPathActive('pc_bus');
      _isPcAdderActive = _isComponentReadySlider('npc_bus') && _isPathActive('npc_bus');
      _isIMemActive = _isComponentReadySlider('instruction_bus') && _isPathActive('instruction_bus');
      _isIBActive = _isComponentReadySlider('instruction_bus') && _isPathActive('instruction_bus');
      _isControlActive = _isComponentReadySlider('control_bus');
      _isPCsrcActive = _isComponentReadySlider('pcsrc_bus');
      _isRegFileActive = (_isComponentReadySlider('rd1_bus') && _isPathActive('rd1_bus')) ||
                         (_isComponentReadySlider('rd2_bus') && _isPathActive('rd2_bus'));
      _isExtenderActive = _isComponentReadySlider('immediate_bus') && _isPathActive('immediate_bus');
      _isAluActive = _isComponentReadySlider('alu_result_bus') && _isPathActive('alu_result_bus');
      _isBranchAdderActive = _isComponentReadySlider('branch_target_bus') && _isPathActive('branch_target_bus');
      // Para 'sw', el bus de lectura no está activo, pero la memoria sí.
      // Usamos el bus de resultado de la ALU como señal de tiempo para 'sw', ya que proporciona la dirección.
      _isDMemActive = (_isComponentReadySlider('mem_read_data_bus') || _isComponentReadySlider('alu_result_bus')) && _isMemoryInstruction();
      _isMuxCActive = _isComponentReadySlider('mux_wb_bus') && _isPathActive('mux_wb_bus');
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
  bool _isComponentReady(String componentName) {
    final readyAtCycle = _readyAt[componentName] ?? 99; // Un ciclo inalcanzable
    return _currentMicroCycle >= readyAtCycle;
  }

  // Helper para comprobar si una ruta es lógicamente activa.
  bool _isPathActive(String componentName) {
    // Si el backend no nos informa sobre una ruta, asumimos que es activa por defecto
    // para no ocultar nada por error.
    return _activePaths[componentName] ?? true;
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