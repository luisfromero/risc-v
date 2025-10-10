import 'package:flutter/material.dart';
import 'package:namer_app/geometry.dart';
import 'dart:math';
import 'colors.dart';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'reg_widget.dart';
import 'package:flutter/services.dart'; // Para RawKeyboard
// Para FontFeature
import 'package:provider/provider.dart';
import 'buses_painter.dart';
import 'datapath_state.dart';          // Importa nuestro estado
import 'pc_widget.dart';
import 'adder_widget.dart';
import 'memory_unit_widget.dart';
import 'ib_widget.dart';
import 'mux_widget.dart';
import 'mux2_widget.dart';
import 'mux3_widget.dart';
import 'extender_widget.dart';
import 'control_unit_widget.dart';
import 'services/get_service.dart'; // Importación condicional del servicio
import 'simulation_mode.dart';
import 'tooltip_widgets.dart';
import 'platform_init.dart'; // Importación condicional para la configuración de la ventana
import 'hazard_unit_widget.dart'; // Importamos el nuevo widget
import 'execution_history_view.dart'; // Importamos la nueva vista

const String _registerFileHoverId = '##REGISTER_FILE_HOVER##';
const String _instructionMemoryHoverId = '##INSTRUCTION_MEMORY_HOVER##';
const String _dataMemoryHoverId = '##DATA_MEMORY_HOVER##';
const String _controlHoverId = '##CONTROL_HOVER##';
const String _muxPcHoverId = '##MUX_PC_HOVER##';
const String _muxBHoverId = '##MUX_B_HOVER##';
const String _muxCHoverId = '##MUX_C_HOVER##';
const String _immHoverId = '##IMM_HOVER##';
const String _branchHoverId = '##BRANCH_HOVER##';
const String _aluHoverId = '##ALU_HOVER##';
const String _pcAdderHoverId = '##PC_ADDER_HOVER##';
const String _controlTableHoverId = '##CONTROL_TABLE_HOVER##';
const String _instructionFormatTableHoverId = '##INSTRUCTION_FORMAT_HOVER##';



Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await setupWindow(); // Ahora esperamos a que la ventana se configure

  // 1. Obtenemos la instancia del servicio (API o FFI según la plataforma).
  final simulationService = getSimulationService();

  // 2. Creamos la instancia del estado.
  final datapathState = DatapathState(simulationService);

  try {
    // 3. Esperamos a que la inicialización del estado (que es asíncrona) termine.
    //    Esto llamará internamente a `simulationService.initialize()` y esperará.
    await datapathState.initialize();
  } catch (e) {
    // Es una buena práctica manejar el caso en que la API no esté disponible.
    // ignore: avoid_print
    print('Error fatal durante la inicialización: $e');
  }

  runApp(
    ChangeNotifierProvider.value(
      value: datapathState,
      child: const MyApp(),
    ),
  );
}

/// Clase para encapsular los datos de un registro para el tooltip.
class HoverRegisterData {
  final String name;
  final int? valIn;
  final int? valOut;
  final int digits;

  HoverRegisterData(this.name, this.valIn, this.valOut, {this.digits = 8});
}

/// Formatea una única línea de tooltip para un registro.
String _formatRegisterLine(String name, int? valIn, int? valOut, [int digits = 8]) {
  // El radix por defecto es 16 (hex). Si los dígitos son 5, asumimos binario.
  final sufijo2= (valIn == null)?'':'($valIn)';
  final radix = (digits <= 5) ? 2 : 16;
  final prefix = (radix == 2) ? '' : '0x';
  final suffix = (radix == 2) ? sufijo2 : '';

  final inStr = (valIn == null) 
      ? 'not set' 
      : '$prefix${valIn.toRadixString(radix).padLeft(digits, '0').toUpperCase()}$suffix';
  final outStr = (valOut == null) 
      ? 'not set' 
      : '$prefix${valOut.toRadixString(radix).padLeft(digits, '0').toUpperCase()}$suffix';
  
  final namePart = name.isNotEmpty ? '$name\n' : '\n';
  return "${namePart}in : $inStr \nout: $outStr";
}

String formatSingleRegisterHover(int? valIn, int? valOut, {int digits = 8}) {
  return _formatRegisterLine('', valIn, valOut, digits);
}

/// Genera un tooltip para múltiples registros, cada uno con su nombre.
String formatMultiRegisterHover(List<HoverRegisterData> registers) {
  return registers
      .map((r) => _formatRegisterLine(r.name, r.valIn, r.valOut, r.digits))
      .join('\n\n');
}


/// Genera el texto del tooltip para la unidad de riesgo/cortocircuito que esté activa.
/// Esta función centraliza la lógica para decidir qué mensaje mostrar.
String _getHazardTooltipText(DatapathState datapathState) {
  // La prioridad es importante: un stall tiene preferencia sobre un flush o un forward.
  if (datapathState.isLoadHazard) {
    // Hacemos el tooltip más específico para el riesgo de carga.
    final loadInstruction = datapathState.pipeExInstruction;
    final dependentInstruction = datapathState.pipeIfInstruction;
    
    // Obtenemos la información decodificada de las instrucciones en las etapas EX e ID.
    final loadReg = datapathState.busValues['Pipe_ID_EX_RD_out'];
    final instruccion = datapathState.pipeIfInstruction;
    final contiene=instruccion.contains('x$loadReg');


    // Determinamos qué registro causa la dependencia.
    final conflictingRegister = contiene ? 'x$loadReg' : 'un registro';

    return "La unidad de Riesgo de LOAD se ha activado\nporque la instrucción\n'$instruccion' (en ID) intenta leer el registro $conflictingRegister,\nque está siendo cargado desde memoria por '${loadInstruction.trim()}' (en EX).""\n\nSe ha insertado un ciclo de espera (stall) para resolver el riesgo,\nanulando la carga de PC (mantiene la instrucción dependiente)\n y colocando una NOP en la segunda etapa.";
  } else if (datapathState.isBranchHazard) {
    // Hacemos el tooltip más específico para el riesgo de salto.
    final instruction = datapathState.pipeExInstruction;
    final instructionName = instruction.split(' ').first;
    final flagZ = datapathState.busValues['flagZ'];

    String reason = "la instrucción '$instructionName' en EX ha tomado\nel salto";
    if (instructionName == 'beq' && flagZ == 1) {
      reason += " (Z=1).";
    } else if (instructionName == 'bne' && flagZ == 0) {
      reason += " (Z=0).";
    } else {
      reason += " incondicionalmente.";
    }
    return 'La unidad de Riesgo de Salto se ha activado\nporque $reason''\n\nNota: El campo RD del registro de segmentación,\nen branch, se usa para propagar funct3 (tipo de branch).';
  } else if (datapathState.busValues['bus_ControlForwardA'] != 1 || datapathState.busValues['bus_ControlForwardB'] != 1) {
    // Hacemos el tooltip más específico para los cortocircuitos.
    final forwardA = datapathState.busValues['bus_ControlForwardA'];
    final forwardB = datapathState.busValues['bus_ControlForwardB'];
    
    List<String> descriptions = [];

    // Describe el cortocircuito para el operando A (rs1)
    if (forwardA == 0) { // MEM -> EX
      descriptions.add("- MEM -> EX (operando 1): La instrucción '${datapathState.pipeExInstruction.trim()}' (en EX)\n  recibe el resultado de '${datapathState.pipeMemInstruction.trim()}' (en MEM).");
    } else if (forwardA == 2) { // WB -> EX
      descriptions.add("- WB -> EX (operando 1): La instrucción '${datapathState.pipeExInstruction.trim()}' (en EX)\n  recibe el resultado de '${datapathState.pipeWbInstruction.trim()}' (en WB).");
    }

    // Describe el cortocircuito para el operando B (rs2)
    if (forwardB == 0) { // MEM -> EX
      descriptions.add("- MEM -> EX (operando 2): La instrucción '${datapathState.pipeExInstruction.trim()}' (en EX)\n  recibe el resultado de '${datapathState.pipeMemInstruction.trim()}' (en MEM).");
    } else if (forwardB == 2) { // WB -> EX
      descriptions.add("- WB -> EX (operando 2): La instrucción '${datapathState.pipeExInstruction.trim()}' (en EX)\n  recibe el resultado de '${datapathState.pipeWbInstruction.trim()}' (en WB).");
    }

    final title = descriptions.length > 1 
        ? 'Se han activado dos cortocircuitos:' 
        : 'Se ha activado un cortocircuito:';

    return 'La unidad de Cortocircuitos se ha activado.\n$title\n\n${descriptions.join('\n\n')}';
  }
  // Si ninguna está activa, no devolvemos texto.
  return '';
}


