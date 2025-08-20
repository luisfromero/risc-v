import 'package:flutter/material.dart';
import 'colors.dart';

class ExtenderWidget extends StatelessWidget {
  final String label;
  final bool isActive; // Para recibir si debe estar "activo" (color verde)

  final double width;
  final double height;
  final List<Offset> connectionPoints;
  final Color color; // Color por defecto

  const ExtenderWidget({
    super.key,
    required this.label,
        this.isActive = false, // Por defecto no está activo

    this.width = 100,
    this.height = 40,
    this.connectionPoints = const [
      Offset(0, 0.5),
      Offset(0.5, 1),
      Offset(1, 0.5),
      Offset(2, 0.5),
    ],
    this.color = defaultColor, // Color por defecto
  });

  @override
  Widget build(BuildContext context) {
    final Color backgroundColor = isActive ? color : color.withAlpha(30);
    final Color textColor = isActive ? Colors.black : Colors.black.withAlpha(30);

    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(2.0), // Padding para el texto
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(
          color: textColor,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Center(
        child: Text(
          label,
          textAlign: TextAlign.center,
          style:  TextStyle(
            color: textColor,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            height: 1.2, // Altura de línea para texto de 2 líneas
          ),
        ),
      ),
    );
  }
}

