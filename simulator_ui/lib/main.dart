import 'package:flutter/material.dart';
import 'package:namer_app/colors.dart';
import 'package:namer_app/reg_widget.dart';
import 'package:flutter/services.dart'; // Para RawKeyboard
import 'dart:ui'; // Para FontFeature
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
import 'services/simulation_service.dart';
import 'services/get_service.dart'; // Importación condicional del servicio
import 'simulation_mode.dart';
import 'platform_init.dart'; // Importación condicional para la configuración de la ventana

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupWindow(); // Ahora esperamos a que la ventana se configure

  runApp(
    ChangeNotifierProvider(
      // Creamos el estado y le "inyectamos" el servicio de simulación.
      create: (context) => DatapathState(getSimulationService())..initialize(),
      child: const MyApp(),
    ),
  );
}

String registerHover(int? val1, int? val2,[int digits = 8]) {
  String in_=(val1==null)?'not set':'0x${val1.toRadixString(16).padLeft(digits, '0')}';
  String out=(val2==null)?'not set':'0x${val2.toRadixString(16).padLeft(digits, '0')}';
  return "\nin : $in_ \nout: $out";

}

Color pipelineColorForPC(int? pc) {
  // Ejemplo: elige entre 4 colores cíclicamente según el valor del PC
  if(pc==null||pc==0)return Color.fromARGB(67, 0, 0, 0); // Si el PC es nulo, devolvemos un color transparente
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
              child: Center(
                child: Text(
                  datapathState.hoverInfo,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
                      // --- Selector de modo de simulación ---
            Row(
              children: [
                for (final mode in SimulationMode.values)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(mode.label, style: const TextStyle(color: Colors.white)),
                      Radio<SimulationMode>(
                        value: mode,
                        groupValue: datapathState.simulationMode,
                        onChanged: (SimulationMode? value) => datapathState.setSimulationMode(value),
                        activeColor: Colors.white,
                        fillColor: WidgetStateProperty.all(Colors.white70),

                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(width: 20), // Espacio entre el selector y las coordenadas

          ],
        ),
        // Usamos un Column para añadir el Slider debajo del Stack
        body: Column(
          children: [
            // --- Panel de Control Superior ---
            Container(
              padding: const EdgeInsets.all(12.0),
              //color: Colors.blueGrey.shade50,
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
                  SizedBox( // Mantenemos el SizedBox para fijar el tamaño de la ControlUnit
                    width: 1070,
                    height: 90,
                    child: ControlUnitWidget(
                      key: datapathState.controlUnitKey,
                      isActive: datapathState.isControlActive,
                    ),
                  ),
                  const SizedBox(width: 10), // Espacio entre la unidad de control y los checkboxes
                  // Checkboxes de depuración, ahora fuera del SizedBox
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
                    ],
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
                        onEnter: (_) => datapathState.setHoverInfo('MuxPC'),
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
                        onEnter: (_) => datapathState.setHoverInfo('PC: ${registerHover(datapathState.pcValue,datapathState.busValues['mux_pc_bus'])}'),
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
                        onEnter: (_) => datapathState.setHoverInfo(
                            'ADD4: 0x${datapathState.pcValue.toRadixString(16)} + 4 = 0x${(datapathState.pcValue + 4).toRadixString(16)}'),
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
                        onEnter: (_) => datapathState.setHoverInfo('Memoria de Instrucciones'),
                        onExit: (_) => datapathState.setHoverInfo(''),
                        child: MemoryUnitWidget(
                          key: datapathState.instructionMemoryKey,
                          label: 'Instruct.\nMemory',
                          width: 80,
                          height: 120,
                          isActive: datapathState.isIMemActive,
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
                        onEnter: (_) => datapathState.setHoverInfo(isSingleCycleMode?'Instruction Buffer':'IF_ID_Instr ${registerHover(datapathState.busValues['Pipe_IF_ID_Instr'],datapathState.busValues['Pipe_IF_ID_Instr_out'])}'),
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
                        onEnter: (_) => datapathState.setHoverInfo('IF_ID_NPC ${registerHover(datapathState.busValues['Pipe_IF_ID_NPC'],datapathState.busValues['Pipe_IF_ID_NPC_out'])}'),
                        onExit: (_) => datapathState.setHoverInfo(''),
                        child: RegWidget(
                          key: datapathState.pipereg_fd0_Key,
                          label: 'FD0',
                          height: 42,
                          isActive: datapathState.isPathActive("Pipe_IF_ID_NPC_out"),
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
                        onEnter: (_) => datapathState.setHoverInfo('IF_ID_PC ${registerHover(datapathState.busValues['Pipe_IF_ID_PC'],datapathState.busValues['Pipe_IF_ID_PC_out'])}'),
                        onExit: (_) => datapathState.setHoverInfo(''),
                        child: RegWidget(
                          key: datapathState.pipereg_fd1_Key,
                          label: 'FD1',
                          height: 40,
                          isActive: datapathState.isPathActive("Pipe_IF_ID_PC_out"),
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
                        onEnter: (_) => datapathState.setHoverInfo('Banco de Registros'),
                        onExit: (_) => datapathState.setHoverInfo(''),
                        child: MemoryUnitWidget(
                          key: datapathState.registerFileKey,
                          label: 'Register\nFile',
                          isActive: isPipelineMode?datapathState.isPathActive("rd1_bus"): datapathState.isRegFileActive,
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
                        onEnter: (_) => datapathState.setHoverInfo('Immediate extender'),
                        onExit: (_) => datapathState.setHoverInfo(''),
                        child: ExtenderWidget(
                          key: datapathState.extenderKey,
                          label: 'Imm. ext.',
                          isActive: isPipelineMode?datapathState.isPathActive("immExt_bus"): datapathState.isExtenderActive,
                          color:isSingleCycleMode?defaultColor:(isMultiCycleMode?color2:pipelineColorForPC(datapathState.busValues['Pipe_IF_ID_NPC_out'])),

                          width: 100,
                          height: 30,
                        ),
                      ),
                    ),

                    // --- Pipeline Registers ---
                    Positioned(
                      top: 80,
                      left: 740,
                      child: MouseRegion(
                        onEnter: (_) => datapathState.setHoverInfo('DE/EX Control ${registerHover(datapathState.busValues['Pipe_ID_EX_Control'],datapathState.busValues['Pipe_ID_EX_Control_out'], 4)}'),
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
                        onEnter: (_) => datapathState.setHoverInfo('DE/EX Register (NPC)  ${registerHover(datapathState.busValues['Pipe_ID_EX_NPC'],datapathState.busValues['Pipe_ID_EX_NPC_out'])}'),
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
                        onEnter: (_) => datapathState.setHoverInfo('DE/EX Register (A,B,destRegName,immExt)'),
                        onExit: (_) => datapathState.setHoverInfo(''),
                        child: RegWidget(
                          label:'DE1',
                          height: 262,
                          key: datapathState.pipereg_de1_Key,
                          isActive: datapathState.isPathActive("Pipe_ID_EX_A_out"),
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
                        onEnter: (_) => datapathState.setHoverInfo('DE/EX Register (PC) ${registerHover(datapathState.busValues['Pipe_ID_EX_PC'],datapathState.busValues['Pipe_ID_EX_PC_out'])}'),
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

                    // --- Sumador de Saltos (Branch) ---
                    Positioned(
                      top: 350,
                      left: 900,
                      child: MouseRegion(
                        onEnter: (_) => datapathState.setHoverInfo('Branch target: Sumador para saltos condicionales'),
                        onExit: (_) => datapathState.setHoverInfo(''),
                        child: AdderWidget(
                          key: datapathState.branchAdderKey,
                          label: '  BR\ntarget',
                          isActive: !isSingleCycleMode?datapathState.isPathActive("branch_target_bus"): datapathState.isBranchAdderActive,
                          color:isSingleCycleMode?defaultColor:(isMultiCycleMode?color3:pipelineColorForPC(datapathState.busValues['Pipe_ID_EX_NPC_out'])),
                        ),
                      ),
                    ),
                    // --- ALU ---
                    Positioned(
                      top: 200,
                      left: 920,
                      child: MouseRegion(
                        onEnter: (_) => datapathState.setHoverInfo('ALU: Unidad Aritmético-Lógica'),
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
                          ],
                        ),
                      ),
                    ),
                    // --- MuxB ---
                    Positioned(
                      top: 265,
                      left: 860,
                      child: MouseRegion(
                        onEnter: (_) => datapathState.setHoverInfo('MuxB'),
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
                    
                    // --- Pipeline Registers ---
                    Positioned(
                      top: 80,
                      left: 1020,
                      child: MouseRegion(
                        onEnter: (_) => datapathState.setHoverInfo('EX/MEM Control ${registerHover(datapathState.busValues['Pipe_EX_MEM_Control'],datapathState.busValues['Pipe_EX_MEM_Control_out'], 4)}'),
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
                        onEnter: (_) => datapathState.setHoverInfo('EX/ME Register (NPC) ${registerHover(datapathState.busValues['Pipe_EX_MEM_NPC'],datapathState.busValues['Pipe_EX_MEM_NPC_out'])}'),
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
                        onEnter: (_) => datapathState.setHoverInfo('EX/ME Register (ALU result, B, destRegName) ${registerHover(datapathState.busValues['Pipe_EX_MEM_ALU_result'],datapathState.busValues['Pipe_EX_MEM_ALU_result_out'])}'),
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

                    // ToDo Sustituir el HOVER en los registros de segmentación que contienen varios
 



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
                    // --- Instruction Labels ---
                    if (!isPipelineMode)
                      Positioned(
                        top: 540,
                        left: 800,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              datapathState.instruction,
                              style: const TextStyle(
                                fontSize: 24,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              datapathState.instructionValue.toRadixString(2).padLeft(32, '0'),
                              style: const TextStyle(fontSize: 20, fontFamily: 'monospace'),
                            ),
                          ],
                        ),
                      ),

                    // --- Pipeline Instruction Labels ---
                    if (isPipelineMode)
                      Positioned(
                        top: 540,
                        left: 300,
                        child: Text(
                          datapathState.pipeIfInstruction,
                          style: const TextStyle(fontSize: 24, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                        ),
                      ),
                    if (isPipelineMode)
                      Positioned(
                        top: 540,
                        left: 550,
                        child: Text(
                          datapathState.pipeIdInstruction,
                          style: const TextStyle(fontSize: 24, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                        ),
                      ),
                    if (isPipelineMode)
                      Positioned(
                        top: 540,
                        left: 800,
                        child: Text(
                          datapathState.pipeExInstruction,
                          style: const TextStyle(fontSize: 24, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                        ),
                      ),
                    if (isPipelineMode)
                      Positioned(
                        top: 540,
                        left: 1050,
                        child: Text(
                          datapathState.pipeMemInstruction,
                          style: const TextStyle(fontSize: 24, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                        ),
                      ),
                    if (isPipelineMode)
                      Positioned(
                        top: 540,
                        left: 1300,
                        child: Text(
                          datapathState.pipeWbInstruction,
                          style: const TextStyle(fontSize: 24, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                        ),
                      ),
                    

                    // --- Memoria de Datos ---
                    Positioned(
                      top: 200,
                      left: 1100,
                      child: MouseRegion(
                        onEnter: (_) => datapathState.setHoverInfo('Memoria de Datos'),
                        onExit: (_) => datapathState.setHoverInfo(''),
                        child: MemoryUnitWidget(
                          key: datapathState.dataMemoryKey,
                          label: 'Data\nMemory',
                          width: 80,
                          isActive: datapathState.isDMemActive,
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
                    Positioned(
                      top: 80,
                      left: 1220,
                      child: MouseRegion(
                        onEnter: (_) => datapathState.setHoverInfo('MEM/WB Control ${registerHover(datapathState.busValues['Pipe_MEM_WB_Control'],datapathState.busValues['Pipe_MEM_WB_Control_out'], 4)}'),
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
                        onEnter: (_) => datapathState.setHoverInfo('ME/WR Register (NPC) ${registerHover(datapathState.busValues['Pipe_MEM_WB_NPC'],datapathState.busValues['Pipe_MEM_WB_NPC_out'])}'),
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
                        onEnter: (_) => datapathState.setHoverInfo('ME/WR Register (ALU result, Read mem, Dest reg name)'),
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
                        onEnter: (_) => datapathState.setHoverInfo('MuxC'),
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
    // Usamos un Positioned para colocar el tooltip en las coordenadas del ratón.
    return Positioned(
      left: position.dx + 15, // Pequeño offset para que no tape el cursor.
      top: position.dy + 15,
      // IgnorePointer evita que el tooltip intercepte eventos del ratón.
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.85),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            message,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ),
      ),
    );
  }
}