class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late TransformationController _transformationController;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
  }

  @override
  Widget build(BuildContext context) {
    final datapathState = Provider.of<DatapathState>(context);

    bool isSingleCycleMode = datapathState.simulationMode == SimulationMode.singleCycle;
    bool isPipelineMode = datapathState.simulationMode == SimulationMode.pipeline;
    bool isMultiCycleMode = datapathState.simulationMode == SimulationMode.multiCycle;
    
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          // Usamos un Row en el title para centrar el contador de ciclos
          // sin afectar al layout de los actions.
          title: Row(
            children: [
              const Text('RISC-V Datapath'),
              const SizedBox(width: 20), // Espacio entre el selector y las coordenadas

              ToggleButtons(
                isSelected: SimulationMode.values
                    .map((mode) => datapathState.simulationMode == mode)
                    .toList(),
                onPressed: (int index) {
                  datapathState.setSimulationMode(SimulationMode.values[index]);
                },
                // Estilos para que se integre bien en la AppBar
                color: Colors.white.withValues(alpha: 0.5),
                selectedColor: Colors.white,
                fillColor: Colors.white.withValues(alpha: 0.2),
                borderColor: Colors.white.withValues(alpha: 0.5),
                selectedBorderColor: Colors.white,
                borderRadius: BorderRadius.circular(4.0),
                constraints: const BoxConstraints(minHeight: 28.0), // Altura compacta
                children: SimulationMode.values
                    .map((mode) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Text(mode.label, style: const TextStyle(fontSize: 10)),
                        ))
                    .toList(),
              ),


            const SizedBox(width: 20), // Espacio entre el selector y las coordenadas
              const Spacer(),
              if (datapathState.simulationMode == SimulationMode.multiCycle)
                Text(
                  'Cycle: ${datapathState.currentMicroCycle + 1} / ${datapathState.totalMicroCycles}',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold, fontFeatures: [FontFeature.tabularFigures()]),
                ),
              const Spacer(),
            ],
          ),
          backgroundColor: Colors.blueGrey,
          actions: [
            // Botón para resetear el zoom y paneo
            Tooltip(
              message: 'Reset view',
              child: IconButton(
                icon: const Icon(Icons.zoom_in_map),
                onPressed: () {
                  _transformationController.value = Matrix4.identity();
                },
              ),
            ),
            // Widget para mostrar las coordenadas del ratón en la barra superior.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Center(
                child: Text(
                  'X: ${datapathState.mousePosition.dx.toStringAsFixed(0)}, Y: ${datapathState.mousePosition.dy.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 16, fontFeatures: [FontFeature.tabularFigures()]), // tabularFigures para que no "baile"
                ),
              ),
            ),
            // Un pequeño tooltip para mostrar la información del hover
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              // Para asegurar que el estilo se aplique sobre el tema del AppBar,
              // envolvemos el Text en un DefaultTextStyle.
              child: DefaultTextStyle(
                style: miEstiloTooltip,
                child: Center(
                  child: Text(datapathState.hoverInfo),
                ),
              ),
            ),
                      // --- Selector de modo de simulación ---

          ],
        ),
        // Usamos un Column para añadir el Slider debajo del Stack
        body: Column(
          children: [
            // --- Panel de Control Superior ---
            Container(
              padding: const EdgeInsets.only(top: 12, left:12),
              child: Row(
                children: [
                  // Envolvemos los botones en un SizedBox para fijar el ancho total.
                  SizedBox(
                    width: 255, // Ancho total fijo para los tres botones.
                    height:40,
                    child: Row(
                      children: [
                        // Cada bo90tón se envuelve en Expanded para que compartan el espacio.
                        Expanded(
                          child: 
                          Tooltip(message: 'Upload program to memory',
                            child:
                          ElevatedButton.icon(
                            onPressed: () async {
                              FilePickerResult? result = await FilePicker.platform.pickFiles(
                                type: FileType.custom,
                                allowedExtensions: ['bin', 's'],
                                withData: true, // <-- NECESARIO para que file.bytes no sea nulo
                              );

                              if (result != null && result.files.single.bytes != null) {
                                final file = result.files.single;
                                if (file.extension == 'bin') {
                                  final Uint8List binCode = file.bytes!;
                                  datapathState.reset(binCode: binCode);
                                } else if (file.extension == 's') {
                                  final String assemblyCode = utf8.decode(file.bytes!);
                                  // Aún no se procesa, pero se pasa a la capa de servicio.
                                  datapathState.reset(assemblyCode: assemblyCode);
                                }
                              }
                            },
                            icon: const Icon(Icons.file_open, size: 16),
                            label: const Text('Load'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade100, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 8)),
                          ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          flex: 1, // Le damos más espacio a este botón porque su texto es más largo.
                          child: Tooltip(
                            message: 'Reset (Long press or Ctrl+Click to reset with random PC)',
                            child: ElevatedButton.icon(
                              onPressed: () {
                                final isControlPressed = HardwareKeyboard.instance.isControlPressed;
                                if(!isControlPressed){
                                  datapathState.reset();
                                }
                                else{
                                  datapathState.initial_pc = 256 * Random().nextInt(256);
                                  datapathState.reset(initial_pc: datapathState.initial_pc);
                                }
                              },
                              onLongPress: () {
                                datapathState.initial_pc  = 256 * Random().nextInt(256);
                                datapathState.reset(initial_pc: datapathState.initial_pc);
                              },
                              icon: const Icon(Icons.refresh, size: 16),
                              label: const Text('Reset'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade100, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 8)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          flex: 1, // Le damos más espacio a este botón porque su texto es más largo.
                          child: Tooltip(
                            message: 'Step forward (Long press or Ctrl+Click to step back)',
                            child: ElevatedButton.icon(
                              onPressed: () {
                                final isControlPressed = HardwareKeyboard.instance.isControlPressed;
                                if (isControlPressed) {
                                  datapathState.stepBack();
                                } else {
                                  datapathState.step();
                                }
                              },
                              onLongPress: () => datapathState.stepBack(),
                              icon: const Icon(Icons.timer, size: 16),
                              label: const Text('Clock'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade100, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 8)),
                            ),
                          ),
                        ),
                      ],
                    )
                  ),
                  const SizedBox(width: 8), // Espacio antes de la Unidad de Control
                  // La Unidad de Control se ha movido al Stack principal para que sea parte del canvas con zoom.
                ],
              ),
            ),
            Expanded(
              child: InteractiveViewer(
                transformationController: _transformationController,
                minScale: 0.2,
                maxScale: 4.0,
                // Ajustamos el boundaryMargin para incluir el espacio de la ControlUnit en la parte superior.
                //boundaryMargin: const EdgeInsets.fromLTRB(200, 200 + heightUC, 200, 200),
                boundaryMargin:EdgeInsets.all(200),
                // Envolvemos el Stack en un MouseRegion para capturar la posición del ratón.
                child: MouseRegion(
                  onHover: (event) {
                    // La posición local ya está en el sistema de coordenadas transformado del Stack.
                    // No se necesita ninguna compensación manual.
                    datapathState.setMousePosition(event.localPosition);
                  },
                  child: Stack(
                    key: datapathState.stackKey,
                    clipBehavior: Clip.none, // Permite que los widgets se dibujen fuera de los límites del Stack
                    children: [
                      // --- Pintor de Buses (se dibuja detrás de todo) ---
                      CustomPaint(
                        painter: BusesPainter(datapathState),
                        size: Size.infinite,
                      ),

                      // --- Logos ---
                      Positioned(
                        top: yShift+520,
                        left: 22,
                        child: Row(
                          children: [
                            Image.asset(
                              'img/dac.png',
                              width: 60,
                              height: 50,
                            ),
                            const SizedBox(width: 20),
                            Image.asset(
                              'img/uma.png',
                              width: 70,
                              height: 70,
                            ),
                          ],
                        ),
                      ),
                      //iNFO ICONS
                      Positioned(
                        top:20,
                        left: 10,
                        child: Row(
                          children: [
                            Tooltip(
                              message: 'Instruction Formats',
                              child: MouseRegion(
                                onEnter: (_) => datapathState.setHoverInfo(_instructionFormatTableHoverId),
                                onExit: (_) => datapathState.setHoverInfo(''),
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.info_outline),
                                  constraints: const BoxConstraints(),
                                  onPressed: () {}, // No action on click
                                ),
                              ),
                            ),
                            Tooltip(
                              message: 'Control Unit Logic Table',
                              child: MouseRegion(
                                onEnter: (_) => datapathState.setHoverInfo(_controlTableHoverId),
                                onExit: (_) => datapathState.setHoverInfo(''),
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.bolt), // Icono de rayo
                                  constraints: const BoxConstraints(),
                                  onPressed: () {}, // No action on click
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                      // --- Todos los widgets del datapath ---
                      ..._buildDatapathWidgets(datapathState, isSingleCycleMode, isPipelineMode, isMultiCycleMode),
                    
                      // --- Tooltip Flotante ---
                      // Se muestra solo si hay información de hover y se dibuja encima de todo.
                      if (datapathState.hoverInfo.isNotEmpty)
                        FloatingTooltip(
                          message: datapathState.hoverInfo,
                          position: datapathState.mousePosition,
                        ),
                    ],
                  ),
                ),
              ),
            ),
            // --- Slider (solo visible en modo single-cycle) ---
            if (datapathState.simulationMode == SimulationMode.singleCycle)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                child: Slider(
                  value: datapathState.sliderValue,
                  min: 0,
                  max: datapathState.criticalTime.toDouble(),
                  // divisions no puede ser 0. Si criticalTime es 0, lo dejamos en null (continuo).
                  divisions: datapathState.criticalTime > 0 ? datapathState.criticalTime : null,
                  label: datapathState.sliderValue.round().toString(),
                  onChanged: (double value) {
                    // Llama al método para actualizar el estado del slider
                    datapathState.setSliderValue(value);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }
}

final miEstiloInst = TextStyle(
  fontFamily: 'RobotoMono',
  fontSize: 18,
  color: Colors.black,
  fontWeight: FontWeight.bold,
  fontFeatures: [const FontFeature.disable('liga')],
);

/// Extrae la lógica de construcción de los widgets del datapath a una función separada
/// para mantener el método `build` principal más limpio.
List<Widget> _buildDatapathWidgets(DatapathState datapathState, bool isSingleCycleMode, bool isPipelineMode, bool isMultiCycleMode) {
  return [
    // --- Unidad de Control ---
    Positioned(
      top: yPosUC,
      left: xPosUC,
      child: MouseRegion(
        onEnter: (_) => datapathState.setHoverInfo(_controlHoverId),
        onExit: (_) => datapathState.setHoverInfo(''),
        child: SizedBox( // Mantenemos el SizedBox para darle el tamaño fijo necesario.
          width: widthUC,
          height: heightUC,
          child: ControlUnitWidget(
            key: datapathState.controlUnitKey,
            isActive: datapathState.isControlActive,
          ),
        ),
      ),
    ),
    // --- Mux2 PC ---
    Positioned(
      top: yMuxPC,
      left: xMuxPC,
      child: MouseRegion(
        onEnter: (_) => datapathState.setHoverInfo(_muxPcHoverId),
        onExit: (_) => datapathState.setHoverInfo(''),
        child: MuxWidget(
          key: datapathState.mux2Key,
          value: datapathState.busValues['control_PCsrc'] ?? 0,
          isActive: isPipelineMode? true: datapathState.isMux2Active,
          color:isSingleCycleMode?defaultColor:(isMultiCycleMode?color5:pipelineColorForPC((datapathState.busValues['Pipe_MEM_WB_NPC_out']??0)-4)),
        ),
      ),
    ),
    // --- PC ---
    Positioned(
      top: yPC,
      left: xPC,
      // MouseRegion detecta cuando el ratón entra o sale de su área.
      child: MouseRegion(
        onEnter: (_) => datapathState.setHoverInfo('PC: ${formatSingleRegisterHover(datapathState.pcValue, datapathState.busValues['mux_pc_bus'])}'),
        onExit: (_) => datapathState.setHoverInfo(''),
        child: PcWidget(
          key: datapathState.pcKey,
          isActive: datapathState.isPCActive,
          color:isSingleCycleMode?defaultColor:(isMultiCycleMode?color1:pipelineColorForPC((datapathState.busValues['npc_bus']??0)-4)),
        ),
      ),
    ),

    // --- Sumador del PC ---
    Positioned(
      top: yAdderPC,
      left: xAdderPC,
      child: MouseRegion(
        onEnter: (_) => datapathState.setHoverInfo(_pcAdderHoverId),
        onExit: (_) => datapathState.setHoverInfo(''),
        // El color del sumador ahora depende del estado global
        child: AdderWidget(
          key: datapathState.pcAdderKey,
          label: 'NPC',
          isActive: datapathState.isPcAdderActive,
          connectionPoints: [
            Offset(-1.5,0.25),
            Offset(0,0.25),
            Offset(0,0.75),
            Offset(1,0.5),
            Offset(2,0.5),
          ],
          color:isSingleCycleMode?defaultColor:(isMultiCycleMode?color1:pipelineColorForPC((datapathState.busValues['npc_bus']??0)-4)),


        ),
      ),
    ),
    // --- Memoria de Instrucciones ---
    Positioned(
      top: yInstrMem,
      left: xInstrMem,
      child: MouseRegion(
        onEnter: (_) => datapathState.setHoverInfo(_instructionMemoryHoverId),
        onExit: (_) => datapathState.setHoverInfo(''),
        child: MemoryUnitWidget(
          key: datapathState.instructionMemoryKey,
          label: 'Instruct.\nMemory',
          width: widthMems,
          height: heightMems,
          isActive: !isSingleCycleMode?true: datapathState.isIMemActive,
          color:isSingleCycleMode?defaultColor:(isMultiCycleMode?color1:pipelineColorForPC((datapathState.busValues['npc_bus']??0)-4)),
          // 2 Puntos para I-Mem
          connectionPoints: const [
            Offset(0,0.5),
            Offset(1,0.5),
          ],
        ),
      ),
    ),
    // --- Cte ---
    Positioned(
      top: yConst4,
      left: xConst4,
      child: MouseRegion(
        onEnter: (_) => datapathState.setHoverInfo('Constant: 4'),
        onExit: (_) => datapathState.setHoverInfo(''),
        child: Text("0x00000004")
      ),
    ),
    // --- Instruction Buffer ---
    Positioned(
      top: yIB,
      left: xIB,
      child: MouseRegion(
        onEnter: (_) => datapathState.setHoverInfo(isSingleCycleMode?'Instruction Buffer':
        'IF_ID_Instr ${formatSingleRegisterHover(datapathState.busValues['Pipe_IF_ID_Instr'],datapathState.busValues['Pipe_IF_ID_Instr_out'])}'),
        onExit: (_) => datapathState.setHoverInfo(''),
        child: IBWidget(
          key: datapathState.ibKey,
          isActive: !isSingleCycleMode? datapathState.isPathActive('Pipe_IF_ID_Instr_out'): datapathState.isIBActive,
          color:isSingleCycleMode?defaultColor:(isMultiCycleMode?color2:pipelineColorForPC((datapathState.busValues['Pipe_IF_ID_NPC_out']??0)-4)),
    
        ),
      ),
    ),

    // --- Pipeline Registers IF/ID ---
    Positioned(
      top: yPipeRegIFID_NPC,
      left: xPipeRegIFID_NPC,
      child: MouseRegion(
        onEnter: (_) => datapathState.setHoverInfo('IF_ID_NPC ${formatSingleRegisterHover(datapathState.busValues['Pipe_IF_ID_NPC'],datapathState.busValues['Pipe_IF_ID_NPC_out'])}'),
        onExit: (_) => datapathState.setHoverInfo(''),
        child: RegWidget(
          key: datapathState.pipereg_fd0_Key,
          label: 'FD0',
          height: heightNPCReg,
          isActive: datapathState.isPathActive("Pipe_IF_ID_Instr_out"),
          color:isSingleCycleMode?defaultColor:(isMultiCycleMode?color2:pipelineColorForPC((datapathState.busValues['Pipe_IF_ID_NPC_out']??0)-4)),
          visibility: isPipelineMode,
          connectionPoints: const [Offset(0, yPipeNPC1),Offset(1, yPipeNPC1),Offset(0.5, 0)],
        ),
      ),
    ),
    Positioned(
      top: yPipeRegIFID_PC,
      left: xPipeRegIFID_PC,
      child: MouseRegion(
        onEnter: (_) => datapathState.setHoverInfo('IF_ID_PC ${formatSingleRegisterHover(datapathState.busValues['Pipe_IF_ID_PC'],datapathState.busValues['Pipe_IF_ID_PC_out']??0-4)}'),
        onExit: (_) => datapathState.setHoverInfo(''),
        child: RegWidget(
          key: datapathState.pipereg_fd1_Key,
          label: 'FD1',
          height: heightPCPipeReg,
          isActive: datapathState.isPathActive("Pipe_IF_ID_Instr_out"),
          visibility: isPipelineMode,
          color:isSingleCycleMode?defaultColor:(isMultiCycleMode?color2:pipelineColorForPC((datapathState.busValues['Pipe_IF_ID_NPC_out']??0)-4)),
        ),
      ),
    ),

    // --- Banco de Registros ---
    Positioned(
      top: yRegFile,
      left: xRegFile,
      child: MouseRegion(                        
        onEnter: (_) => datapathState.setHoverInfo(_registerFileHoverId),
        onExit: (_) => datapathState.setHoverInfo(''),
        child: MemoryUnitWidget(
          key: datapathState.registerFileKey,
          label: 'Register\nFile',
          isActive: isPipelineMode ? datapathState.isPathActive("Pipe_IF_ID_Instr_out") : datapathState.isRegFileActive,
          width: widthMems,
          height: heightMems,
          // 7 Puntos para el Banco de Registros
          connectionPoints: const [
            Offset(0,0.2),
            Offset(0,0.4),
            Offset(0,0.6),
            Offset(0,0.8),
            Offset(0.5,0),
            Offset(1,0.25),
            Offset(1,r_BR_B),
            Offset(15/8.0,r_BR_B),
            ],
          color:isSingleCycleMode?defaultColor:(isMultiCycleMode?color2:pipelineColorForPC((datapathState.busValues['Pipe_IF_ID_NPC_out']??0)-4)),
        ),
      ),
    ),
    // --- Extender ---
    Positioned(
      top: yExtender,
      left: xExtender,
      child: MouseRegion(
        onEnter: (_) => datapathState.setHoverInfo(_immHoverId),
        onExit: (_) => datapathState.setHoverInfo(''),
        child: ExtenderWidget(
          key: datapathState.extenderKey,
          label: 'Imm. ext.',
          isActive: isPipelineMode?datapathState.isPathActive("Pipe_IF_ID_Instr_out"): datapathState.isExtenderActive,
          color:isSingleCycleMode?defaultColor:(isMultiCycleMode?color2:pipelineColorForPC((datapathState.busValues['Pipe_IF_ID_NPC_out']??0)-4)),
        ),
      ),
    ),

    // --- Pipeline Registers ---
    if(datapathState.showControl||datapathState.showForwarding||datapathState.showLHU||datapathState.showBHU)
    Positioned(
      top: yPipeRegIDEX_Control,
      left: xPipeRegIDEX_Control, 
      child: MouseRegion(
        onEnter: (_) => datapathState.setHoverInfo('DE/EX Control ${formatSingleRegisterHover(datapathState.busValues['Pipe_ID_EX_Control'],datapathState.busValues['Pipe_ID_EX_Control_out'], digits: 4)}'),
        onExit: (_) => datapathState.setHoverInfo(''),
        child: RegWidget(
          key: datapathState.pipereg_deControl_Key,
          label: 'DEControl ',
          height: heightControlPipe1,
          isActive: datapathState.isPathActive("Pipe_ID_EX_Control_out"),
          visibility: isPipelineMode,
          connectionPoints: const [Offset(0, 0.5),Offset(1, 0.33),Offset(1, 0.666),], //Llega en 100, salen en 90 y 100
          color:isSingleCycleMode?defaultColor:(isMultiCycleMode?color3:pipelineColorForPC((datapathState.busValues['Pipe_ID_EX_NPC_out']??0)-4)),

        ),
      ),
    ),

    Positioned(
      top: yPipeRegIDEX_NPC,
      left: xPipeRegIDEX_NPC,
      child: MouseRegion(
        onEnter: (_) => datapathState.setHoverInfo('DE/EX Register (NPC)  ${formatSingleRegisterHover(datapathState.busValues['Pipe_ID_EX_NPC'],datapathState.busValues['Pipe_ID_EX_NPC_out'])}'),
        onExit: (_) => datapathState.setHoverInfo(''),
        child: RegWidget(
          key: datapathState.pipereg_de0_Key,
          label: 'DE0',
          height: heightNPCReg,
          isActive: datapathState.isPathActive("Pipe_ID_EX_NPC_out"),
          visibility: isPipelineMode,
          connectionPoints: const [Offset(0, yPipeNPC1),Offset(1, yPipeNPC1),],
          color:isSingleCycleMode?defaultColor:(isMultiCycleMode?color3:pipelineColorForPC((datapathState.busValues['Pipe_ID_EX_NPC_out']??0)-4)),

        ),
      ),
    ),
    Positioned(
      top: yPipeRegIDEX_Data,
      left: xPipeRegIDEX_Data,
      child: MouseRegion(
        onEnter: (_) => datapathState.setHoverInfo(
          (isMultiCycleMode)?
          formatMultiRegisterHover([
            HoverRegisterData("ID/EX (A)", datapathState.busValues['Pipe_ID_EX_A'], datapathState.busValues['Pipe_ID_EX_A_out']),
            HoverRegisterData("ID/EX (B)", datapathState.busValues['Pipe_ID_EX_B'], datapathState.busValues['Pipe_ID_EX_B_out']),
            HoverRegisterData("ID/EX (Imm)", datapathState.busValues['Pipe_ID_EX_Imm'], datapathState.busValues['Pipe_ID_EX_Imm_out']),
          ])
          :
          formatMultiRegisterHover([
            HoverRegisterData("ID/EX (A)", datapathState.busValues['Pipe_ID_EX_A'], datapathState.busValues['Pipe_ID_EX_A_out']),
            HoverRegisterData("ID/EX (B)", datapathState.busValues['Pipe_ID_EX_B'], datapathState.busValues['Pipe_ID_EX_B_out']),
            HoverRegisterData("ID/EX (RD)", datapathState.busValues['Pipe_ID_EX_RD'], datapathState.busValues['Pipe_ID_EX_RD_out'],digits:5),
            HoverRegisterData("ID/EX (RS1)", datapathState.busValues['Pipe_ID_EX_RS1'], datapathState.busValues['Pipe_ID_EX_RS1_out'], digits: 5),
            HoverRegisterData("ID/EX (RS2)", datapathState.busValues['Pipe_ID_EX_RS2'], datapathState.busValues['Pipe_ID_EX_RS2_out'], digits: 5),
            HoverRegisterData("ID/EX (Imm)", datapathState.busValues['Pipe_ID_EX_Imm'], datapathState.busValues['Pipe_ID_EX_Imm_out']),
          ])
        ),
        onExit: (_) => datapathState.setHoverInfo(''),
        child: RegWidget(
          label:'DE1',
          height: heightIB,
          key: datapathState.pipereg_de1_Key,
          isActive: datapathState.isPathActive("Pipe_ID_EX_NPC_out"),
          visibility: !isSingleCycleMode,
          connectionPoints: const [Offset(0, r_DE0),Offset(0, r_DE1),Offset(0, r_DE2),Offset(0, r_DE3),Offset(1, r_DE0),Offset(1, r_DE1),Offset(1, r_DE2),Offset(1, r_DE3),Offset(1, r_DE4)],
          color:isSingleCycleMode?defaultColor:(isMultiCycleMode?color3:pipelineColorForPC((datapathState.busValues['Pipe_ID_EX_NPC_out']??0)-4)),
        ),
      ),
    ),
    Positioned(
      top: yPipeRegIDEX_PC,
      left: xPipeRegIDEX_PC,
      child: MouseRegion(
        onEnter: (_) => datapathState.setHoverInfo('DE/EX Register (PC) ${formatSingleRegisterHover(datapathState.busValues['Pipe_ID_EX_PC'],datapathState.busValues['Pipe_ID_EX_PC_out'])}'),
        onExit: (_) => datapathState.setHoverInfo(''),
        child: RegWidget(
          key: datapathState.pipereg_de2_Key,
          label: 'DE2',
          height: heightPCPipeReg,
          isActive: datapathState.isPathActive("Pipe_ID_EX_PC_out"),
          visibility: isPipelineMode,
          color:isSingleCycleMode?defaultColor:(isMultiCycleMode?color3:pipelineColorForPC((datapathState.busValues['Pipe_ID_EX_NPC_out']??0)-4)),
        ),
      ),
    ),


    // --- MuxB ---
    Positioned(
      top: yMuxALU,
      left: xMuxALU,
      child: MouseRegion(
        onEnter: (_) => datapathState.setHoverInfo(_muxBHoverId),
        onExit: (_) => datapathState.setHoverInfo(''),
        child: Mux2Widget(
          key: datapathState.mux3Key,
          value: datapathState.busValues['control_ALUsrc'] ?? 0,
          isActive: isPipelineMode?datapathState.isPathActive("Pipe_ID_EX_B_out"): datapathState.isMux3Active,
          labels: ['0', '1', '2', ' '],
          color:isSingleCycleMode?defaultColor:(isMultiCycleMode?color3:pipelineColorForPC((datapathState.busValues['Pipe_ID_EX_NPC_out']??0)-4)),

        ),
      ),
    ),

    // --- Forwarding muxes ---
    if(isPipelineMode)
    Positioned(
      top: yMuxFwdA,
      left: xMuxFwdA,
      child: Opacity(
        opacity: datapathState.showForwarding||(datapathState.busValues['bus_ControlForwardA'] !=1)? 1.0 : 0.0,
        child: MouseRegion(
          onEnter: (_) { if (datapathState.showForwarding) datapathState.setHoverInfo(_muxBHoverId); },
          onExit: (_) => datapathState.setHoverInfo(''),
          child: Mux3Widget(
            key: datapathState.muxFWAKey,
            value: 1,
            isActive: true,
          ),
        ),
      ),
    ),
    if(isPipelineMode)
    Positioned(
      top: yMuxFwdB,
      left: xMuxFwdB,
      child: Opacity(
        opacity: datapathState.showForwarding||(datapathState.busValues['bus_ControlForwardB'] !=1)? 1.0 : 0.0,
        child: MouseRegion(
          onEnter: (_) { if (datapathState.showForwarding) datapathState.setHoverInfo(_muxBHoverId); },
          onExit: (_) => datapathState.setHoverInfo(''),
          child: Mux3Widget(
            key: datapathState.muxFWBKey,
            value: 1,
            isActive: true,
          ),
        ),
      ),
    ),


    // --- ALU ---
    Positioned(
      top: yALU,
      left: xALU,
      child: MouseRegion(
        onEnter: (_) => datapathState.setHoverInfo(_aluHoverId),
        onExit: (_) => datapathState.setHoverInfo(''),
        child: AdderWidget(
          key: datapathState.aluKey,
          label: 'ALU',
          isActive: isPipelineMode ? datapathState.isPathActive("Pipe_ID_EX_A_out") : datapathState.isAluActive,
          color:isSingleCycleMode?defaultColor:(isMultiCycleMode?color3:pipelineColorForPC((datapathState.busValues['Pipe_ID_EX_NPC_out']??0)-4)),
          // 5 Puntos para la ALU
          connectionPoints: const [
            Offset(0,0.25),
            Offset(0,0.75),
            Offset(0.5,0.15),
            Offset(1,0.35),
            Offset(1,0.5),
            Offset(2.5,0.5),
            Offset(1.2,0.5),
          ],
        ),
      ),
    ),
    // --- Sumador de Saltos (Branch) ---
    Positioned(
      top: yAdderBranch,
      left: xAdderBranch,
      child: MouseRegion(
        onEnter: (_) => datapathState.setHoverInfo(_branchHoverId),
        onExit: (_) => datapathState.setHoverInfo(''),
        child: AdderWidget(
          key: datapathState.branchAdderKey,
          label: '  BR\ntarget',
          isActive: !isSingleCycleMode?datapathState.isPathActive("branch_target_bus"): datapathState.isBranchAdderActive,
          color:isSingleCycleMode?defaultColor:(isMultiCycleMode?color3:pipelineColorForPC((datapathState.busValues['Pipe_ID_EX_NPC_out']??0)-4)),
        ),
      ),
    ),
    
    // --- Pipeline Registers ---
    if(datapathState.showControl||datapathState.showForwarding||datapathState.showLHU||datapathState.showBHU)
    Positioned(
      top: yPipeRegEXMEM_Control,
      left: xPipeRegEXMEM_Control,
      child: MouseRegion(
        onEnter: (_) => datapathState.setHoverInfo('EX/MEM Control ${formatSingleRegisterHover(datapathState.busValues['Pipe_EX_MEM_Control'],datapathState.busValues['Pipe_EX_MEM_Control_out'], digits: 4)}'),
        onExit: (_) => datapathState.setHoverInfo(''),
        child: RegWidget(
          key: datapathState.pipereg_emControl_Key,
          label: 'EMControl ',
          height: heightControlPipe2,
          isActive: datapathState.isPathActive("Pipe_EX_MEM_Control_out"),
          visibility: isPipelineMode,
          connectionPoints: const [Offset(0, 0.5),Offset(1, 0.25),Offset(1, 0.75),Offset(0.5, 0),], // Le llega en 90. Uno sale en 85 y el otro en 95
          color:isSingleCycleMode?defaultColor:(isMultiCycleMode?color3:pipelineColorForPC((datapathState.busValues['Pipe_EX_MEM_NPC_out']??0)-4)),

        ),
      ),
    ),


    Positioned(
      top: yPipeRegEXMEM_NPC,
      left: xPipeRegEXMEM_NPC,
      child: MouseRegion(
        onEnter: (_) => datapathState.setHoverInfo('EX/ME Register (NPC) ${formatSingleRegisterHover(datapathState.busValues['Pipe_EX_MEM_NPC'],datapathState.busValues['Pipe_EX_MEM_NPC_out'])}'),
        onExit: (_) => datapathState.setHoverInfo(''),
        child: RegWidget(
          key: datapathState.pipereg_em0_Key,
          height: heightNPCReg,
          label: 'EM0',
          isActive: datapathState.isPathActive( "Pipe_EX_MEM_NPC_out"),
          visibility: isPipelineMode,
          connectionPoints: const [Offset(0, yPipeNPC1),Offset(1, yPipeNPC1),],
          color:isSingleCycleMode?defaultColor:(isMultiCycleMode?color4:pipelineColorForPC((datapathState.busValues['Pipe_EX_MEM_NPC_out']??0)-4)),
        ),
      ),
    ),
    Positioned(
      top: yPipeRegEXMEM_Data,
      left: xPipeRegEXMEM_Data,
      child: MouseRegion(
        onEnter: (_) => datapathState.setHoverInfo(
          (isMultiCycleMode)?
          formatMultiRegisterHover([
            HoverRegisterData("EX/ME (ALU_result)", datapathState.busValues['Pipe_EX_MEM_ALU_result'], datapathState.busValues['Pipe_EX_MEM_ALU_result_out']),
            HoverRegisterData("EX/ME (B)", datapathState.busValues['Pipe_EX_MEM_ALU_B'], datapathState.busValues['Pipe_EX_MEM_ALU_B_out']),
          ])
          :
          formatMultiRegisterHover([
            HoverRegisterData("EX/ME (ALU_result)", datapathState.busValues['Pipe_EX_MEM_ALU_result'], datapathState.busValues['Pipe_EX_MEM_ALU_result_out']),
            HoverRegisterData("EX/ME (B)", datapathState.busValues['Pipe_EX_MEM_ALU_B'], datapathState.busValues['Pipe_EX_MEM_ALU_B_out']),
            HoverRegisterData("EX/ME (RD)", datapathState.busValues['Pipe_EX_MEM_RD'], datapathState.busValues['Pipe_EX_MEM_RD_out'], digits: 5),
          ])
          ),
        onExit: (_) => datapathState.setHoverInfo(''),
        child: RegWidget(
          label:'EM1',
          height: heightIB,
          key: datapathState.pipereg_em1_Key,
          isActive: datapathState.isPathActive("Pipe_EX_MEM_ALU_result_out"),
          visibility: !isSingleCycleMode,
          connectionPoints: const [Offset(0, 0.315),Offset(0, 0.384),Offset(0, 0.654),Offset(0, 0.7115),Offset(1, 0.315),Offset(1, 0.384),Offset(1, 0.654),Offset(1, 0.7115)],
          color:isSingleCycleMode?defaultColor:(isMultiCycleMode?color4:pipelineColorForPC((datapathState.busValues['Pipe_EX_MEM_NPC_out']??0)-4)),
        ),
      ),
    ),

 



    // --- Z ---
    Positioned(
      top: yFlagZ,
      left: xFlagZ,
      child: MouseRegion(
        onEnter: (_) => datapathState.setHoverInfo('flag Z'),
        onExit: (_) => datapathState.setHoverInfo(''),
        child: Text("Z")
      ),
    ),

    

    // --- Memoria de Datos ---
    Positioned(
      top: yDataMem,
      left: xDataMem,
      child: MouseRegion(
        onEnter: (_) => datapathState.setHoverInfo(_dataMemoryHoverId),
        onExit: (_) => datapathState.setHoverInfo(''),
        child: MemoryUnitWidget(
          key: datapathState.dataMemoryKey,
          label: 'Data\nMemory',
          width: widthMems,
          height: heightMems,
          isActive: isPipelineMode ? (datapathState.busValues["Pipe_MemWr"] == 1) || datapathState.isPathActive("mem_read_data_bus") : datapathState.isDMemActive,
          // 4 Puntos para D-Mem
          connectionPoints: const [
            Offset(0,0.5),
            Offset(0,0.75),
            Offset(0.5,0),
            Offset(1,ry_salidaMemData), // Se calcula del mux
          ],
          color:isSingleCycleMode?defaultColor:(isMultiCycleMode?color4:pipelineColorForPC((datapathState.busValues['Pipe_EX_MEM_NPC_out']??0)-4)),
        ),
      ),
    ),

    // --- Pipeline Registers ---
    if(datapathState.showControl||datapathState.showForwarding)
    Positioned(
      top: yPipeRegMEMWB_Control,
      left: xPipeRegMEMWB_Control,
      child: MouseRegion(
        onEnter: (_) => datapathState.setHoverInfo('MEM/WB Control ${formatSingleRegisterHover(datapathState.busValues['Pipe_MEM_WB_Control'],datapathState.busValues['Pipe_MEM_WB_Control_out'], digits: 4)}'),
        onExit: (_) => datapathState.setHoverInfo(''),
        child: RegWidget(
          key: datapathState.pipereg_mwControl_Key,
          label: 'MWControl ',
          height: heightControlPipe3,
          isActive: datapathState.isPathActive("Pipe_MEM_WB_Control_out"),
          visibility: isPipelineMode,
          connectionPoints: const [Offset(0, 0.5),Offset(1, 0.5),Offset(0.5, 0),],
          color:isSingleCycleMode?defaultColor:(isMultiCycleMode?color3:pipelineColorForPC((datapathState.busValues['Pipe_MEM_WB_NPC_out']??0)-4)),

        ),
      ),
    ),


    Positioned(
      top: yPipeRegMEMWB_NPC,
      left: xPipeRegMEMWB_NPC,
      child: MouseRegion(
        onEnter: (_) => datapathState.setHoverInfo('ME/WR Register (NPC) ${formatSingleRegisterHover(datapathState.busValues['Pipe_MEM_WB_NPC'],datapathState.busValues['Pipe_MEM_WB_NPC_out'])}'),
        onExit: (_) => datapathState.setHoverInfo(''),
        child: RegWidget(
          key: datapathState.pipereg_mw0_Key,
          label: 'MW0',
          height: heightNPCReg,
          isActive: datapathState.isPathActive("Pipe_MEM_WB_NPC_out"),
          visibility: isPipelineMode,
          connectionPoints: const [Offset(0, yPipeNPC1),Offset(1,yPipeNPC1),],
          color:isSingleCycleMode?defaultColor:(isMultiCycleMode?color5:pipelineColorForPC((datapathState.busValues['Pipe_MEM_WB_NPC_out']??0)-4)),
        ),
      ),
    ),
    Positioned(
      top: yPipeRegMEMWB_Data,
      left: xPipeRegMEMWB_Data,
      child: MouseRegion(
        onEnter: (_) => datapathState.setHoverInfo(
          (isMultiCycleMode)?
          formatMultiRegisterHover([
            HoverRegisterData("ME/WB (ALU_result)", datapathState.busValues['Pipe_MEM_WB_ALU_result'], datapathState.busValues['Pipe_MEM_WB_ALU_result_out']),
            HoverRegisterData("ME/WB (RM)", datapathState.busValues['Pipe_MEM_WB_RM'], datapathState.busValues['Pipe_MEM_WB_RM_out']),
          ])
          :
          formatMultiRegisterHover([
            HoverRegisterData("ME/WB (ALU_result)", datapathState.busValues['Pipe_MEM_WB_ALU_result'], datapathState.busValues['Pipe_MEM_WB_ALU_result_out']),
            HoverRegisterData("ME/WB (RM)", datapathState.busValues['Pipe_MEM_WB_RM'], datapathState.busValues['Pipe_MEM_WB_RM_out']),
            HoverRegisterData("ME/WB (RD)", datapathState.busValues['Pipe_MEM_WB_RD'], datapathState.busValues['Pipe_MEM_WB_RD_out'], digits: 5),
          ])
        ),
        onExit: (_) => datapathState.setHoverInfo(''),
        child: RegWidget(
          label:'MW1',
          height: heightIB,
          key: datapathState.pipereg_mw1_Key,
          isActive: datapathState.isPathActive("Pipe_MEM_WB_NPC_out"),
          visibility: !isSingleCycleMode,
          connectionPoints: const [
            Offset(0, r_MW0),
            Offset(0, r_MW1),
            Offset(0, r_MW2),
            Offset(1, r_MW0),
            Offset(1, r_MW1),
            Offset(1, r_MW2),
            Offset(1.5, r_MW1),
            ],
          color:isSingleCycleMode?defaultColor:(isMultiCycleMode?color5:pipelineColorForPC((datapathState.busValues['Pipe_MEM_WB_NPC_out']??0)-4)),

        ),
      ),
    ),

    // --- Unidades de Riesgo y Cortocircuito ---
    if (isPipelineMode)
      Positioned(
        top: yHazardUnits,
        left: xHazardUnits,
        child: HazardUnitWidget(
          key: datapathState.loadHazardUnitKey,
          label: 'Load Hazard\nUnit',
          isActive: datapathState.showLHU || datapathState.isLoadHazard,
          connectionPoints: const [
            Offset(0, 0.5), // Salida para congelar PC
            Offset(0.2, 1), // Entrada desde RD
            Offset(0.5, 1), // Entrada desde Control en ex
            Offset(0.5, 1.5), // Entrada desde Control en ex
            Offset(0, 0.25), // Entrada desde UC, con instruccion decodificada
          ],
        ),
      ),

    if (isPipelineMode)
      Positioned(
        top: yHazardUnits,
        left: xHazardUnits,
        child: HazardUnitWidget(
          key: datapathState.branchHazardUnitKey,
          label: 'Branch Hazard\nUnit',
          isActive: datapathState.showBHU ||datapathState.isBranchHazard,
          activeColor: const Color.fromARGB(255, 166, 189, 240),
          connectionPoints: const [
            Offset(1, 0.5), // Entrada desde ALU.Zero
            Offset(1.45, 0.5), // Entrada desde ALU.Zero
            Offset(0.5, 1), // Entrada desde Control
            Offset(0.5, 1.5), // Entrada desde Control
            Offset(0, 0.66), // Salida hacia la izquierda (a IF/ID)
            Offset(0, 0.33), // Salida hacia la izquierda (a PC)
          ],
        ),
      ),

    if (isPipelineMode)
      Positioned(
        top: yHazardUnits,
        left: xHazardUnits,
        child: HazardUnitWidget(
          key: datapathState.forwardingUnitKey,
          label: 'Forwarding Unit',
          isActive: datapathState.showForwarding || datapathState.busValues['bus_ControlForwardA'] != 1 || datapathState.busValues['bus_ControlForwardB'] != 1,
          activeColor: Colors.purpleAccent,
          connectionPoints: const [
            Offset(0.2, 1), // Entrada rd1 rd2
            Offset(0.5, 1), // Entrada desde Control ex
            Offset(0.5, 1.5), // Entrada desde Control ex
            Offset(1, 0.2), // Entrada desde Control me
            Offset(1, 0.5), // Entrada desde Control wb
            Offset(rx_controlMuxHzd, 1), // Salida hacia los muxes
          ],
        ),
      ),

    if (isPipelineMode)
      Positioned(
        top: yHazardUnits,
        left: xHazardUnits,
        child: MouseRegion(
          onEnter: (_) => datapathState.setHoverInfo(_getHazardTooltipText(datapathState)),
          onExit: (_) => datapathState.setHoverInfo(''),
          child:                         
          HazardUnitWidget(
          label: '',
          isActive: false,
          activeColor: Colors.transparent,
          ),
          ),
      ),
      


    // --- MuxC result ---
    Positioned(
      top: yMuxWB,
      left: xMuxWB,
      child: MouseRegion(
        onEnter: (_) => datapathState.setHoverInfo(_muxCHoverId),
        onExit: (_) => datapathState.setHoverInfo(''),
        child: MuxWidget(
          key: datapathState.muxCKey,
          value: (isPipelineMode ? datapathState.busValues['control_ResSrc'] : datapathState.busValues['control_ResSrc']) ?? 0,
          isActive: isPipelineMode?datapathState.isPathActive("Pipe_MEM_WB_NPC_out"):datapathState.isMuxCActive,
          labels: ['2', '1', '0', ' '],
          color:isSingleCycleMode?defaultColor:(isMultiCycleMode?color5:pipelineColorForPC((datapathState.busValues['Pipe_MEM_WB_NPC_out']??0)-4)),

        ),
      ),
    ),

    // --- Instruction Labels ---
    if (!isPipelineMode)
      Positioned(
        top: yInstrucciones,
        left: xInstruction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            //Text(datapathState.instructionValue.toRadixString(2).padLeft(32, '0'),style: miEstiloTooltip.copyWith(fontSize: 24,fontWeight: FontWeight.bold,),                            ),
            buildFormattedInstruction(datapathState.instructionInfo, datapathState.instructionValue),
          ],
        ),
      ),
    if (!isPipelineMode)
      Positioned(
        top: yInstrucciones,
        left: xInstructionD,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "${datapathState.instruction} (tipo ${datapathState.instructionInfo.type})",
              style: miEstiloInst.copyWith(fontSize: 24),
            ),
          ],
        ),
      ),

      if (isPipelineMode)
      Positioned(
        top: yInstrucciones,
        left: xInstruction1,
        child: Text(
          datapathState.pipeIfInstruction,
              style: miEstiloInst,
        ),
      ),                     
      if (isPipelineMode)
      Positioned(
        top: yInstrucciones,
        left: xInstruction2,
        child: Text(
          datapathState.pipeIdInstruction,
              style: miEstiloInst,
        ),
      ),
      if (isPipelineMode)
      Positioned(
        top: yInstrucciones,
        left: xInstruction3,
        child: Text(
          datapathState.pipeExInstruction,
              style: miEstiloInst,
        ),
      ),
      if (isPipelineMode)
      Positioned(
        top: yInstrucciones,
        left: xInstruction4,
        child: Text(
          datapathState.pipeMemInstruction,
              style: miEstiloInst,
        ),
      ),
      if (isPipelineMode)
      Positioned(
        top: yInstrucciones,
        left: xInstruction5,
        child: Text(
          datapathState.pipeWbInstruction,
              style: miEstiloInst,
        ),
      ),                    
      
  //zONA DERECHA
  Positioned(top:0,left:xDerecha,child:
  Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Row(
        children: [
          Checkbox(
            value: datapathState.showConnectionLabels,
            onChanged: (value) => datapathState.setShowConnectionLabels(value),
            visualDensity: VisualDensity.compact,
          ),
          const Text('Show connectors', style: TextStyle(fontSize: 9)),
        ],
      ),
      Row(
        children: [
          Checkbox(
            value: datapathState.showBusesLabels,
            onChanged:(value) => datapathState.setShowBusesLabels(value), 
            visualDensity: VisualDensity.compact),
          const Text('Show buses values', style: TextStyle(fontSize: 9, color: Colors.black)),
        ],
      ),
      Row(
        children: [
          Checkbox(
            value: datapathState.showControl,
            onChanged:(value) => datapathState.setControlVisibility(value), 
            visualDensity: VisualDensity.compact),
          const Text('Show control signals', style: TextStyle(fontSize: 9, color: Colors.black)),
        ],
        
      ),
    if (isPipelineMode)
      Row(
          children: [
            Checkbox(
              value: datapathState.showForwarding,
              onChanged:(value) => datapathState.setForwardingVisibility(value), 
              visualDensity: VisualDensity.compact),
            const Text('Show forwarding', style: TextStyle(fontSize: 9, color: Colors.black)),
          ],
          
        ),
    if (isPipelineMode)
      Row(
          children: [
            Checkbox(
              value: datapathState.showLHU,
              onChanged:(value) => datapathState.setShowLHU(value), 
              visualDensity: VisualDensity.compact),
            const Text('Show LHU', style: TextStyle(fontSize: 9, color: Colors.black)),
          ],
        ),
    if (isPipelineMode)
      Row(
          children: [
            Checkbox(
              value: datapathState.showBHU,
              onChanged:(value) => datapathState.setShowBHU(value), 
              visualDensity: VisualDensity.compact),
            const Text('Show BHU', style: TextStyle(fontSize: 9, color: Colors.black)),
          ],
        ),
      const SizedBox(height: 16),
      // --- Contenedor para el Historial de Ejecución ---
      // Le damos un tamaño fijo y un borde para que se vea bien.
      Container(
        height: 470, // Altura fija para el historial
        width: 180,  // Ancho fijo
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const ExecutionHistoryView(),
      ),
    ],
  ),
  ),
  ];
}


