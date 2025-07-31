import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'datapath_state.dart';          // Importa nuestro estado
import 'pc_widget.dart';
import 'adder_widget.dart';
import 'mux_widget.dart';
import 'services/ffi_simulation_service.dart'; // Importamos la implementación FFI

void main() {
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
          title: const Text('Datapath Interactivo'),
          backgroundColor: Colors.blueGrey,
          actions: [
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
            Expanded(
              // El Stack ahora ocupa todo el espacio disponible
              child: Stack(
                children: [
                  // --- PC ---
                  Positioned(
                    top: 100,
                    left: 50,
                    // MouseRegion detecta cuando el ratón entra o sale de su área.
                    child: MouseRegion(
                      onEnter: (_) => datapathState.setHoverInfo('PC: 0x${datapathState.pcValue.toRadixString(16)}'),
                      onExit: (_) => datapathState.setHoverInfo(''),
                      child: const PcWidget(),
                    ),
                  ),
                  // --- Sumador del PC ---
                  Positioned(
                    top: 100,
                    left: 200,
                    child: MouseRegion(
                      onEnter: (_) => datapathState.setHoverInfo(
                          'ADD4: 0x${datapathState.pcValue.toRadixString(16)} + 4 = 0x${(datapathState.pcValue + 4).toRadixString(16)}'),
                      onExit: (_) => datapathState.setHoverInfo(''),
                      // El color del sumador ahora depende del estado global
                      child: AdderWidget(
                        label: 'ADD4',
                        isActive: datapathState.isPcAdderActive,
                      ),
                    ),
                  ),
                  // --- Sumador de Saltos (Branch) ---
                  Positioned(
                    top: 300,
                    left: 350,
                    child: MouseRegion(
                      onEnter: (_) => datapathState.setHoverInfo('ADD2: Sumador para saltos condicionales'),
                      onExit: (_) => datapathState.setHoverInfo(''),
                      child: AdderWidget(
                        label: 'ADD2',
                        isActive: datapathState.isBranchAdderActive,
                      ),
                    ),
                  ),
                  // --- ALU ---
                  Positioned(
                    top: 250,
                    left: 500,
                    child: MouseRegion(
                      onEnter: (_) => datapathState.setHoverInfo('ALU: Unidad Aritmético-Lógica'),
                      onExit: (_) => datapathState.setHoverInfo(''),
                      child: AdderWidget(
                        label: 'ALU',
                        isActive: datapathState.isAluActive,
                      ),
                    ),
                  ),

                  Positioned(
                    top: 250,
                    left: 600,
                    child: MouseRegion(
                      onEnter: (_) => datapathState.setHoverInfo('Mux1'),
                      onExit: (_) => datapathState.setHoverInfo(''),
                      child: MuxWidget(
                        value: 3,
                        isActive: datapathState.isMux1Active,
                      ),
                    ),
                  ),

                  Positioned(
                    top: 250,
                    left: 700,
                    child: MouseRegion(
                      onEnter: (_) => datapathState.setHoverInfo('Mux2'),
                      onExit: (_) => datapathState.setHoverInfo(''),
                      child: MuxWidget(
                        value: 3,
                        isActive: datapathState.isMux2Active,
                      ),
                    ),
                  ),

                  Positioned(
                    top: 250,
                    left: 800,
                    child: MouseRegion(
                      onEnter: (_) => datapathState.setHoverInfo('Mux3'),
                      onExit: (_) => datapathState.setHoverInfo(''),
                      child: MuxWidget(
                        value: 3,
                        isActive: datapathState.isMux3Active,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // --- Slider ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
              child: Slider(
                value: datapathState.sliderValue,
                min: 0,
                max: 100, // O el valor máximo que necesites
                divisions: 100, // Opcional: para que el slider se mueva en pasos
                label: datapathState.sliderValue.round().toString(),
                onChanged: (double value) {
                  // Llama al método para actualizar el estado del slider
                  datapathState.setSliderValue(value);
                },
              ),
            ),
          ],
        ),
        // Un botón flotante para simular un ciclo de reloj
        floatingActionButton: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FloatingActionButton(
              onPressed: () {
                // Llama al método que resetea el estado.
                Provider.of<DatapathState>(context, listen: false).reset();
              },
              tooltip: 'Reset',
              child: const Icon(Icons.refresh),
            ),
            const SizedBox(width: 10), // Espacio entre botones
            FloatingActionButton(
              onPressed: () {
                // Al pulsar, llamamos al método que cambia el estado.
                Provider.of<DatapathState>(context, listen: false).clockTick();
              },
              tooltip: 'Clock Tick',
              child: const Icon(Icons.timer),
            ),
          ],
        ),
      ),
    );
  }
}