import 'package:flutter/material.dart';
import 'dart:ui'; // Para FontFeature
import 'dart:io'; 
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
import 'services/ffi_simulation_service.dart'; // Importamos la implementación FFI
import 'package:window_size/window_size.dart';

void main() {
    WidgetsFlutterBinding.ensureInitialized();

      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      setWindowTitle('RISC-V Datapath');
      setWindowMinSize(const Size(1500, 600));
      setWindowMaxSize(const Size(1920, 768));
      setWindowFrame(const Rect.fromLTWH(100, 100, 1500, 768)); // posición y tamaño inicial
    }

  runApp(
    ChangeNotifierProvider(
      // Creamos el estado y le "inyectamos" el servicio de simulación.
      // Si quisiéramos usar una API, solo cambiaríamos FfiSimulationService()
      // por ApiSimulationService() aquí.
      create: (context) => DatapathState(FfiSimulationService())..initialize(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final datapathState = Provider.of<DatapathState>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('RISC-V Datapath'),
          backgroundColor: Colors.blueGrey,
          actions: [
            // --- CAMBIO 1: AÑADIDO ---
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
            )
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
                  ElevatedButton.icon(
                    onPressed: () => Provider.of<DatapathState>(context, listen: false).step(),
                    icon: const Icon(Icons.timer),
                    label: const Text('Clock Tick'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade100, foregroundColor: Colors.black),
                  ),
                  const SizedBox(width: 20),
                  // Widget de la Unidad de Control
                  SizedBox(
                    width: 1070,
                    height: 90,
                    child: ControlUnitWidget(key: datapathState.controlUnitKey), // Quitamos 'const' para poder usar la key
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
                        onEnter: (_) => datapathState.setHoverInfo('Mux '),
                        onExit: (_) => datapathState.setHoverInfo(''),
                        child: MuxWidget(
                          key: datapathState.mux2Key,
                          value: 3,
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
                        child: PcWidget(key: datapathState.pcKey),
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
                    // --- Z ---
                    Positioned(
                      top: 230,
                      left: 1040,
                      child: MouseRegion(
                        onEnter: (_) => datapathState.setHoverInfo('flag Z'),
                        onExit: (_) => datapathState.setHoverInfo(''),
                        child: Text("Z")
                      ),
                    ),
                    // --- Instruction Labels ---
                    Positioned(
                      top: 400,
                      left: 1050,
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
                          value: 3,
                          isActive: datapathState.isMux3Active,
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
                    // --- Mux1 result ---
                    Positioned(
                      top: 220,
                      left: 1300,
                      child: MouseRegion(
                        onEnter: (_) => datapathState.setHoverInfo('Mux1'),
                        onExit: (_) => datapathState.setHoverInfo(''),
                        child: MuxWidget(
                          key: datapathState.mux1Key,
                          value: 0,
                          isActive: datapathState.isMux1Active,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // --- Slider ---
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
