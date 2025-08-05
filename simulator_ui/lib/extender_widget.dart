import 'package:flutter/material.dart';

class ExtenderWidget extends StatelessWidget {
  final String label;
  final double width;
  final double height;
  final List<Offset> connectionPoints;

  const ExtenderWidget({
    super.key,
    required this.label,
    this.width = 100,
    this.height = 40,
    this.connectionPoints = const [
      Offset(0, 0.5),
      Offset(0.5, 1),
      Offset(1, 0.5),
      Offset(2, 0.5),
    ],

  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(2.0), // Padding para el texto
      decoration: BoxDecoration(
        color: Colors.blueGrey[100],
        border: Border.all(
          color: Colors.black,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Center(
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            height: 1.2, // Altura de línea para texto de 2 líneas
          ),
        ),
      ),
    );
  }
}

