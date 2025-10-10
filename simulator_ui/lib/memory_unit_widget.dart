import 'package:flutter/material.dart';
import 'package:namer_app/geometry.dart';
import 'colors.dart';

class MemoryUnitWidget extends StatelessWidget {
  final String label;
  final double width;
  final double height;
  final List<Offset> connectionPoints;
  final bool isActive; // Para recibir si debe estar "activo" (color verde)
  final Color color; // Color por defecto

  const MemoryUnitWidget({
    super.key,
    required this.label,
    this.isActive = false, // Por defecto no está activo
    this.width = widthMems,
    this.height = heightMems,
    this.connectionPoints=const [],
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
          style: TextStyle(
            fontSize: 14,
            color: textColor,
            fontWeight: FontWeight.bold,
            height: 1.2, // Altura de línea para texto de 2 líneas
          ),
        ),
      ),
    );
  }
}
