import 'package:flutter/material.dart';

class MemoryUnitWidget extends StatelessWidget {
  final String label;
  final double width;
  final double height;
  final List<Offset> connectionPoints;
  final bool isActive; // Para recibir si debe estar "activo" (color verde)

  const MemoryUnitWidget({
    super.key,
    required this.label,
    this.isActive = false, // Por defecto no está activo
    this.width = 100,
    this.height = 120,
    this.connectionPoints=const [],
  });

  @override
  Widget build(BuildContext context) {
    final Color backgroundColor = isActive ? Colors.green.shade200 : Colors.green.shade200.withAlpha(30);
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
