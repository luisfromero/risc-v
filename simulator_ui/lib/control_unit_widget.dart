
import 'package:flutter/material.dart';
import 'geometry.dart';


class ControlUnitWidget extends StatelessWidget {
  final List<Offset> connectionPoints;
    final bool isActive; // Para recibir si debe estar "activo" (color verde)

  const ControlUnitWidget({super.key,


  this.connectionPoints=const [
    Offset(ucx1, 1),
    Offset(ucx2, 1),
    Offset(ucx3, 1),
    Offset(ucx4, 1),
    Offset(ucx5, 1),
    Offset(ucx6, 1),
    Offset(ucx7, 1),
    Offset(ucx8, 1),
    Offset(ucx9, 1),
    Offset(ucx10, 1),
    Offset(ucx11, 1)
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