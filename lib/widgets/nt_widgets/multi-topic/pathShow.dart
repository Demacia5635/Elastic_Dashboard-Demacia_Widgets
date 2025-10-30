import 'package:flutter/material.dart';

class Pathshow extends CustomPainter {
  final List<O  ffset> pathPoints;
  final Offset? currentMousePoint;
  final double metersToPixels;
  final double scaleReduction;

  Pathshow({
    required this.pathPoints,
    required this.currentMousePoint,
    required this.metersToPixels,
    required this.scaleReduction,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final pointPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;

    final previewLinePaint = Paint()
      ..color = Colors.blue.withOpacity(0.5)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < pathPoints.length - 1; i++) {
      Offset start = Offset(
        pathPoints[i].dx * metersToPixels * scaleReduction,
        pathPoints[i].dy * metersToPixels * scaleReduction,
      );
      Offset end = Offset(
        pathPoints[i + 1].dx * metersToPixels * scaleReduction,
        pathPoints[i + 1].dy * metersToPixels * scaleReduction,
      );
      canvas.drawLine(start, end, linePaint);
    }

    for (int i = 1; i < pathPoints.length; i++) {
      Offset pixelPoint = Offset(
        pathPoints[i].dx * metersToPixels * scaleReduction,
        pathPoints[i].dy * metersToPixels * scaleReduction,
      );
      canvas.drawCircle(pixelPoint, 8, pointPaint);
    }

    if (pathPoints.isNotEmpty && currentMousePoint != null) {
      Offset lastPoint = Offset(
        pathPoints.last.dx * metersToPixels * scaleReduction,
        pathPoints.last.dy * metersToPixels * scaleReduction,
      );
      canvas.drawLine(lastPoint, currentMousePoint!, previewLinePaint);

      final tempPointPaint = Paint()
        ..color = Colors.blue.withOpacity(0.5)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(currentMousePoint!, 6, tempPointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant Pathshow oldDelegate) {
    return oldDelegate.pathPoints != pathPoints ||
        oldDelegate.currentMousePoint != currentMousePoint;
  }
}
