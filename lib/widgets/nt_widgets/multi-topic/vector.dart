import 'dart:math';

import 'package:dot_cast/dot_cast.dart';
import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class VectorModel extends MultiTopicNTWidgetModel {
  @override
  String type = Vector.widgetType;

  late NT4Subscription vectorsSubscription;
  late NT4Subscription startingPointsSubscription;

  VectorModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    super.period,
    super.dataType,
  }) : super();

  VectorModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required super.jsonData,
  }) : super.fromJson();

  @override
  void init() {
    super.init();

    vectorsSubscription =
        ntConnection.subscribe('$topic/Vectors', super.period);
    startingPointsSubscription =
        ntConnection.subscribe('$topic/StartingPoints', super.period);

    vectorsSubscription.listen((value, timestamp) {
      notifyListeners();
    });

    startingPointsSubscription.listen((value, timestamp) {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  List<VectorData> getVectors() {
    List<VectorData> vectors = [];

    var vectorsValue = vectorsSubscription.value;
    var startingPointsValue = startingPointsSubscription.value;

    if (vectorsValue == null || vectorsValue is! List) {
      return vectors;
    }

    List<double> vectorsList = [];
    for (var v in vectorsValue) {
      if (v is num) {
        vectorsList.add(v.toDouble());
      }
    }

    List<double> startingPointsList = [];
    if (startingPointsValue != null && startingPointsValue is List) {
      for (var v in startingPointsValue) {
        if (v is num) {
          startingPointsList.add(v.toDouble());
        }
      }
    }

    // המערך מכיל זוגות של (magnitude, angle) לכל וקטור
    if (vectorsList.length % 2 != 0) {
      return vectors;
    }

    int vectorCount = vectorsList.length ~/ 2;

    for (int i = 0; i < vectorCount; i++) {
      double magnitude = vectorsList[i * 2];
      double angleDegrees = vectorsList[i * 2 + 1];

      double startX = 0.0;
      double startY = 0.0;

      if (startingPointsList.length >= (i + 1) * 2) {
        startX = startingPointsList[i * 2];
        startY = startingPointsList[i * 2 + 1];
      }

      vectors.add(VectorData(
        magnitude: magnitude,
        angleDegrees: angleDegrees,
        startX: startX,
        startY: startY,
        color: _getColorForIndex(i),
        index: i,
      ));
    }

    return vectors;
  }

  Color _getColorForIndex(int index) {
    final colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.cyan,
      Colors.pink,
      Colors.amber,
    ];
    return colors[index % colors.length];
  }
}

class Vector extends NTWidget {
  static const String widgetType = 'Vector Display';

  const Vector({super.key}) : super();

  @override
  Widget build(BuildContext context) {
    VectorModel model = cast(context.watch<NTWidgetModel>());

    return LayoutBuilder(
      builder: (context, constraints) {
        List<VectorData> vectors = model.getVectors();

        if (vectors.isEmpty) {
          return Center(
            child: Text(
              'No vectors available',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Wrap(
                spacing: 10,
                runSpacing: 5,
                children: [
                  for (var vector in vectors)
                    Text(
                      'V${vector.index}: ${vector.magnitude.toStringAsFixed(2)}∠${vector.angleDegrees.toStringAsFixed(1)}° @ (${vector.startX.toStringAsFixed(2)}, ${vector.startY.toStringAsFixed(2)})',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: vector.color,
                          ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: CustomPaint(
                painter: VectorPainter(
                  vectors: vectors,
                  arrowSize: 15.0,
                ),
                child: Container(),
              ),
            ),
          ],
        );
      },
    );
  }
}

class VectorData {
  final double magnitude;
  final double angleDegrees;
  final double startX;
  final double startY;
  final Color color;
  final int index;

  VectorData({
    required this.magnitude,
    required this.angleDegrees,
    required this.startX,
    required this.startY,
    required this.color,
    required this.index,
  });

  // המרה לרדיאנים
  double get angleRadians => angleDegrees * pi / 180.0;

  // חישוב X,Y מהגודל והזווית
  // זווית 0° = ימינה, 90° = למעלה, -90° = למטה, 180° = שמאלה
  double get x => magnitude * cos(angleRadians);
  double get y => magnitude * sin(angleRadians);
}

class VectorPainter extends CustomPainter {
  final List<VectorData> vectors;
  final double arrowSize;

  VectorPainter({
    required this.vectors,
    required this.arrowSize,
  });

  double _calculateScale(double maxValue) {
    if (maxValue == 0) return 1.0;

    if (maxValue < 1.0) {
      double scale = 1.0;
      while (scale / 2 > maxValue) {
        scale /= 2;
      }
      return scale;
    }

    double powerOf10 = pow(10, (log(maxValue) / ln10).ceil()).toDouble();
    return powerOf10;
  }

  @override
  void paint(Canvas canvas, Size size) {
    // מציאת הגודל המקסימלי של הווקטורים + נקודות ההתחלה
    double maxMagnitude = 0.0;
    double maxStartPosition = 0.0;

    for (var vector in vectors) {
      maxMagnitude = max(maxMagnitude, vector.magnitude);
      double startDistance =
          sqrt(vector.startX * vector.startX + vector.startY * vector.startY);
      maxStartPosition = max(maxStartPosition, startDistance);
    }

    // קנה מידה מבוסס על הגודל המקסימלי + המרחק המקסימלי של נקודת התחלה
    double maxRange = max(maxMagnitude + maxStartPosition, 0.1);

    double gridScale = _calculateScale(maxRange);

    final Offset origin = Offset(size.width / 2, size.height / 2);

    final axisPaint = Paint()
      ..color = Colors.grey
      ..strokeWidth = 1.0;

    canvas.drawLine(
      Offset(0, origin.dy),
      Offset(size.width, origin.dy),
      axisPaint,
    );
    canvas.drawLine(
      Offset(origin.dx, 0),
      Offset(origin.dx, size.height),
      axisPaint,
    );

    double scaleFactor = min(size.width, size.height) * 0.35 / gridScale;

    _drawGridAndLabels(canvas, size, origin, gridScale, scaleFactor);

    for (var vector in vectors) {
      if (vector.magnitude == 0) continue;

      final paint = Paint()
        ..color = vector.color
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;

      final Offset vectorStart = Offset(
        origin.dx + vector.startX * scaleFactor,
        origin.dy - vector.startY * scaleFactor,
      );

      final Offset vectorEnd = Offset(
        vectorStart.dx + vector.x * scaleFactor,
        vectorStart.dy - vector.y * scaleFactor,
      );

      canvas.drawLine(vectorStart, vectorEnd, paint);

      final double angle = atan2(
        vectorEnd.dy - vectorStart.dy,
        vectorEnd.dx - vectorStart.dx,
      );

      canvas.drawLine(
        vectorEnd,
        Offset(
          vectorEnd.dx - arrowSize * cos(angle - pi / 6),
          vectorEnd.dy - arrowSize * sin(angle - pi / 6),
        ),
        paint,
      );
      canvas.drawLine(
        vectorEnd,
        Offset(
          vectorEnd.dx - arrowSize * cos(angle + pi / 6),
          vectorEnd.dy - arrowSize * sin(angle + pi / 6),
        ),
        paint,
      );

      canvas.drawCircle(
        vectorStart,
        4.0,
        Paint()
          ..color = vector.color
          ..style = PaintingStyle.fill,
      );
    }
  }

  void _drawGridAndLabels(Canvas canvas, Size size, Offset origin,
      double gridScale, double scaleFactor) {
    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.3)
      ..strokeWidth = 0.5;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    int numLines = 8;
    for (int i = -numLines; i <= numLines; i++) {
      if (i == 0) continue;

      double value = i * (gridScale / 4);

      double x = origin.dx + value * scaleFactor;
      if (x >= 0 && x <= size.width) {
        canvas.drawLine(
          Offset(x, 0),
          Offset(x, size.height),
          gridPaint,
        );

        textPainter.text = TextSpan(
          text: value.toStringAsFixed(value.abs() < 1 ? 2 : 1),
          style: TextStyle(color: Colors.grey, fontSize: 10),
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(x - textPainter.width / 2, origin.dy + 5),
        );
      }

      double y = origin.dy - value * scaleFactor;
      if (y >= 0 && y <= size.height) {
        canvas.drawLine(
          Offset(0, y),
          Offset(size.width, y),
          gridPaint,
        );

        textPainter.text = TextSpan(
          text: value.toStringAsFixed(value.abs() < 1 ? 2 : 1),
          style: TextStyle(color: Colors.grey, fontSize: 10),
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(origin.dx + 5, y - textPainter.height / 2),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant VectorPainter oldDelegate) {
    if (vectors.length != oldDelegate.vectors.length) {
      return true;
    }

    for (int i = 0; i < vectors.length; i++) {
      if (oldDelegate.vectors[i].magnitude != vectors[i].magnitude ||
          oldDelegate.vectors[i].angleDegrees != vectors[i].angleDegrees ||
          oldDelegate.vectors[i].startX != vectors[i].startX ||
          oldDelegate.vectors[i].startY != vectors[i].startY) {
        return true;
      }
    }
    return false;
  }
}
