
import 'package:flutter/material.dart';

class ControlUnitWidget extends StatelessWidget {
  final List<Offset> connectionPoints;
    final bool isActive; // Para recibir si debe estar "activo" (color verde)

  const ControlUnitWidget({super.key,
  
  this.connectionPoints=const [
    Offset(0.1, 1),

    Offset(0.191, 1),
    Offset(0.266, 1),
    Offset(0.317, 1),
    Offset(0.36, 1),
    Offset(0.556, 1),
    Offset(0.631, 1),
    Offset(0.7243, 1),
    Offset(0.8084, 1),
    Offset(0.9735, 1),

    
    Offset(1, 0.85)
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