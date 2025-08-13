import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'datapath_state.dart';
import 'simulation_mode.dart';

class IBWidget extends StatelessWidget {
  final bool isActive;
  final List<Offset> connectionPoints;

  // Constructor del widget. La 'key' es para que Flutter identifique el widget.
  const IBWidget({
    super.key,
    this.isActive = false,
    this.connectionPoints = const [
      Offset(0,0.385),

      Offset(0,0.045),
      Offset(1,0.09),
      Offset(1,0.14),
      Offset(1,0.24),
      Offset(1,0.335),
      Offset(1,0.425),
      Offset(1,0.83),
    ],
  });

  @override
  Widget build(BuildContext context) {
    // Accedemos al estado global para determinar el ancho del widget.
    final datapathState = Provider.of<DatapathState>(context);

    final Color backgroundColor = isActive ? Colors.green.shade200 : Colors.blueGrey.shade100;
    final Color activeText =isActive?Colors.black:Colors.black.withAlpha(15);

    final double widgetWidth = datapathState.simulationMode == SimulationMode.singleCycle ? 0 : 15;
    // Usamos un Container como base para nuestro componente.
    // Es como una caja (<div> en web) que podemos decorar.
    return Container(
      width: widgetWidth,  // Ancho de la caja
      height: 262, // Alto de la caja
      // La decoración nos permite añadir color, bordes, sombras, etc.
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(         // Un borde negro
          color:activeText,
          width: 2,
        ),
      ),
      // El 'child' es lo que va DENTRO del Container.
    );
  }
}