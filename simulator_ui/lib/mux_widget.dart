import 'package:flutter/material.dart';
import 'package:namer_app/geometry.dart';
import 'colors.dart';

class MuxWidget extends StatelessWidget {
  final int value;
  final bool isActive; // Para recibir si debe estar "activo" (color verde)
  final List<Offset> connectionPoints;
  final List<String> labels;
  final color; // Color por defecto


  const MuxWidget({
    super.key,
    required this.value,
    this.isActive = false, // Por defecto no está activo
    this.labels = const ['0', '1', '2', '3'],
    // Por defecto, 3 puntos: dos entradas a la izquierda/abajo y una salida a la derecha.
    this.connectionPoints = const [
      Offset(0,0.1),
      Offset(0,0.35),
      Offset(0,0.6),
      Offset(0,0.85),
      Offset(0.35,0),
      Offset(1,0.5),
      Offset(1.4,0.5),],
    this.color = defaultColor, // Color por defecto
  });

  // Verificación para asegurar que la lista de etiquetas tenga 4 elementos.
  bool get _hasValidLabels => labels.length == 4;

  @override
  Widget build(BuildContext context) {
    // El color dependerá de si el widget está activo o no.
    final Color backgroundColor = isActive ? color : color.withAlpha(30);
    final Color textColor = isActive ? Colors.black : Colors.black.withAlpha(30);
  final TextStyle estilo= TextStyle(fontSize: 13,color:textColor);

    return SizedBox(
      width: widthMuxWB,
      height: heightMuxWB,
      
      // Stack nos permite apilar widgets. Dibujaremos la forma
      // y pondremos el texto '+' encima.
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Widget para dibujo personalizado
          CustomPaint(
            size: const Size(80, 120),
            painter: _MuxPainter(color: backgroundColor, borderColor: textColor),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: !_hasValidLabels
                ? const Icon(Icons.error, color: Colors.red)
                : Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: labels.map((label) => Text(label, style: estilo)).toList(),
                  ),
          ),

          Padding(
            padding: const EdgeInsets.only(left:15),
            child: Text(
              value.toString(),
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.normal,color: Colors.blue),
            ),
          ),
        ],
      ),
    );
  }
}

// Esta es la clase que realmente dibuja la forma del sumador.
class _MuxPainter extends CustomPainter {
  final Color color;
  final Color borderColor;
  _MuxPainter({required this.color, required this.borderColor});

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
    path.moveTo(size.width * 0.6, 0); // Punto inicial superior-izquierda
    path.lineTo(size.width * 1, size.height * 0.5); // Línea a superior-derecha
    path.lineTo(size.width * 0.6, size.height); // Punto inicial superior-izquierda
    path.lineTo(size.width * 0, size.height); // Punto inicial superior-izquierda
    path.lineTo(size.width * 0, 0); // Línea a inferior-derecha
    path.close(); // Cierra la forma

    canvas.drawPath(path, paint); // Dibuja el relleno
    canvas.drawPath(path, borderPaint); // Dibuja el borde
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}