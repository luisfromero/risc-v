import 'package:flutter/material.dart';
import 'services/simulation_service.dart';

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

  // --- ESTADO DE LA SIMULACIÓN (TIMING) ---
  int _criticalTime = 100;      // Tiempo total del ciclo, para el slider.
  Map<String, int> _readyAt = {};
  Map<String, bool> _activePaths = {};

  // --- ESTADO DEL DATAPATH ---
  bool _isPcAdderActive = false;
  bool _isBranchAdderActive = false;
  bool _isAluActive = false;
  bool _isMux1Active = false;
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
  final mux1Key = GlobalKey();
  final mux2Key = GlobalKey();
  final mux3Key = GlobalKey();
  final instructionMemoryKey = GlobalKey();
  final dataMemoryKey = GlobalKey();
  final registerFileKey = GlobalKey();
  final controlUnitKey = GlobalKey();
  final extenderKey = GlobalKey();

  final stackKey = GlobalKey();
  final ibKey = GlobalKey();


  int _pcValue = 0x00400000;
  String _instruction = "";
  int _instructionValue = 0;
  int _statusRegister = 0;
  Map<String, int> _registers = {};
  Map<String, int> _busValues = {};

  final Map<String,int> _control_signals={};

  // --- DEFINICIÓN DE BUSES ---
  // Aquí definimos todo el "cableado" del datapath.
  final List<Bus> buses = [
    Bus(startPointLabel: 'NPC-0', endPointLabel: 'NPC-1', isActive: (s) => true, valueKey: 'npc_bus'),

    // Salida del PC se reparte a 3 sitios (efecto "joint" o "BusGroup")
    Bus(startPointLabel: 'PC-1', endPointLabel: 'PC-2', isActive: (s) => s.isPCActive, valueKey: 'pc_bus'),
    Bus(startPointLabel: 'PC-2', endPointLabel: 'NPC-2', isActive: (s) => s.isPCActive,waypoints: List.of([Offset(260,180)]), valueKey: 'pc_bus'),
    Bus(startPointLabel: 'PC-2', endPointLabel: 'IM-0', isActive: (s) => s.isPCActive, valueKey: 'pc_bus'),
    Bus(startPointLabel: 'PC-2', endPointLabel: 'BR-1', isActive: (s) => s.isPCActive,waypoints: List.of([Offset(260,440)]), valueKey: 'pc_bus'),

        // Sumador del PC a Mux del PC
    Bus(startPointLabel: 'NPC-3', endPointLabel: 'NPC-4', isActive: (s) => s.isPcAdderActive, valueKey: 'npc_bus'),
    Bus(startPointLabel: 'NPC-4', endPointLabel: 'M2-0', isActive: (s) => s.isPcAdderActive,waypoints: List.of([Offset(420,80),Offset(20,80),Offset(20,228)] ), valueKey: 'npc_bus'),
    Bus(startPointLabel: 'NPC-4', endPointLabel: 'M1-0', isActive: (s) => s.isPcAdderActive,waypoints: List.of([Offset(1270,150),Offset(1270,228)] ), valueKey: 'npc_bus'),


    Bus(startPointLabel: 'IM-1', endPointLabel: 'IB-0', isActive: (s) => s.isIMemActive, valueKey: 'instruction_bus'),
    Bus(startPointLabel: 'IB-4', endPointLabel: 'RF-0', isActive: (s) => s.isIMemActive,width: 2, valueKey: 'da_bus',size: 5),
    Bus(startPointLabel: 'IB-5', endPointLabel: 'RF-1', isActive: (s) => s.isIMemActive,width: 2, valueKey: 'db_bus',size: 5),
    Bus(startPointLabel: 'IB-6', endPointLabel: 'RF-2', isActive: (s) => s.isIMemActive,width: 2, valueKey: 'dc_bus',size: 5),
    Bus(startPointLabel: 'IB-7', endPointLabel: 'EXT-0', isActive: (s) => s.isIMemActive, valueKey: 'instruction_bus'),

    Bus(startPointLabel: 'EXT-2', endPointLabel: 'BR-0', isActive: (s) => s.isExtenderActive, valueKey: 'immediate_bus'),
    Bus(startPointLabel: 'EXT-3', endPointLabel: 'M3-1', isActive: (s) => s.isExtenderActive,waypoints: List.of([Offset(820,302)]), valueKey: 'immediate_bus'),

    Bus(startPointLabel: 'BR-2', endPointLabel: 'M2-1', isActive: (s) => s.isBranchAdderActive,waypoints:List.of([Offset(1000,410),Offset(1000,500),Offset(20,500),Offset(20,248)]  ), valueKey: 'branch_target_bus'),

    // Salida del Mux del PC a la entrada del PC
    Bus(startPointLabel: 'M2-5', endPointLabel: 'PC-0', isActive: (s) => s.isMux2Active, valueKey: 'mux_pc_bus'),

    Bus(startPointLabel: 'RF-5', endPointLabel: 'ALU-0', isActive: (s) => s.isRegFileActive, valueKey: 'rd1_bus'),
    Bus(startPointLabel: 'RF-6', endPointLabel: 'M3-0', isActive: (s) => s.isRegFileActive, valueKey: 'rd2_bus'),
    Bus(startPointLabel: 'RF-7', endPointLabel: 'DM-1', isActive: (s) => s.isRegFileActive,waypoints: List.of([Offset(770,330),Offset(1050,330),Offset(1050,290)]), valueKey: 'rd2_bus'),

    Bus(startPointLabel: 'M3-3', endPointLabel: 'ALU-1', isActive: (s) => s.isMux3Active, valueKey: 'mux_alu_b_bus'),

    Bus(startPointLabel: 'ALU-4', endPointLabel: 'DM-0', isActive: (s) => s.isAluActive, valueKey: 'alu_result_bus'),
    Bus(startPointLabel: 'ALU-5', endPointLabel: 'M1-1', isActive: (s) => s.isAluActive,waypoints: List.of([Offset(1070,190),Offset(1250,190),Offset(1250,248)]), valueKey: 'alu_result_bus'),
    
    Bus(startPointLabel: 'DM-3', endPointLabel: 'M1-2', isActive: (s) => s.isDMemActive, valueKey: 'mem_read_data_bus'),

    Bus(startPointLabel: 'M1-5', endPointLabel: 'RF-3', isActive: (s) => s.isMux1Active,waypoints:List.of([Offset(1400,260),Offset(1400,340),Offset(600,340),Offset(600,296)]  ), valueKey: 'mux_wb_bus'),


// Señales de estado

    Bus(startPointLabel: 'ALU-3', endPointLabel: 'CU-7', isActive: (s) => s.isAluActive,waypoints: List.of([Offset(1032,242)]),isState: true),
    Bus(startPointLabel: 'IB-1', endPointLabel: 'CU-1', isActive: (s) => s.isIMemActive,waypoints: List.of([Offset(488,172)]),isState: true),
    Bus(startPointLabel: 'IB-2', endPointLabel: 'CU-2', isActive: (s) => s.isIMemActive,waypoints: List.of([Offset(553,184)]),isState: true),
    Bus(startPointLabel: 'IB-3', endPointLabel: 'CU-3', isActive: (s) => s.isIMemActive,waypoints: List.of([Offset(617,196)]),isState: true),

    Bus(startPointLabel: 'CU-0', endPointLabel: 'M2-4', isActive: (s) => s.isPCsrcActive,waypoints: List.of([Offset(75,-30)]),isControl: true),

    Bus(startPointLabel: 'CU-4', endPointLabel: 'RF-4', isActive: (s) => s.isControlActive,isControl: true),
    Bus(startPointLabel: 'CU-5', endPointLabel: 'M3-2', isActive: (s) => s.isControlActive,isControl: true),
    Bus(startPointLabel: 'CU-6', endPointLabel: 'ALU-2', isActive: (s) => s.isControlActive,isControl: true),
    Bus(startPointLabel: 'CU-8', endPointLabel: 'DM-2', isActive: (s) => s.isControlActive,isControl: true),
    Bus(startPointLabel: 'CU-9', endPointLabel: 'M1-4', isActive: (s) => s.isControlActive,isControl: true),
    Bus(startPointLabel: 'CU-10', endPointLabel: 'EXT-1', isActive: (s) => s.isControlActive,waypoints: List.of([Offset(1425,-30),Offset(1425,510),Offset(670,510)]),isControl: true),
    

  ];

  






  String _hoverInfo = ""; // Texto a mostrar en el hover.
  double _sliderValue = 0.0; // Nuevo estado para el slider.
  Offset _mousePosition = Offset.zero; // Para las coordenadas del ratón

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
  bool get isMux1Active => _isMux1Active;
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
  Offset get mousePosition => _mousePosition;

  // Inicializa el estado pidiendo los valores iniciales al servicio.
  Future<void> initialize() async {
    try {
      await _simulationService.initialize();
      final initialState = await _simulationService.reset();
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

  // Simula la ejecución de un ciclo de reloj
  Future<void> step() async {
    try {
      final newState = await _simulationService.step();
    print("Ejecutado step()  ");
    print(newState);
      _sliderValue = 0.0; // Reinicia el slider al principio del nuevo ciclo
      _sliderValue=newState.criticalTime.toDouble();
      _updateState(newState);
    } catch (e) {
      // ignore: avoid_print
      print("Error during step: $e");
    }
  }

  // Resetea el estado a sus valores iniciales.
  Future<void> reset() async {
    final newState = await _simulationService.reset();
    print("Ejecutado reset()  ");
    print(newState);
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






  // Evalúa qué componentes están activos en función del valor del slider y el mapa _readyAt.
  void _evaluateActiveComponents() {
    // Esta función es el núcleo de la visualización controlada por el slider.
    // Compara el valor actual del slider con los porcentajes de "listo en" de cada componente.

    // Las claves ('pc_bus', 'npc_bus', etc.) DEBEN coincidir con las que envía el backend.
    _isPCActive = _isComponentReady('pc_bus') && _isPathActive('pc_bus');
    _isPcAdderActive = _isComponentReady('npc_bus') && _isPathActive('npc_bus');
    _isIMemActive = _isComponentReady('instruction_bus') && _isPathActive('instruction_bus');
    _isIBActive = _isComponentReady('instruction_bus') && _isPathActive('instruction_bus');
    _isControlActive = _isComponentReady('control_bus'); // La unidad de control siempre es "útil" si está lista
    _isPCsrcActive = _isComponentReady('pcsrc_bus'); // La señal de control siempre es "útil"
    _isRegFileActive = (_isComponentReady('rd1_bus') && _isPathActive('rd1_bus')) ||
                       (_isComponentReady('rd2_bus') && _isPathActive('rd2_bus'));
    _isExtenderActive = _isComponentReady('immediate_bus') && _isPathActive('immediate_bus');
    _isAluActive = _isComponentReady('alu_result_bus') && _isPathActive('alu_result_bus');
    _isBranchAdderActive = _isComponentReady('branch_target_bus') && _isPathActive('branch_target_bus');
    _isDMemActive = _isComponentReady('mem_read_data_bus') && _isMemoryInstruction();
    _isMux1Active = _isComponentReady('mux_wb_bus') && _isPathActive('mux_wb_bus'); // Mux para Write Back
    _isMux2Active = _isComponentReady('mux_pc_bus'); // El Mux del PC siempre es útil si está listo
    _isMux3Active = _isComponentReady('mux_alu_b_bus'); // El Mux de la ALU siempre es útil si está listo
  }

  // Helper para comprobar si un componente está listo.
  bool _isComponentReady(String componentName) {
    // Si el componente no está en el mapa, se asume que no está activo.
    // Un valor por defecto mayor que cualquier tiempo crítico posible.
    final readyAtTime = _readyAt[componentName] ?? (_criticalTime + 1);
    return _sliderValue >= readyAtTime;
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
}