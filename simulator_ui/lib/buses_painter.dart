import 'package:flutter/material.dart';
import 'package:namer_app/tooltip_widgets.dart';
import 'dart:math';
import 'dart:ui' as ui;
import 'datapath_state.dart';

class BusesPainter extends CustomPainter {
  final DatapathState datapathState;

  BusesPainter(this.datapathState);

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Obtiene el mapa de puntos de conexión desde el estado.
    final pointsMap = datapathState.connectionPoints;

    // 2. Dibuja las etiquetas de cada punto para depuración.
    if (datapathState.showConnectionLabels) {
      _drawConnectionPointLabels(canvas, pointsMap.values.toList());
    }
    _drawBusesAndValues(canvas, pointsMap);
  }

  /// Dibuja todos los buses y sus valores si están activos.
  void _drawBusesAndValues(Canvas canvas, Map<String, ConnectionPoint> pointsMap) {
    // 1. Preparamos la lista que guardará la información de cada TRAMO de bus visible.
    final List<BusHoverInfo> busHoverInfoList = [];

    final paint = Paint()
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    for (final bus in datapathState.buses) {
      // Si el bus está oculto, lo ignoramos por completo.
      if (bus.isHidden(datapathState)) continue;

      // Si "Show Control" está desactivado, ocultamos los buses de control/estado,
      // A MENOS QUE sea un bus de forwarding y "Show Forwarding" esté activado.
      final bool shouldHideControl = !datapathState.showControl && (bus.isControl || bus.isState);
        final bool isForwardingException = bus.isForwardingBus && datapathState.showForwarding;
        final bool isLHUException = bus.isLoadHazardBus && datapathState.showLHU;
        final bool isBHUException = bus.isBranchHazardBus && datapathState.showBHU;
      if (shouldHideControl && !(isForwardingException ||isLHUException||isBHUException) ) continue;

      // )
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

      // --- Lógica de color actualizada ---
      if (bus.color != null) {
        // Si el bus tiene un color personalizado, lo usamos.
        paint.color = isActive ? bus.color! : bus.color!.withAlpha(80);
        paint.strokeWidth = width.toDouble();
      } else if (isControl) {
        paint.strokeWidth = 1.5;
        paint.color = isActive ? const Color.fromARGB(255, 0, 0, 255) : const Color.fromARGB(100, 0, 0, 255);
      } else if (isState) {
        paint.strokeWidth = 1.5;
        paint.color = isActive ? const Color.fromARGB(255, 73, 240, 79) : const Color.fromARGB(255, 176, 241, 188);
      } else {
        // Lógica por defecto para buses de datos.
        paint.strokeWidth = width.toDouble();
        paint.color = isActive ? const Color.fromARGB(255, 255, 0, 0) : const Color.fromARGB(100, 255, 0, 0);
      }

      // --- LÓGICA MODIFICADA: DIBUJAR Y GUARDAR POR TRAMOS ---

      // Obtenemos los waypoints. Si hay un builder, lo ejecutamos AHORA.
      final dynamicWaypoints = bus.waypointsBuilder?.call(datapathState) ?? [];

      // Construimos la lista completa de puntos del bus.
      // Combinamos los waypoints fijos y los dinámicos.
      final allBusPoints = [startPoint.position, ...bus.waypoints, ...dynamicWaypoints, endPoint.position];

      // Generamos el texto del tooltip una sola vez por bus.
      String tooltipText;
      final value = datapathState.busValues[bus.valueKey];
      if (bus.isControl && bus.valueKey != null) {
        // Lógica para tooltips de buses de control
        // Generamos un identificador especial para que el widget del tooltip sepa cómo dibujarlo.
        tooltipText = '##CONTROL_BUS:${bus.valueKey}';
        //Definido en buildControlBusTooltip
      } else if (bus.isState) {
        // Lógica para tooltips de buses de estado
        tooltipText = '${bus.valueKey} (${bus.size} bits)\nValue: ${value != null ? value.toRadixString(2).padLeft(bus.size, '0') : 'N/A'}';
      }
      else if (bus.valueKey != null) {
        // Lógica para buses de datos
        tooltipText = '${bus.valueKey} (${bus.size} bits)\nValue: ${value != null ? '0x${value.toRadixString(16).toUpperCase()}' : 'N/A'}';
      }
      else {
        // Fallback
        tooltipText = 'Control/State Bus';
      }
      
      // Iteramos por cada segmento (tramo) del bus.
      for (int i = 0; i < allBusPoints.length - 1; i++) {
        final p1 = allBusPoints[i];
        final p2 = allBusPoints[i + 1];

        // Creamos un path solo para este segmento.
        final segmentPath = Path()
          ..moveTo(p1.dx, p1.dy)
          ..lineTo(p2.dx, p2.dy);

        // Dibujamos el segmento.
        if (isControl || isState) {
          _drawDashedPath(canvas, segmentPath, paint, [5, 5]);
        } else {
          canvas.drawPath(segmentPath, paint);
        }

        // Guardamos la información de hover para este segmento.
        busHoverInfoList.add(BusHoverInfo(
          path: segmentPath,
          bounds: segmentPath.getBounds().inflate(width.toDouble() + 1),
          tooltip: tooltipText,
          strokeWidth: width.toDouble(),
        ));

        // Dibujamos la flecha solo en el último segmento del bus.
        if (i == allBusPoints.length - 2) {
          _drawArrowHead(canvas, p1, p2, paint);
        }
      }

      // El valor del bus se sigue dibujando una vez, si está activo.
      if (isActive && bus.valueKey != null && datapathState.busValues[bus.valueKey] != null && datapathState.showBusesLabels) {
        // Dibuja el valor del bus en el canvas.
      _drawBusValue(canvas, allBusPoints, bus, datapathState.busValues[bus.valueKey]!);
      }
    }
    datapathState.setBusHoverInfoList(busHoverInfoList);
    }
