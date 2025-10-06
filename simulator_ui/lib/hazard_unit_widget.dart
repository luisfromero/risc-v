import 'package:flutter/material.dart';

class HazardUnitWidget extends StatelessWidget {
  final String label;
  final bool isActive;
  final Color activeColor;
  final List<Offset> connectionPoints;

  const HazardUnitWidget({
    super.key,
    required this.label,
    this.isActive = false,
    this.activeColor = Colors.red,
    this.connectionPoints = const [],
  });

  @override
  Widget build(BuildContext context) {
    // El widget será transparente si no está activo.
    final Color backgroundColor = isActive ? activeColor.withAlpha(80) : Colors.transparent;
    final Color textColor = isActive ? Colors.black : Colors.transparent;
    final Color borderColor = isActive ? activeColor : Colors.transparent;

    return Container(
      width: 100,
      height: 50,
      padding: const EdgeInsets.all(4.0),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(
          color: borderColor,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
