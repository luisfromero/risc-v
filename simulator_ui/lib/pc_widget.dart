import 'package:flutter/material.dart';
import 'colors.dart';

class PcWidget extends StatelessWidget {
  // Constructor del widget. La 'key' es para que Flutter identifique el widget.
  final List<Offset> connectionPoints;
  final bool isActive; // Para recibir si debe estar "activo" (color verde)
  final Color color; // Color por defecto
  const PcWidget({
    super.key,
    this.isActive = false, // Por defecto no está activo
    this.connectionPoints = const [
      Offset(0,0.5),
      Offset(1,0.5),
      Offset(2,0.5),
    ],
    this.color = defaultColor, // Color por defecto
  });
  @override
  Widget build(BuildContext context) {
    // Usamos un Container como base para nuestro componente.
    // Es como una caja (<div> en web) que podemos decorar.
    final Color backgroundColor = isActive ? color : color.withAlpha(30);
    final Color textColor = isActive ? Colors.black : Colors.black.withAlpha(30);

    return Container(
      width: 30,  // Ancho de la caja
      height: 120, // Alto de la caja
      // La decoración nos permite añadir color, bordes, sombras, etc.
      decoration: BoxDecoration(
        color: backgroundColor, // Color de fondo grisáceo
        border: Border.all(         // Un borde negro
          color: textColor,
          width: 2,
        ),
      ),
      // El 'child' es lo que va DENTRO del Container.
      child:  Center( // Centra el texto en la caja
        child: Text(
          'PC',
          style: TextStyle(
            color:textColor,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}