//    datapathState.setBusHoverInfoList(busHoverInfoList);
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
    for (final ui.PathMetric metric in metrics) {
      for (double dist = 0; dist < metric.length;) {
        canvas.drawPath(metric.extractPath(dist, dist + dashArray[0]), paint);
        dist += dashArray[0] + dashArray[1];
      }
    }
  }

  /// Dibuja el valor de un bus en el canvas.
  void _drawBusValue(Canvas canvas, List<Offset> allBusPoints, Bus bus, int value) {
    // 1. Calcular la posición para el texto.
    // Usaremos el punto medio del segmento "central" del bus.
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
    String valueText;
    if (bus.isControl || bus.isState) {
      // Para buses de control y estado, mostrar el valor binario con padding.
      valueText = value.toRadixString(2).padLeft(bus.size, '0');
      if(valueText.length > 5) {
        // Si es muy largo, lo cortamos y añadimos "..."
        valueText = '0x${value.toRadixString(16).padLeft(4, '0')}';
      } 

    } else {
      valueText = '0x${value.toRadixString(16).toUpperCase()}';
      if(valueText=='0xDEADBEEF'){
        valueText='??'; // Evitamos mostrar valores basura.
      }
    }

    // 3. Configurar el TextPainter para dibujar el texto.
    final textStyle = TextStyle(
      color: Colors.blue.shade900,
      fontSize: 11,
      backgroundColor: const Color.fromARGB(210, 227, 242, 253), // Fondo azul claro semitransparente
      fontWeight: FontWeight.bold,
      fontFamily: 'monospace',
    );
    final textStyle2=miEstiloTooltip.copyWith(color: Colors.black);
    final textSpan = TextSpan(text: valueText, style: textStyle2);
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
    if(valueText!='')canvas.drawRRect(backgroundRect, backgroundPaint);
    if(valueText!='')textPainter.paint(canvas, textOffset);
  }

  /// Dibuja las etiquetas de una lista de `ConnectionPoint` en el canvas.
  /// Es una función de ayuda para depurar la posición de los puntos.
  void _drawConnectionPointLabels(Canvas canvas, List<ConnectionPoint> points) {
    final textStyle = TextStyle(
      color: Colors.deepPurple,
      fontSize: 7,
      backgroundColor: Colors.white.withAlpha(20),
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
  bool shouldRepaint(covariant BusesPainter oldDelegate) {
    // Se redibuja si el estado cambia, lo que es ideal para la simulación.
    return true;
  }
  }