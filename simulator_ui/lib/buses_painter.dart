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
    if (datapathState.showConnectionLabels) {
      _drawConnectionPointLabels(canvas, allPoints);
    }
    _drawBusesAndValues(canvas, pointsMap);
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
    extractPoints(datapathState.muxCKey, 'M1');
    extractPoints(datapathState.mux2Key, 'M2');
    extractPoints(datapathState.mux3Key, 'M3');
    extractPoints(datapathState.instructionMemoryKey, 'IM');
    extractPoints(datapathState.dataMemoryKey, 'DM');
    extractPoints(datapathState.registerFileKey, 'RF');
    extractPoints(datapathState.controlUnitKey, 'CU');
    extractPoints(datapathState.extenderKey, 'EXT');
    extractPoints(datapathState.ibKey, 'IB');
    
    //Pipeline Registers
    extractPoints(datapathState.pipereg_fd0_Key, 'FD0');//Fetch decode
    extractPoints(datapathState.pipereg_fd1_Key, 'FD1');//Fetch decode
    extractPoints(datapathState.pipereg_de0_Key, 'DE0');//Fetch decode
    extractPoints(datapathState.pipereg_em0_Key, 'EM0');//Fetch decode
    extractPoints(datapathState.pipereg_em1_Key, 'EM1');//Fetch decode
    extractPoints(datapathState.pipereg_mw0_Key, 'MW0');//Fetch decode
    extractPoints(datapathState.pipereg_mw1_Key, 'MW1');//Fetch decode
    extractPoints(datapathState.pipereg_de1_Key, 'DE1');//Decode execute


    return allPoints;
  }

  /// Dibuja todos los buses y sus valores si están activos.
  void _drawBusesAndValues(Canvas canvas, Map<String, ConnectionPoint> pointsMap) {
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

        // Dibuja el valor del bus si está activo y tiene una clave de valor.
        if (isActive && bus.valueKey != null) {
          final busValue = datapathState.busValues[bus.valueKey];
          if (busValue != null) {
            _drawBusValue(canvas, bus, pointsMap, busValue);
          }
        }
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

  /// Dibuja el valor de un bus en el canvas.
  void _drawBusValue(Canvas canvas, Bus bus, Map<String, ConnectionPoint> pointsMap, int value) {
    final startPoint = pointsMap[bus.startPointLabel];
    final endPoint = pointsMap[bus.endPointLabel];
    if (startPoint == null || endPoint == null) {
      return;
    }

    // 1. Calcular la posición para el texto.
    // Usaremos el punto medio del segmento "central" del bus.
    final allBusPoints = [startPoint.position, ...bus.waypoints, endPoint.position];
    Offset textPosition;

    if (allBusPoints.length < 2) return; // No se puede dibujar en un punto.

    if (allBusPoints.length == 2) {
      // Línea simple, usamos el punto medio.
      textPosition = (allBusPoints[0] + allBusPoints[1]) / 2.0;
    } else {
      // Bus con waypoints, usamos el punto medio del segmento central.
      final midIndex = (allBusPoints.length / 2).floor();
      textPosition = (allBusPoints[midIndex - 1] + allBusPoints[midIndex]) / 2.0;
    }

    // 2. Formatear el texto del valor.
    final valueText = '0x${value.toRadixString(16)}';

    // 3. Configurar el TextPainter para dibujar el texto.
    final textStyle = TextStyle(
      color: Colors.blue.shade900,
      fontSize: 11,
      backgroundColor: const Color.fromARGB(210, 227, 242, 253), // Fondo azul claro semitransparente
      fontWeight: FontWeight.bold,
      fontFamily: 'monospace',
    );
    final textSpan = TextSpan(text: valueText, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    // 4. Dibujar el texto centrado en la posición calculada.
    final textOffset = textPosition - Offset(textPainter.width / 2, textPainter.height / 2);

    // Dibujamos un fondo redondeado para que el texto sea más legible.
    final backgroundRect = RRect.fromLTRBAndCorners(textOffset.dx - 3, textOffset.dy - 2, textOffset.dx + textPainter.width + 3, textOffset.dy + textPainter.height + 2, topLeft: const Radius.circular(4), topRight: const Radius.circular(4), bottomLeft: const Radius.circular(4), bottomRight: const Radius.circular(4));
    final backgroundPaint = Paint()..color = textStyle.backgroundColor!;
    canvas.drawRRect(backgroundRect, backgroundPaint);
    textPainter.paint(canvas, textOffset);
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