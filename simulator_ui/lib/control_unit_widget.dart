import 'dart:math';

import 'package:flutter/material.dart';

class ControlUnitWidget extends StatelessWidget {
  final List<Offset> connectionPoints;
    final bool isActive; // Para recibir si debe estar "activo" (color verde)

  const ControlUnitWidget({super.key,
  
  this.connectionPoints=const [
    Offset(0, 0.8),

    Offset(0.2, 1),
    Offset(0.26, 1),
    Offset(0.32, 1),
    Offset(0.37, 1),
    Offset(0.557, 1),
    Offset(0.66, 1),
    Offset(0.725, 1),
    Offset(0.82, 1),
    Offset(0.975, 1),

    
    Offset(1, 0.8)
  ],
      this.isActive = false, // Por defecto no está activo

  });  

  @override
  Widget build(BuildContext context) {
        final Color backgroundColor = isActive ? Colors.orange.shade100 : Colors.orange.shade100.withAlpha(15);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(
          color: Colors.black,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Text(
          'Control Unit',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}