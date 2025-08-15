import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'datapath_state.dart';
import 'simulation_mode.dart';

/// Un widget que representa un registro de pipeline (como A, B, NPC).
/// Su ancho es 0 en modo single-cycle (transparente) y 15 en los demás modos.
class RegWidget extends StatelessWidget {
  final bool isActive;
  final List<Offset> connectionPoints;
  final String label;
  final double height;
  final bool visibility;

  // Constructor del widget. La 'key' es para que Flutter identifique el widget.  

  const RegWidget({ 
    super.key,
    required this.label,
    this.height=40,
    this.isActive = false,
    this.connectionPoints = const [
      Offset(0, 0.5), // Punto de conexión a la izquierda, centrado verticalmente.
      Offset(1, 0.5), // Punto de conexión a la derecha, centrado verticalmente.
    ],
    this.visibility=false,
  });

  @override
  Widget build(BuildContext context) {
    final datapathState = Provider.of<DatapathState>(context);
    //final bool exist=datapathState.simulationMode == SimulationMode.singleCycle;

    final Color backgroundColor = isActive ? Colors.green.shade200 : Colors.blueGrey.shade100;
    final Color borderColor = !visibility ? Colors.black.withAlpha(0): isActive ? Colors.black : Colors.black.withAlpha(15);

    final double widgetWidth = !visibility ? 0 : 15;

    return Container(
      width: widgetWidth,
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(color: borderColor, width: 2),
      ),
    );
  }
}