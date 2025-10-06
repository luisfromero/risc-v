import 'package:flutter/material.dart';

const Color defaultColor = Color(0xFF81C784);
const Color color1 = Color(0xFF4CAF50);
const Color color2 = Color.fromARGB(255, 239, 245, 66);
const Color color3 = Color.fromRGBO(120, 113, 245, 1);   
const Color color4 = Color.fromARGB(255, 250, 101, 98);
const Color color5 = Color.fromARGB(255, 9, 227, 251);

/// Lista de colores para diferenciar instrucciones en el historial.
const List<Color> instructionColors = [
  Colors.blue,
  Colors.green,
  Colors.orange,
  Colors.purple,
  Colors.red,
  Colors.teal,
  Colors.pink,
  Colors.indigo,
];

Color pipelineColorForPC(int? pc) {
  // Ejemplo: elige entre 8 colores cíclicamente según el valor del PC
  if (pc == null) return Colors.transparent; // Si el PC es nulo, devolvemos un color transparente

  // Usamos la lista de colores definida arriba.
  return instructionColors[((pc) ~/ 4) % instructionColors.length];
}
