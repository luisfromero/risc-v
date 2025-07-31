import 'package:flutter/material.dart';

class PcWidget extends StatelessWidget {
  // Constructor del widget. La 'key' es para que Flutter identifique el widget.
  const PcWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // Usamos un Container como base para nuestro componente.
    // Es como una caja (<div> en web) que podemos decorar.
    return Container(
      width: 50,  // Ancho de la caja
      height: 120, // Alto de la caja
      // La decoración nos permite añadir color, bordes, sombras, etc.
      decoration: BoxDecoration(
        color: Colors.blueGrey[100], // Color de fondo grisáceo
        border: Border.all(         // Un borde negro
          color: Colors.black,
          width: 2,
        ),
      ),
      // El 'child' es lo que va DENTRO del Container.
      child: const Center( // Centra el texto en la caja
        child: Text(
          'PC',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}