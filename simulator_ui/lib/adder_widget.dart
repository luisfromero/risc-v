import 'package:flutter/material.dart';

class AdderWidget extends StatelessWidget {
  final String label;
  final bool isActive; // Para recibir si debe estar "activo" (color verde)
  final List<Offset> connectionPoints;

  const AdderWidget({
    super.key,
    required this.label,
    this.isActive = false, // Por defecto no está activo
    // Por defecto, 3 puntos: dos entradas a la izquierda/abajo y una salida a la derecha.
    this.connectionPoints = const [
      Offset(0,0.25),
      Offset(0,0.75),
      Offset(1,0.5),
    ],
  });

  @override
  Widget build(BuildContext context) {
    // El color dependerá de si el widget está activo o no.
    final Color backgroundColor = isActive ? Colors.green.shade200 : Colors.green.shade200.withAlpha(30);
    final Color textColor = isActive ? Colors.black : Colors.black.withAlpha(30);

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
            painter: _AdderPainter(color: backgroundColor, borderColor: textColor),
          ),
          // El símbolo '+' centrado
          Padding(
            padding:  EdgeInsets.only(left: 15),
            child: Text(
              label,
              
              style:  TextStyle(
                color:textColor,
                fontSize: 12, fontWeight: 
                FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

// Esta es la clase que realmente dibuja la forma del sumador.
class _AdderPainter extends CustomPainter {
  final Color color;
  final Color borderColor;
  _AdderPainter({required this.color, required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color // Usa el color que le pasamos
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Creamos la ruta (el path) de nuestro trapecio
    final path = Path();
    path.moveTo(size.width * 0, 0); // Punto inicial superior-izquierda
    path.lineTo(size.width * 1, size.height * 0.25); // Línea a superior-derecha
    path.lineTo(size.width * 1, size.height * 0.75); // Línea a superior-derecha
    path.lineTo(size.width * 0, size.height); // Punto inicial superior-izquierda
    path.lineTo(size.width * 0, 0.6*size.height); // Punto inicial superior-izquierda
    path.lineTo(size.width * 0.3, 0.5*size.height); // Punto inicial superior-izquierda
    path.lineTo(size.width * 0, 0.4*size.height); // Punto inicial superior-izquierda
    path.lineTo(size.width*0, 0); // Línea a inferior-derecha
    path.close(); // Cierra la forma

    canvas.drawPath(path, paint); // Dibuja el relleno
    canvas.drawPath(path, borderPaint); // Dibuja el borde
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}