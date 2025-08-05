import 'package:flutter/material.dart';

class IBWidget extends StatelessWidget {
  final bool isActive;
  final List<Offset> connectionPoints;

  // Constructor del widget. La 'key' es para que Flutter identifique el widget.
  const IBWidget({
    super.key,
    this.isActive = false,
    this.connectionPoints = const [
      Offset(0,0.42),

      Offset(1,0.05),
      Offset(1,0.1),
      Offset(1,0.15),
      Offset(1,0.266),
      Offset(1,0.366),
      Offset(1,0.466),
      Offset(1,0.91),
    ],
  });

  @override
  Widget build(BuildContext context) {
    final Color backgroundColor = isActive ? Colors.green.shade200 : Colors.blueGrey.shade100;
    // Usamos un Container como base para nuestro componente.
    // Es como una caja (<div> en web) que podemos decorar.
    return Container(
      width: 0,  // Ancho de la caja
      height: 240, // Alto de la caja
      // La decoración nos permite añadir color, bordes, sombras, etc.
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(         // Un borde negro
          color: Colors.black,
          width: 2,
        ),
      ),
      // El 'child' es lo que va DENTRO del Container.
    );
  }
}