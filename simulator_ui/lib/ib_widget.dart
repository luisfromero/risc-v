import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'datapath_state.dart';
import 'simulation_mode.dart';
import 'colors.dart';
import 'geometry.dart';


class IBWidget extends StatelessWidget {
  final bool isActive;
  final List<Offset> connectionPoints;
  final color;

  // Constructor del widget. La 'key' es para que Flutter identifique el widget.
  const IBWidget({
    super.key,
    this.isActive = false,
    this.connectionPoints = const [
      Offset(0,0.385),
      Offset(0,0.045),
      Offset(1,0.09),
      Offset(1,0.16),
      Offset(1,r_IB4),
      Offset(1,r_IB5),
      Offset(1,r_IB6),
      Offset(1,r_IB7),
    ],
    this.color = defaultColor, // Color por defecto
  });

  @override
  Widget build(BuildContext context) {
    // Accedemos al estado global para determinar el ancho del widget.
    final datapathState = Provider.of<DatapathState>(context);

    final Color backgroundColor = isActive ? color : color.withAlpha(30);
    final Color activeText =isActive?Colors.black:Colors.black.withAlpha(15);

    final double widgetWidth = datapathState.simulationMode == SimulationMode.singleCycle ? 0 : widthReg;
    // Usamos un Container como base para nuestro componente.
    // Es como una caja (<div> en web) que podemos decorar.
    return Container(
      width: widgetWidth,  // Ancho de la caja
      height: heightIB, // Alto de la caja
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