final miEstiloTooltip = TextStyle(
  fontFamily: 'RobotoMono',
  fontSize: 12,
  color: Colors.white,
  fontWeight: FontWeight.bold,
  fontFeatures: [const FontFeature.disable('liga')],
);

/// Un widget que muestra un texto en una caja semitransparente, posicionado
/// de forma absoluta. Sigue al cursor del ratón.
class FloatingTooltip extends StatelessWidget {
  final String message;
  final Offset position;

  const FloatingTooltip({
    super.key,
    required this.message,
    required this.position,
  });

  @override
  Widget build(BuildContext context) {
    final datapathState = Provider.of<DatapathState>(context, listen: false);

    Widget content;
    if (message == _registerFileHoverId) {
      content = buildRegisterFileTooltip(datapathState);
    } else if (message == _instructionMemoryHoverId) {
      content = buildInstructionMemoryTooltip(datapathState);
    } else if (message == _dataMemoryHoverId) {
      content = buildDataMemoryTooltip(datapathState);
    } else if (message == _controlHoverId) {
      content = buildControlUnitTooltip(datapathState);
    } else if (message == _muxPcHoverId) {
      content = buildMuxPcTooltip(datapathState);
    } else if (message == _pcAdderHoverId) {
      content = buildPcAdderTooltip(datapathState);
    } else if (message == _muxBHoverId) {
      content = buildMuxBTooltip(datapathState);
    } else if (message == _muxCHoverId) {
      content = buildMuxCTooltip(datapathState);
    } else if (message == _branchHoverId) {
      content = buildBranchTooltip(datapathState);
    } else if (message == _aluHoverId) {
      content = buildAluTooltip(datapathState);
    } else if (message == _immHoverId) {
      content = buildImmTooltip(datapathState);
    } else if (message.startsWith('##CONTROL_BUS:')) {
      final signalKey = message.substring('##CONTROL_BUS:'.length);
      content = buildControlBusTooltip(datapathState, signalKey);
    } else if (message == _controlTableHoverId) {
      content = buildControlTableTooltip();
    } else if (message == _instructionFormatTableHoverId) {
      content = buildInstructionFormatTooltip();
    } else {
      content = Text(
        message,
        style: miEstiloTooltip.copyWith(color: Colors.white),
      );
    }

    // Usamos un Positioned para colocar el tooltip en las coordenadas del ratón.
    return Positioned(
      left: position.dx + 15, // Pequeño offset para que no tape el cursor.
      top: position.dy + 15,
      // IgnorePointer evita que el tooltip intercepte eventos del ratón.
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(200),
            borderRadius: BorderRadius.circular(6),
          ),
          child: content,
        ),
      ),
    );
  }
}
