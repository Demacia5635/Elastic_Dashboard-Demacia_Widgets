import 'dart:math';

import 'package:dot_cast/dot_cast.dart';
import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class VectorModel extends MultiTopicNTWidgetModel {
  String type = Vector.widgetType;

  late List<NT4Subscription> vectorsX;
  late List<NT4Subscription> vectorsY;

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
  void initializeSubscriptions() {
    vectorsX = [];
    vectorsY = [];
    if (vectorsX.length != vectorsY.length) {
      throw Error();
    }

    for (int i = 0; i < 5; i++) {
      NT4Subscription subX =
          ntConnection.subscribe('$topic/Vector$i/X', super.period);
      NT4Subscription subY =
          ntConnection.subscribe('$topic/Vector$i/Y', super.period);

      subX.listen((value, timestamp) {
        notifyListeners();
      });

      subY.listen((value, timestamp) {
        notifyListeners();
      });

      vectorsX.add(subX);
      vectorsY.add(subY);
    }
  }

  int getActiveVectorCount() {
    int count = 0;
    for (int i = 0; i < vectorsX.length; i++) {
      var xValue = vectorsX[i].value;
      var yValue = vectorsY[i].value;

      if (xValue != null || yValue != null) {
        count = i + 1;
      }
    }
    return count;
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
        List<VectorData> vectors = [];

        for (int i = 0; i < model.getActiveVectorCount(); i++) {
          double x = tryCast(model.vectorsX[i].value) ?? 0.0;
          double y = tryCast(model.vectorsY[i].value) ?? 0.0;

          vectors.add(VectorData(
            x: x,
            y: y,
            color: _getColorForIndex(i),
            index: i,
          ));
        }
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
                      'V${vector.index}: (${vector.x.toStringAsFixed(2)}, ${vector.y.toStringAsFixed(2)})',
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

class VectorData {
  final double x;
  final double y;
  final Color color;
  final int index;

  VectorData(
      {required this.x,
      required this.y,
      required this.color,
      required this.index});

  double get magnitude => sqrt(x * x + y * y);
}

class VectorPainter extends CustomPainter {
  final List<VectorData> vectors;
  final double arrowSize;

  VectorPainter({
    required this.vectors,
    required this.arrowSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    double maxMagnitude = vectors.fold(
      0.0,
      (max, v) => v.magnitude > max ? v.magnitude : max,
    );

    if (maxMagnitude == 0) maxMagnitude = 1.0;

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

    double scaleFactor = min(size.width, size.height) * 0.4 / maxMagnitude;

    for (var vector in vectors) {
      if (vector.magnitude == 0) continue;

      final paint = Paint()
        ..color = vector.color
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;

      final Offset vectorEnd = Offset(
        origin.dx + vector.x * scaleFactor,
        origin.dy - vector.y * scaleFactor,
      );

      canvas.drawLine(origin, vectorEnd, paint);

      final double angle = atan2(
        vectorEnd.dy - origin.dy,
        vectorEnd.dx - origin.dx,
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
    }
  }

  @override
  bool shouldRepaint(covariant VectorPainter oldDelegate) {
    if (vectors.length != oldDelegate.vectors.length) {
      print('another Vector popped!');
      return true;
    }
    print('no new vector :(');

    for (int i = 0; i < vectors.length; i++) {
      if (oldDelegate.vectors[i].x != vectors[i].x ||
          oldDelegate.vectors[i].y != vectors[i].y) {
        print('x|y changed');
        return true;
      }
    }
    print('ntn changed');
    return false;
  }
}
