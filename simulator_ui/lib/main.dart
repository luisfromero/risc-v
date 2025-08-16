import 'package:flutter/material.dart';
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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final datapathState = Provider.of<DatapathState>(context);

    bool isSingleCycleMode = datapathState.simulationMode == SimulationMode.singleCycle;
    bool isPipelineMode = datapathState.simulationMode == SimulationMode.pipeline;
    
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
                        fillColor: MaterialStateProperty.all(Colors.white70),

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
                          Checkbox(value: false, onChanged: null, visualDensity: VisualDensity.compact),
                          const Text('Show values', style: TextStyle(fontSize: 10, color: Colors.grey)),
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
                          isActive: datapathState.isMux2Active,
                        ),
                      ),
                    ),
                    // --- PC ---
                    Positioned(
                      top: 200,
                      left: 200,
                      // MouseRegion detecta cuando el ratón entra o sale de su área.
                      child: MouseRegion(
                        onEnter: (_) => datapathState.setHoverInfo('PC: 0x${datapathState.pcValue.toRadixString(16)}'),
                        onExit: (_) => datapathState.setHoverInfo(''),
                        child: PcWidget(
                          key: datapathState.pcKey,
                          isActive: datapathState.isPCActive,
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
                          label: 'Instruction\nMemory',
                          width: 100,
                          height: 120,
                          isActive: datapathState.isIMemActive,
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
                        onEnter: (_) => datapathState.setHoverInfo('Instruction Bus'),
                        onExit: (_) => datapathState.setHoverInfo(''),
                        child: IBWidget(
                          key: datapathState.ibKey,
                          isActive: datapathState.isIBActive,
                        ),
                      ),
                    ),

                    // --- Pipeline Registers RE/DE ---
                    Positioned(
                      top: 130,
                      left: 520,
                      child: MouseRegion(
                        onEnter: (_) => datapathState.setHoverInfo('FD0'),
                        onExit: (_) => datapathState.setHoverInfo(''),
                        child: RegWidget(
                          key: datapathState.pipereg_fd0_Key,
                          label: 'FD0',
                          height: 40,
                          isActive: datapathState.isPcAdderActive,
                          visibility: isPipelineMode,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 420,
                      left: 520,
                      child: MouseRegion(
                        onEnter: (_) => datapathState.setHoverInfo('IF/DE Register (PC)'),
                        onExit: (_) => datapathState.setHoverInfo(''),
                        child: RegWidget(
                          key: datapathState.pipereg_fd1_Key,
                          label: 'FD1',
                          height: 40,
                          isActive: datapathState.isPcAdderActive,
                          visibility: isPipelineMode,
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
                          width: 100,
                          isActive: datapathState.isRegFileActive,
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
                            Offset(1.5,0.65),
                            ],
                        ),
                      ),
                    ),

                    // --- Pipeline Registers ---
                    Positioned(
                      top: 130,
                      left: 740,
                      child: MouseRegion(
                        onEnter: (_) => datapathState.setHoverInfo('DE/EX Register (PC)'),
                        onExit: (_) => datapathState.setHoverInfo(''),
                        child: RegWidget(
                          key: datapathState.pipereg_de0_Key,
                          label: 'DE0',
                          isActive: datapathState.isPcAdderActive,
                          visibility: isPipelineMode,

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
                          isActive: datapathState.isIBActive,
                          visibility: !isSingleCycleMode,
                          connectionPoints: const [Offset(0, 0.269),Offset(0, 0.453),Offset(0, 0.7115),Offset(0, 0.838),Offset(1, 0.269),Offset(1, 0.453),Offset(1, 0.7115),Offset(1, 0.838)],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 420,
                      left: 740,
                      child: MouseRegion(
                        onEnter: (_) => datapathState.setHoverInfo('DE/EX Register (PC)'),
                        onExit: (_) => datapathState.setHoverInfo(''),
                        child: RegWidget(
                          key: datapathState.pipereg_de2_Key,
                          label: 'DE2',
                          height: 40,
                          isActive: datapathState.isRegFileActive,
                          visibility: isPipelineMode,
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
                          isActive: datapathState.isBranchAdderActive,
                        ),
                      ),
                    ),
                    // --- ALU ---
                    Positioned(
                      top: 200,
                      left: 950,
                      child: MouseRegion(
                        onEnter: (_) => datapathState.setHoverInfo('ALU: Unidad Aritmético-Lógica'),
                        onExit: (_) => datapathState.setHoverInfo(''),
                        child: AdderWidget(
                          key: datapathState.aluKey,
                          label: 'ALU',
                          isActive: datapathState.isAluActive,
                          // 5 Puntos para la ALU
                          connectionPoints: const [
                            Offset(0,0.25),
                            Offset(0,0.75),
                            Offset(0.5,0.15),
                            Offset(1,0.35),
                            Offset(1,0.5),
                            Offset(2,0.5),
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
                          isActive: datapathState.isMux3Active,
                          labels: ['0', '1', '2', ' '],
                        ),
                      ),
                    ),
                    
                    // --- Pipeline Registers ---
                    Positioned(
                      top: 130,
                      left: 1020,
                      child: MouseRegion(
                        onEnter: (_) => datapathState.setHoverInfo('EX/ME Register (PC)'),
                        onExit: (_) => datapathState.setHoverInfo(''),
                        child: RegWidget(
                          key: datapathState.pipereg_em0_Key,
                          label: 'EM0',
                          isActive: datapathState.isPcAdderActive,
                          visibility: isPipelineMode,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 160,
                      left: 1020,
                      child: MouseRegion(
                        onEnter: (_) => datapathState.setHoverInfo('EX/ME Register (ALU result, B, destRegName)'),
                        onExit: (_) => datapathState.setHoverInfo(''),
                        child: RegWidget(
                          label:'EM1',
                          height: 262,
                          key: datapathState.pipereg_em1_Key,
                          isActive: datapathState.isIBActive,
                          visibility: !isSingleCycleMode,
                          connectionPoints: const [Offset(0, 0.315),Offset(0, 0.384),Offset(0, 0.654),Offset(0, 0.7115),Offset(1, 0.315),Offset(1, 0.384),Offset(1, 0.654),Offset(1, 0.7115)],
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
                              '${datapathState.instructionValue.toRadixString(2).padLeft(32, '0')}',
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
                          isActive: datapathState.isExtenderActive,

                          width: 100,
                          height: 30,
                        ),
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
                          width: 100,
                          isActive: datapathState.isDMemActive,
                          height: 120,
                          // 4 Puntos para D-Mem
                          connectionPoints: const [
                            Offset(0,0.5),
                            Offset(0,0.75),
                            Offset(0.5,0),
                            Offset(1,0.566),
                          ],
                        ),
                      ),
                    ),

                    // --- Pipeline Registers ---
                    Positioned(
                      top: 130,
                      left: 1220,
                      child: MouseRegion(
                        onEnter: (_) => datapathState.setHoverInfo('ME/WR Register (PC)'),
                        onExit: (_) => datapathState.setHoverInfo(''),
                        child: RegWidget(
                          key: datapathState.pipereg_mw0_Key,
                          label: 'MW0',
                          isActive: datapathState.isPcAdderActive,
                          visibility: isPipelineMode,
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
                          isActive: datapathState.isIBActive,
                          visibility: !isSingleCycleMode,
                          connectionPoints: const [Offset(0, 0.0577),Offset(0, 0.412),Offset(0, 0.7115),Offset(1, 0.0577),Offset(1, 0.412),Offset(1, 0.7115)],

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
                          isActive: datapathState.isMuxCActive,
                          labels: ['2', '1', '0', ' '],
                        ),
                      ),
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
