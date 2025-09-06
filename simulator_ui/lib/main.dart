import 'package:flutter/material.dart';
import 'colors.dart';
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
import 'extender_widget.dart';
import 'control_unit_widget.dart';
import 'services/get_service.dart'; // Importación condicional del servicio
import 'simulation_mode.dart';
import 'tooltip_widgets.dart';
import 'platform_init.dart'; // Importación condicional para la configuración de la ventana

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
  final inStr = (valIn == null) ? 'not set' : '0x${valIn.toRadixString(16).padLeft(digits, '0').toUpperCase()}';
  final outStr = (valOut == null) ? 'not set' : '0x${valOut.toRadixString(16).padLeft(digits, '0').toUpperCase()}';
  
  final namePart = name.isNotEmpty ? '$name\n' : '\n';
  return "${namePart}in : $inStr \nout: $outStr";
}

/// Genera un tooltip para un único registro sin nombre explícito.
String formatSingleRegisterHover(int? valIn, int? valOut, {int digits = 8}) {
  return _formatRegisterLine('', valIn, valOut, digits);
}

/// Genera un tooltip para múltiples registros, cada uno con su nombre.
String formatMultiRegisterHover(List<HoverRegisterData> registers) {
  return registers
      .map((r) => _formatRegisterLine(r.name, r.valIn, r.valOut, r.digits))
      .join('\n\n');
}

