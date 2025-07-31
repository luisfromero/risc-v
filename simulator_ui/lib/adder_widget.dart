import 'package:flutter/material.dart';

class AdderWidget extends StatelessWidget {
  final String label;
  final bool isActive; // Para recibir si debe estar "activo" (color verde)

  const AdderWidget({
    super.key,
    required this.label,
    this.isActive = false, // Por defecto no está activo
  });

  @override
  Widget build(BuildContext context) {
    // El color dependerá de si el widget está activo o no.
    final Color backgroundColor = isActive ? Colors.green.shade200 : Colors.blueGrey.shade100;

    return SizedBox(
      width: 60,
      height: 120,
      // Stack nos permite apilar widgets. Dibujaremos la forma
      // y pondremos el texto '+' encima.
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Widget para dibujo personalizado
          CustomPaint(
            size: const Size(80, 120),
            painter: _AdderPainter(color: backgroundColor),
          ),
          // El símbolo '+' centrado
          Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
          ),
        ],
      ),
    );
  }
}

// Esta es la clase que realmente dibuja la forma del sumador.
class _AdderPainter extends CustomPainter {
  final Color color;
  _AdderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color // Usa el color que le pasamos
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Creamos la ruta (el path) de nuestro trapecio
    final path = Path();
    path.moveTo(size.width * 0.1, 0); // Punto inicial superior-izquierda
    path.lineTo(size.width * 0.9, size.height * 0.2); // Línea a superior-derecha
    path.lineTo(size.width * 0.9, size.height * 0.8); // Línea a superior-derecha
    path.lineTo(size.width * 0.1, size.height); // Punto inicial superior-izquierda
    path.lineTo(size.width * 0.1, 0.6*size.height); // Punto inicial superior-izquierda
    path.lineTo(size.width * 0.3, 0.5*size.height); // Punto inicial superior-izquierda
    path.lineTo(size.width * 0.1, 0.4*size.height); // Punto inicial superior-izquierda
    path.lineTo(size.width*0.1, 0); // Línea a inferior-derecha
    path.close(); // Cierra la forma

    canvas.drawPath(path, paint); // Dibuja el relleno
    canvas.drawPath(path, borderPaint); // Dibuja el borde
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}