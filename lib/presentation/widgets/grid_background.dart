import 'package:flutter/material.dart';

class GridBackground extends StatelessWidget {
  final Widget child;
  final double gridSize;
  final Color gridColor;

  const GridBackground({
    super.key,
    required this.child,
    this.gridSize = 20.0,
    this.gridColor = const Color(0xFFE5E5E5),
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CustomPaint(
          size: Size.infinite,
          painter: GridPainter(
            gridSize: gridSize,
            gridColor: gridColor,
          ),
        ),
        child,
      ],
    );
  }
}

class GridPainter extends CustomPainter {
  final double gridSize;
  final Color gridColor;

  GridPainter({
    required this.gridSize,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    // 縦線を描画
    for (double x = 0; x <= size.width; x += gridSize) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    // 横線を描画
    for (double y = 0; y <= size.height; y += gridSize) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is GridPainter &&
        (oldDelegate.gridSize != gridSize ||
            oldDelegate.gridColor != gridColor);
  }
}