import 'package:flutter/material.dart';
import 'dart:math';
import 'datapath_state.dart';

/// Un punto de conexión con una etiqueta y una posición global.
class ConnectionPoint {
  final String label;
  final Offset position; // Posición local relativa al área del painter (el Stack)
  ConnectionPoint(this.label, this.position);
}

class BusesPainter extends CustomPainter {
  final DatapathState datapathState;

  BusesPainter(this.datapathState);

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Obtiene todos los puntos de conexión con sus coordenadas globales.
    final allPoints = _getAllConnectionPoints();
    final pointsMap = {for (var p in allPoints) p.label: p};

    // 2. Dibuja las etiquetas de cada punto para depuración.
    _drawConnectionPointLabels(canvas, allPoints); // Comentado para limpiar la vista
    _drawBuses(canvas, pointsMap);
  }

  /// Recopila todos los `connectionPoints` de los widgets del datapath y los
  /// convierte en una lista de puntos con coordenadas globales y etiquetas.
  List<ConnectionPoint> _getAllConnectionPoints() {
    final List<ConnectionPoint> allPoints = [];

    // Obtenemos el RenderBox del Stack para poder convertir coordenadas
    // globales (de pantalla) a locales (relativas al Stack).
    final stackContext = datapathState.stackKey.currentContext;
    if (stackContext == null) return [];
    final stackBox = stackContext.findRenderObject() as RenderBox;

    // Helper para no repetir código.
    void extractPoints(GlobalKey key, String labelPrefix) {
      final context = key.currentContext;
      final widget = key.currentWidget;
      if (context == null || widget == null) return;

      final box = context.findRenderObject() as RenderBox;
      // 1. Obtenemos la posición global del widget (relativa a la pantalla).
      final globalPosition = box.localToGlobal(Offset.zero);
      // 2. La convertimos a una posición local (relativa a nuestro Stack).
      final localPosition = stackBox.globalToLocal(globalPosition);
      final size = box.size;

      // Usamos 'dynamic' para acceder a 'connectionPoints' sin tener que
      // hacer un cast para cada tipo de widget.
      final List<Offset> relativePoints = (widget as dynamic).connectionPoints;

      for (int i = 0; i < relativePoints.length; i++) {
        final relativePoint = relativePoints[i];
        // Calcula el punto de conexión final sumando el offset relativo a la posición local del widget.
        final finalPoint = localPosition +
            Offset(relativePoint.dx * size.width, relativePoint.dy * size.height);
        allPoints.add(ConnectionPoint('$labelPrefix-$i', finalPoint));
      }
    }

    // Extraemos los puntos de cada componente.
    extractPoints(datapathState.pcKey, 'PC');
    extractPoints(datapathState.pcAdderKey, 'NPC');
    extractPoints(datapathState.branchAdderKey, 'BR');
    extractPoints(datapathState.aluKey, 'ALU');
    extractPoints(datapathState.mux1Key, 'M1');
    extractPoints(datapathState.mux2Key, 'M2');
    extractPoints(datapathState.mux3Key, 'M3');
    extractPoints(datapathState.instructionMemoryKey, 'IM');
    extractPoints(datapathState.dataMemoryKey, 'DM');
    extractPoints(datapathState.registerFileKey, 'RF');
    extractPoints(datapathState.controlUnitKey, 'CU');
    extractPoints(datapathState.extenderKey, 'EXT');
    extractPoints(datapathState.ibKey, 'IB');

    return allPoints;
  }

  /// Dibuja todos los buses definidos en el DatapathState.
  void _drawBuses(Canvas canvas, Map<String, ConnectionPoint> pointsMap) {
    final paint = Paint()
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    for (final bus in datapathState.buses) {
      final startPoint = pointsMap[bus.startPointLabel];
      final endPoint = pointsMap[bus.endPointLabel];
      final width = bus.width;


      // Si algún punto no existe, no podemos dibujar este bus.
      if (startPoint == null || endPoint == null) {
        // Opcional: imprimir un aviso para depuración.
        // print('Advertencia: No se encontró el punto para el bus ${bus.startPointLabel} -> ${bus.endPointLabel}');
        continue;
      }

      final isActive = bus.isActive(datapathState);
      final isControl = bus.isControl;
      final isState = bus.isState;


      // Cambiamos el color y el grosor del bus si está activo.
      paint.color = isActive ? const Color.fromARGB(255, 255, 0, 0) : const Color.fromARGB(100, 255, 0, 0);
      paint.strokeWidth = isActive ? 3.5 : 2.0;
      paint.strokeWidth = width.toDouble();
      if (isControl) {
        paint.strokeWidth = 1.5;
        paint.color = isActive ? const Color.fromARGB(255, 0, 0, 255) : const Color.fromARGB(100, 0, 0, 255);
      }
      if (isState) {
        paint.strokeWidth = 1.5;
        paint.color = isActive ? const Color.fromARGB(255, 73, 240, 79) : const Color.fromARGB(255, 176, 241, 188);
      }

      // Creamos el path (camino) del bus.
      final path = Path();
      path.moveTo(startPoint.position.dx, startPoint.position.dy);

      // Añadimos los puntos intermedios si existen.
      for (final waypoint in bus.waypoints) {
        path.lineTo(waypoint.dx, waypoint.dy);
      }

      path.lineTo(endPoint.position.dx, endPoint.position.dy);

      Offset prevPoint;
      if (bus.waypoints.isNotEmpty) {
        prevPoint = bus.waypoints.last;
      } else {
        prevPoint = startPoint.position;
      }


      if (isControl || isState) {
        // Dibuja el path con líneas discontinuas.
        _drawDashedPath(canvas, path, paint, [5, 5]); // Patrón: 5px de línea, 5px de espacio

        // Determina el punto previo al final para calcular la dirección de la flecha.
        _drawArrowHead(canvas, prevPoint, endPoint.position, paint);
      } else {
        canvas.drawPath(path, paint);
        _drawArrowHead(canvas, prevPoint, endPoint.position, paint);

      }
    }
  }

  /// Dibuja una flecha al final de un segmento de línea.
  void _drawArrowHead(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    final arrowPaint = Paint()
      ..color = paint.color
      ..style = PaintingStyle.fill;

    const arrowSize = 10.0;
    const arrowAngle = 25 * pi / 180;

    final angle = (p2 - p1).direction;

    final path = Path();
    path.moveTo(p2.dx - arrowSize * cos(angle - arrowAngle), p2.dy - arrowSize * sin(angle - arrowAngle));
    path.lineTo(p2.dx, p2.dy);
    path.lineTo(p2.dx - arrowSize * cos(angle + arrowAngle), p2.dy - arrowSize * sin(angle + arrowAngle));
    path.close();
    canvas.drawPath(path, arrowPaint);
  }

  /// Dibuja un `Path` con un patrón de líneas discontinuas.
  void _drawDashedPath(Canvas canvas, Path path, Paint paint, List<double> dashArray) {
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      for (double dist = 0; dist < metric.length;) {
        canvas.drawPath(metric.extractPath(dist, dist + dashArray[0]), paint);
        dist += dashArray[0] + dashArray[1];
      }
    }
  }

  /// Dibuja las etiquetas de una lista de `ConnectionPoint` en el canvas.
  /// Es una función de ayuda para depurar la posición de los puntos.
  void _drawConnectionPointLabels(Canvas canvas, List<ConnectionPoint> points) {
    final textStyle = TextStyle(
      color: Colors.deepPurple,
      fontSize: 7,
      backgroundColor: Colors.white.withOpacity(0.6),
      fontWeight: FontWeight.bold,
    );

    for (final point in points) {
      final textSpan = TextSpan(text: point.label, style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      // Dibuja el texto centrado en el punto de conexión.
      textPainter.paint(canvas, point.position - Offset(textPainter.width / 2, textPainter.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    // Se redibuja si el estado cambia, lo que es ideal para la simulación.
    return true;
  }
}