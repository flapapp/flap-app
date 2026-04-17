import 'package:flutter/material.dart';

/// Simple rating sparkline (presentation widget).
class SparklinePainter extends CustomPainter {
  SparklinePainter(this.points);

  final List<double> points;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF4caf50)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    if (points.isEmpty) return;
    final path = Path();
    final maxVal = points.reduce((a, b) => a > b ? a : b);
    final minVal = points.reduce((a, b) => a < b ? a : b);
    final range = (maxVal - minVal).abs() < 1e-6 ? 1.0 : (maxVal - minVal);
    for (var i = 0; i < points.length; i++) {
      final x = points.length == 1 ? 0.0 : (i / (points.length - 1)) * size.width;
      final y = size.height - ((points[i] - minVal) / range) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