Color pipelineColorForPC(int? pc) {
  // Ejemplo: elige entre 4 colores cíclicamente según el valor del PC
  if(pc==null||pc==0)return Color.fromARGB(30, 0, 0, 0); // Si el PC es nulo, devolvemos un color transparente
  const colors = [color1, color2, color3, color4, color5];

  return colors[((pc) ~/ 4) % colors.length];
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
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
                  ElevatedButton.icon(
                    onPressed: () => Provider.of<DatapathState>(context, listen: false).reset(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reset'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade100, foregroundColor: Colors.black),
                  ),
                  const SizedBox(width: 10),
                  Tooltip(
                    message: 'Step forward (Long press or Ctrl+Click to step back)',
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Comprueba si la tecla Control (izquierda o derecha) está pulsada
                        final isControlPressed = HardwareKeyboard.instance.isControlPressed;
                        if (isControlPressed) {
                          datapathState.stepBack();
                        } else {
                          datapathState.step();
                        }
                      },
                      onLongPress: () => datapathState.stepBack(),
                      icon: const Icon(Icons.timer),
                      label: const Text('Clock Tick'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade100, foregroundColor: Colors.black),
                    ),
                  ),
                  const SizedBox(width: 20), // Espacio antes de la Unidad de Control
                  // Widget de la Unidad de Control
                  MouseRegion(
                    onEnter: (_) => datapathState.setHoverInfo(_controlHoverId),
                    onExit: (_) => datapathState.setHoverInfo(''),
                    child: SizedBox(
                      // Mantenemos el SizedBox para fijar el tamaño de la ControlUnit
                      width: 1070,
                      height: 90,
                      child: ControlUnitWidget(
                        key: datapathState.controlUnitKey,
                        isActive: datapathState.isControlActive,
                      ),
                    ),
                  ),
                  Expanded(
                    child: 
                  Row(
                    //mainAxisAlignment:MainAxisAlignment.center,
                    children: [
                  const SizedBox(width: 60),
                  Image.asset(
                        'img/dac.png', // <-- CAMBIA ESTO por el nombre de tu primer logo
                        width: 60,
                        height: 50,
                      ),
                  const SizedBox(width: 10),
                  Image.asset(
                        'img/uma.png', // <-- CAMBIA ESTO por el nombre de tu primer logo
                        width: 70,
                        height: 70,
                      ),
                ],)
                
              ),
                ],
              ),
            ),
            Expanded(
              // --- CAMBIO 2: AÑADIDO ---
              // Envolvemos el Stack en un MouseRegion para capturar la posición del ratón.
              child: MouseRegion(
                onHover: (event) {
                  // Actualizamos la posición del ratón en el estado.
                  // Usamos la posición local para que las coordenadas sean relativas
                  // al área del Stack.
                  datapathState.setMousePosition(event.localPosition);
                },
                child: Stack(
                  key: datapathState.stackKey,
                  children: [
                    // --- Pintor de Buses (se dibuja detrás de todo) ---
                    CustomPaint(
                      painter: BusesPainter(datapathState),
                      size: Size.infinite,
                    ),

                    // --- Mux2 PC ---
                    Positioned(
                      top: 220,
                      left: 60,
                      child: MouseRegion(
                        onEnter: (_) => datapathState.setHoverInfo(_muxPcHoverId),
                        onExit: (_) => datapathState.setHoverInfo(''),
                        child: MuxWidget(
                          key: datapathState.mux2Key,
                          value: datapathState.busValues['control_PCsrc'] ?? 0,
                          isActive: isPipelineMode? true: datapathState.isMux2Active,
                          color:isSingleCycleMode?defaultColor:(isMultiCycleMode?color5:pipelineColorForPC(datapathState.busValues['Pipe_MEM_WB_NPC_out'])),
                        ),
                      ),
                    ),
                    // --- PC ---
                    Positioned(
                      top: 200,
                      left: 200,
                      // MouseRegion detecta cuando el ratón entra o sale de su área.
                      child: MouseRegion(
                        onEnter: (_) => datapathState.setHoverInfo('PC: ${formatSingleRegisterHover(datapathState.pcValue, datapathState.busValues['mux_pc_bus'])}'),
                        onExit: (_) => datapathState.setHoverInfo(''),
                        child: PcWidget(
                          key: datapathState.pcKey,
                          isActive: datapathState.isPCActive,
                          color:isSingleCycleMode?defaultColor:(isMultiCycleMode?color1:pipelineColorForPC(datapathState.pcValue)),
                        ),
                      ),
                    ),

                    // --- Sumador del PC ---
                    Positioned(
                      top: 90,
                      left: 300,
                      child: MouseRegion(
                        onEnter: (_) => datapathState.setHoverInfo(_pcAdderHoverId),
                        onExit: (_) => datapathState.setHoverInfo(''),
                        // El color del sumador ahora depende del estado global
                        child: AdderWidget(
                          key: datapathState.pcAdderKey,
                          label: 'NPC',
                          isActive: datapathState.isPcAdderActive,
                          connectionPoints: [
                            Offset(-0.3,0.25),
                            Offset(0,0.25),
                            Offset(0,0.75),
                            Offset(1,0.5),
                            Offset(2,0.5),
                          ],
                          color:isSingleCycleMode?defaultColor:(isMultiCycleMode?color1:pipelineColorForPC(datapathState.pcValue)),


                        ),
                      ),
                    ),
                    // --- Memoria de Instrucciones ---
                    Positioned(
                      top: 200,
                      left: 400,
                      child: MouseRegion(
                        onEnter: (_) => datapathState.setHoverInfo(_instructionMemoryHoverId),
                        onExit: (_) => datapathState.setHoverInfo(''),
                        child: MemoryUnitWidget(
                          key: datapathState.instructionMemoryKey,
                          label: 'Instruct.\nMemory',
                          width: 80,
                          height: 120,
                          isActive: !isSingleCycleMode?true: datapathState.isIMemActive,
                          color:isSingleCycleMode?defaultColor:(isMultiCycleMode?color1:pipelineColorForPC(datapathState.pcValue)),
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
                      top: 110,
                      left: 170,
                      child: MouseRegion(
                        onEnter: (_) => datapathState.setHoverInfo('Constant: 4'),
                        onExit: (_) => datapathState.setHoverInfo(''),
                        child: Text("4 (0x00000004)")
                      ),
                    ),
                    // --- Instruction Buffer ---
                    Positioned(
                      top: 160,
                      left: 520,
                      child: MouseRegion(
                        onEnter: (_) => datapathState.setHoverInfo(isSingleCycleMode?'Instruction Buffer':
                        'IF_ID_Instr ${formatSingleRegisterHover(datapathState.busValues['Pipe_IF_ID_Instr'],datapathState.busValues['Pipe_IF_ID_Instr_out'])}'),
                        onExit: (_) => datapathState.setHoverInfo(''),
                        child: IBWidget(
                          key: datapathState.ibKey,
                          isActive: !isSingleCycleMode? datapathState.isPathActive('Pipe_IF_ID_Instr_out'): datapathState.isIBActive,
                          color:isSingleCycleMode?defaultColor:(isMultiCycleMode?color2:pipelineColorForPC(datapathState.busValues['Pipe_IF_ID_NPC_out'])),
                    
                        ),
                      ),
                    ),

                    // --- Pipeline Registers IF/ID ---
                    Positioned(
                      top: 120,
                      left: 520,
                      child: MouseRegion(
                        onEnter: (_) => datapathState.setHoverInfo('IF_ID_NPC ${formatSingleRegisterHover(datapathState.busValues['Pipe_IF_ID_NPC'],datapathState.busValues['Pipe_IF_ID_NPC_out'])}'),
                        onExit: (_) => datapathState.setHoverInfo(''),
                        child: RegWidget(
                          key: datapathState.pipereg_fd0_Key,
                          label: 'FD0',
                          height: 42,
                          isActive: datapathState.isPathActive("Pipe_IF_ID_Instr_out"),
                          color:isSingleCycleMode?defaultColor:(isMultiCycleMode?color2:pipelineColorForPC(datapathState.busValues['Pipe_IF_ID_NPC_out'])),
                          visibility: isPipelineMode,
                          connectionPoints: const [Offset(0, 0.715),Offset(1, 0.715),],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 420,
                      left: 520,
                      child: MouseRegion(
                        onEnter: (_) => datapathState.setHoverInfo('IF_ID_PC ${formatSingleRegisterHover(datapathState.busValues['Pipe_IF_ID_PC'],datapathState.busValues['Pipe_IF_ID_PC_out'])}'),
                        onExit: (_) => datapathState.setHoverInfo(''),
                        child: RegWidget(
                          key: datapathState.pipereg_fd1_Key,
                          label: 'FD1',
                          height: 40,
                          isActive: datapathState.isPathActive("Pipe_IF_ID_Instr_out"),
                          visibility: isPipelineMode,
                          color:isSingleCycleMode?defaultColor:(isMultiCycleMode?color2:pipelineColorForPC(datapathState.busValues['Pipe_IF_ID_NPC_out'])),
                        ),
                      ),
                    ),

                    // --- Banco de Registros ---
                    Positioned(
                      top: 200,
                      left: 620,
                      child: MouseRegion(                        
                        onEnter: (_) => datapathState.setHoverInfo(_registerFileHoverId),
                        onExit: (_) => datapathState.setHoverInfo(''),
                        child: MemoryUnitWidget(
                          key: datapathState.registerFileKey,
                          label: 'Register\nFile',
                          isActive: isPipelineMode?datapathState.isPathActive("Pipe_IF_ID_Instr_out"): datapathState.isRegFileActive,
                          height: 120,
                          // 7 Puntos para el Banco de Registros
                          connectionPoints: const [
                            Offset(0,0.2),
                            Offset(0,0.4),
                            Offset(0,0.6),
                            Offset(0,0.8),
                            Offset(0.5,0),
                            Offset(1,0.25),
                            Offset(1,0.65),
                            Offset(15/8.0,0.65),
                            ],
                          color:isSingleCycleMode?defaultColor:(isMultiCycleMode?color2:pipelineColorForPC(datapathState.busValues['Pipe_IF_ID_NPC_out'])),
                        ),
                      ),
                    ),
                    // --- Extender ---
                    Positioned(
                      top: 364,
                      left: 620,
                      child: MouseRegion(
                        onEnter: (_) => datapathState.setHoverInfo(_immHoverId),
                        onExit: (_) => datapathState.setHoverInfo(''),
                        child: ExtenderWidget(
                          key: datapathState.extenderKey,
                          label: 'Imm. ext.',
                          isActive: isPipelineMode?datapathState.isPathActive("Pipe_IF_ID_Instr_out"): datapathState.isExtenderActive,
                          color:isSingleCycleMode?defaultColor:(isMultiCycleMode?color2:pipelineColorForPC(datapathState.busValues['Pipe_IF_ID_NPC_out'])),

                          width: 100,
                          height: 30,
                        ),
                      ),
                    ),

                    // --- Pipeline Registers ---
                    if(datapathState.showControl)
                    Positioned(
                      top: 80,
                      left: 740,
                      child: MouseRegion(
                        onEnter: (_) => datapathState.setHoverInfo('DE/EX Control ${formatSingleRegisterHover(datapathState.busValues['Pipe_ID_EX_Control'],datapathState.busValues['Pipe_ID_EX_Control_out'], digits: 4)}'),
                        onExit: (_) => datapathState.setHoverInfo(''),
                        child: RegWidget(
                          key: datapathState.pipereg_deControl_Key,
                          label: 'DEControl ',
                          height: 30,
                          isActive: datapathState.isPathActive("Pipe_ID_EX_Control_out"),
                          visibility: isPipelineMode,
                          connectionPoints: const [Offset(0, 0.5),Offset(1, 0.33),Offset(1, 0.666),], //Llega en 100, salen en 90 y 100
                          color:isSingleCycleMode?defaultColor:(isMultiCycleMode?color3:pipelineColorForPC(datapathState.busValues['Pipe_ID_EX_NPC_out'])),

                        ),
                      ),
                    ),

                    Positioned(
                      top: 120,
                      left: 740,
                      child: MouseRegion(
                        onEnter: (_) => datapathState.setHoverInfo('DE/EX Register (NPC)  ${formatSingleRegisterHover(datapathState.busValues['Pipe_ID_EX_NPC'],datapathState.busValues['Pipe_ID_EX_NPC_out'])}'),
                        onExit: (_) => datapathState.setHoverInfo(''),
                        child: RegWidget(
                          key: datapathState.pipereg_de0_Key,
                          label: 'DE0',
                          height: 42,
                          isActive: datapathState.isPathActive("Pipe_ID_EX_NPC_out"),
                          visibility: isPipelineMode,
                          connectionPoints: const [Offset(0, 0.715),Offset(1, 0.715),],
                          color:isSingleCycleMode?defaultColor:(isMultiCycleMode?color3:pipelineColorForPC(datapathState.busValues['Pipe_ID_EX_NPC_out'])),

                        ),
                      ),
                    ),
                    Positioned(
                      top: 160,
                      left: 740,
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
                            HoverRegisterData("ID/EX (RD)", datapathState.busValues['Pipe_ID_EX_RD'], datapathState.busValues['Pipe_ID_EX_RD_out']),
                            HoverRegisterData("ID/EX (Imm)", datapathState.busValues['Pipe_ID_EX_Imm'], datapathState.busValues['Pipe_ID_EX_Imm_out']),
                          ])
                        ),
                        onExit: (_) => datapathState.setHoverInfo(''),
                        child: RegWidget(
                          label:'DE1',
                          height: 262,
                          key: datapathState.pipereg_de1_Key,
                          isActive: datapathState.isPathActive("Pipe_ID_EX_NPC_out"),
                          visibility: !isSingleCycleMode,
                          connectionPoints: const [Offset(0, 0.269),Offset(0, 0.453),Offset(0, 0.7115),Offset(0, 0.838),Offset(1, 0.269),Offset(1, 0.453),Offset(1, 0.7115),Offset(1, 0.838)],
                          color:isSingleCycleMode?defaultColor:(isMultiCycleMode?color3:pipelineColorForPC(datapathState.busValues['Pipe_ID_EX_NPC_out'])),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 420,
                      left: 740,
                      child: MouseRegion(
                        onEnter: (_) => datapathState.setHoverInfo('DE/EX Register (PC) ${formatSingleRegisterHover(datapathState.busValues['Pipe_ID_EX_PC'],datapathState.busValues['Pipe_ID_EX_PC_out'])}'),
                        onExit: (_) => datapathState.setHoverInfo(''),
                        child: RegWidget(
                          key: datapathState.pipereg_de2_Key,
                          label: 'DE2',
                          height: 40,
                          isActive: datapathState.isPathActive("Pipe_ID_EX_PC_out"),
                          visibility: isPipelineMode,
                          color:isSingleCycleMode?defaultColor:(isMultiCycleMode?color3:pipelineColorForPC(datapathState.busValues['Pipe_ID_EX_NPC_out'])),
                        ),
                      ),
                    ),

                    // --- MuxB ---
                    Positioned(
                      top: 265,
                      left: 860,
                      child: MouseRegion(
                        onEnter: (_) => datapathState.setHoverInfo(_muxBHoverId),
                        onExit: (_) => datapathState.setHoverInfo(''),
                        child: Mux2Widget(
                          key: datapathState.mux3Key,
                          value: datapathState.busValues['control_ALUsrc'] ?? 0,
                          isActive: isPipelineMode?datapathState.isPathActive("Pipe_ID_EX_B_out"): datapathState.isMux3Active,
                          labels: ['0', '1', '2', ' '],
                          color:isSingleCycleMode?defaultColor:(isMultiCycleMode?color3:pipelineColorForPC(datapathState.busValues['Pipe_ID_EX_NPC_out'])),

                        ),
                      ),
                    ),
                    // --- ALU ---
                    Positioned(
                      top: 200,
                      left: 920,
                      child: MouseRegion(
                        onEnter: (_) => datapathState.setHoverInfo(_aluHoverId),
                        onExit: (_) => datapathState.setHoverInfo(''),
                        child: AdderWidget(
                          key: datapathState.aluKey,
                          label: 'ALU',
                          isActive: isPipelineMode?datapathState.isPathActive("Pipe_ID_EX_A_out"): datapathState.isAluActive,
                          color:isSingleCycleMode?defaultColor:(isMultiCycleMode?color3:pipelineColorForPC(datapathState.busValues['Pipe_ID_EX_NPC_out'])),
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
                      top: 350,
                      left: 900,
                      child: MouseRegion(
                        onEnter: (_) => datapathState.setHoverInfo(_branchHoverId),
                        onExit: (_) => datapathState.setHoverInfo(''),
                        child: AdderWidget(
                          key: datapathState.branchAdderKey,
                          label: '  BR\ntarget',
                          isActive: !isSingleCycleMode?datapathState.isPathActive("branch_target_bus"): datapathState.isBranchAdderActive,
                          color:isSingleCycleMode?defaultColor:(isMultiCycleMode?color3:pipelineColorForPC(datapathState.busValues['Pipe_ID_EX_NPC_out'])),
                        ),
                      ),
                    ),
                    
                    // --- Pipeline Registers ---
                    if(datapathState.showControl)
                    Positioned(
                      top: 80,
                      left: 1020,
                      child: MouseRegion(
                        onEnter: (_) => datapathState.setHoverInfo('EX/MEM Control ${formatSingleRegisterHover(datapathState.busValues['Pipe_EX_MEM_Control'],datapathState.busValues['Pipe_EX_MEM_Control_out'], digits: 4)}'),
                        onExit: (_) => datapathState.setHoverInfo(''),
                        child: RegWidget(
                          key: datapathState.pipereg_emControl_Key,
                          label: 'EMControl ',
                          height: 20,
                          isActive: datapathState.isPathActive("Pipe_EX_MEM_Control_out"),
                          visibility: isPipelineMode,
                          connectionPoints: const [Offset(0, 0.5),Offset(1, 0.25),Offset(1, 0.75),], // Le llega en 90. Uno sale en 85 y el otro en 95
                          color:isSingleCycleMode?defaultColor:(isMultiCycleMode?color3:pipelineColorForPC(datapathState.busValues['Pipe_EX_MEM_NPC_out'])),

                        ),
                      ),
                    ),


                    Positioned(
                      top: 120,
                      left: 1020,
                      child: MouseRegion(
                        onEnter: (_) => datapathState.setHoverInfo('EX/ME Register (NPC) ${formatSingleRegisterHover(datapathState.busValues['Pipe_EX_MEM_NPC'],datapathState.busValues['Pipe_EX_MEM_NPC_out'])}'),
                        onExit: (_) => datapathState.setHoverInfo(''),
                        child: RegWidget(
                          key: datapathState.pipereg_em0_Key,
                          height: 42,
                          label: 'EM0',
                          isActive: datapathState.isPathActive( "Pipe_EX_MEM_NPC_out"),
                          visibility: isPipelineMode,
                          connectionPoints: const [Offset(0, 0.715),Offset(1, 0.715),],
                          color:isSingleCycleMode?defaultColor:(isMultiCycleMode?color4:pipelineColorForPC(datapathState.busValues['Pipe_EX_MEM_NPC_out'])),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 160,
                      left: 1020,
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
                            HoverRegisterData("EX/ME (RD)", datapathState.busValues['Pipe_EX_MEM_RD'], datapathState.busValues['Pipe_EX_MEM_RD_out']),
                          ])
                          ),
                        onExit: (_) => datapathState.setHoverInfo(''),
                        child: RegWidget(
                          label:'EM1',
                          height: 262,
                          key: datapathState.pipereg_em1_Key,
                          isActive: datapathState.isPathActive("Pipe_EX_MEM_ALU_result_out"),
                          visibility: !isSingleCycleMode,
                          connectionPoints: const [Offset(0, 0.315),Offset(0, 0.384),Offset(0, 0.654),Offset(0, 0.7115),Offset(1, 0.315),Offset(1, 0.384),Offset(1, 0.654),Offset(1, 0.7115)],
                          color:isSingleCycleMode?defaultColor:(isMultiCycleMode?color4:pipelineColorForPC(datapathState.busValues['Pipe_EX_MEM_NPC_out'])),
                        ),
                      ),
                    ),

 



                    // --- Z ---
                    Positioned(
                      top: 220,
                      left: 1040,
                      child: MouseRegion(
                        onEnter: (_) => datapathState.setHoverInfo('flag Z'),
                        onExit: (_) => datapathState.setHoverInfo(''),
                        child: Text("Z")
                      ),
                    ),

                    

                    // --- Memoria de Datos ---
                    Positioned(
                      top: 200,
                      left: 1100,
                      child: MouseRegion(
                        onEnter: (_) => datapathState.setHoverInfo(_dataMemoryHoverId),
                        onExit: (_) => datapathState.setHoverInfo(''),
                        child: MemoryUnitWidget(
                          key: datapathState.dataMemoryKey,
                          label: 'Data\nMemory',
                          width: 80,
                          isActive: isPipelineMode?(datapathState.busValues["Pipe_MemWr"]==1)||datapathState.isPathActive("mem_read_data_bus") : datapathState.isDMemActive,
                          height: 120,
                          // 4 Puntos para D-Mem
                          connectionPoints: const [
                            Offset(0,0.5),
                            Offset(0,0.75),
                            Offset(0.5,0),
                            Offset(1,0.566),
                          ],
                          color:isSingleCycleMode?defaultColor:(isMultiCycleMode?color4:pipelineColorForPC(datapathState.busValues['Pipe_EX_MEM_NPC_out'])),
                        ),
                      ),
                    ),

                    // --- Pipeline Registers ---
                    if(datapathState.showControl)
                    Positioned(
                      top: 80,
                      left: 1220,
                      child: MouseRegion(
                        onEnter: (_) => datapathState.setHoverInfo('MEM/WB Control ${formatSingleRegisterHover(datapathState.busValues['Pipe_MEM_WB_Control'],datapathState.busValues['Pipe_MEM_WB_Control_out'], digits: 4)}'),
                        onExit: (_) => datapathState.setHoverInfo(''),
                        child: RegWidget(
                          key: datapathState.pipereg_mwControl_Key,
                          label: 'MWControl ',
                          height: 10,
                          isActive: datapathState.isPathActive("Pipe_MEM_WB_Control_out"),
                          visibility: isPipelineMode,
                          connectionPoints: const [Offset(0, 0.5),Offset(1, 0.5),],
                          color:isSingleCycleMode?defaultColor:(isMultiCycleMode?color3:pipelineColorForPC(datapathState.busValues['Pipe_MEM_WB_NPC_out'])),

                        ),
                      ),
                    ),


                    Positioned(
                      top: 120,
                      left: 1220,
                      child: MouseRegion(
                        onEnter: (_) => datapathState.setHoverInfo('ME/WR Register (NPC) ${formatSingleRegisterHover(datapathState.busValues['Pipe_MEM_WB_NPC'],datapathState.busValues['Pipe_MEM_WB_NPC_out'])}'),
                        onExit: (_) => datapathState.setHoverInfo(''),
                        child: RegWidget(
                          key: datapathState.pipereg_mw0_Key,
                          label: 'MW0',
                          height: 42,
                          isActive: datapathState.isPathActive("Pipe_MEM_WB_NPC_out"),
                          visibility: isPipelineMode,
                          connectionPoints: const [Offset(0, 0.715),Offset(1, 0.715),],
                          color:isSingleCycleMode?defaultColor:(isMultiCycleMode?color5:pipelineColorForPC(datapathState.busValues['Pipe_MEM_WB_NPC_out'])),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 160,
                      left: 1220,
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
                            HoverRegisterData("ME/WB (RD)", datapathState.busValues['Pipe_MEM_WB_RD'], datapathState.busValues['Pipe_MEM_WB_RD_out']),
                          ])
                        ),
                        onExit: (_) => datapathState.setHoverInfo(''),
                        child: RegWidget(
                          label:'MW1',
                          height: 262,
                          key: datapathState.pipereg_mw1_Key,
                          isActive: datapathState.isPathActive("Pipe_MEM_WB_NPC_out"),
                          visibility: !isSingleCycleMode,
                          connectionPoints: const [Offset(0, 0.0577),Offset(0, 0.412),Offset(0, 0.7115),Offset(1, 0.0577),Offset(1, 0.412),Offset(1, 0.7115)],
                          color:isSingleCycleMode?defaultColor:(isMultiCycleMode?color5:pipelineColorForPC(datapathState.busValues['Pipe_MEM_WB_NPC_out'])),

                        ),
                      ),
                    ),


                    // --- MuxC result ---
                    Positioned(
                      top: 220,
                      left: 1300,
                      child: MouseRegion(
                        onEnter: (_) => datapathState.setHoverInfo(_muxCHoverId),
                        onExit: (_) => datapathState.setHoverInfo(''),
                        child: MuxWidget(
                          key: datapathState.muxCKey,
                          value: datapathState.busValues['control_ResSrc'] ?? 0,
                          isActive: isPipelineMode?datapathState.isPathActive("Pipe_MEM_WB_NPC_out"):datapathState.isMuxCActive,
                          labels: ['2', '1', '0', ' '],
                          color:isSingleCycleMode?defaultColor:(isMultiCycleMode?color5:pipelineColorForPC(datapathState.busValues['Pipe_MEM_WB_NPC_out'])),

                        ),
                      ),
                    ),

                    // --- Instruction Labels ---
                    if (!isPipelineMode)
                      Positioned(
                        top: 540,
                        left: 840,
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
                        top: 540,
                        left: 430,
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
                        top: 540,
                        left: 300,
                        child: Text(
                          datapathState.pipeIfInstruction,
                              style: miEstiloInst,
                        ),
                      ),                     
                      if (isPipelineMode)
                      Positioned(
                        top: 540,
                        left: 550,
                        child: Text(
                          datapathState.pipeIdInstruction,
                              style: miEstiloInst,
                        ),
                      ),
                      if (isPipelineMode)
                      Positioned(
                        top: 540,
                        left: 800,
                        child: Text(
                          datapathState.pipeExInstruction,
                              style: miEstiloInst,
                        ),
                      ),
                      if (isPipelineMode)
                      Positioned(
                        top: 540,
                        left: 1050,
                        child: Text(
                          datapathState.pipeMemInstruction,
                              style: miEstiloInst,
                        ),
                      ),
                      if (isPipelineMode)
                      Positioned(
                        top: 540,
                        left: 1300,
                        child: Text(
                          datapathState.pipeWbInstruction,
                              style: miEstiloInst,
                        ),
                      ),                    
                      
                      
                  Positioned(top:100,left:1430,child:
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
                          const Text('Show connectors', style: TextStyle(fontSize: 10)),
                        ],
                      ),
                      Row(
                        children: [
                          Checkbox(
                            value: datapathState.showBusesLabels,
                            onChanged:(value) => datapathState.setShowBusesLabels(value), 
                            visualDensity: VisualDensity.compact),
                          const Text('Show buses values', style: TextStyle(fontSize: 10, color: Colors.black)),
                        ],
                      ),
                      Row(
                        children: [
                          Checkbox(
                            value: datapathState.showControl,
                            onChanged:(value) => datapathState.setControlVisibility(value), 
                            visualDensity: VisualDensity.compact),
                          const Text('Show control signals', style: TextStyle(fontSize: 10, color: Colors.black)),
                        ],
                      ),
                    ],
                  ),
                  ),



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
}

final miEstiloInst = TextStyle(
  fontFamily: 'RobotoMono',
  fontSize: 24,
  color: Colors.black,
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
