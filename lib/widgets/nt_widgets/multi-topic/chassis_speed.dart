import 'dart:math';

import 'package:dot_cast/dot_cast.dart';
import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:provider/provider.dart';

class ChassisSpeedModel extends MultiTopicNTWidgetModel {
  @override
  String type = ChassisSpeed.widgetType;

  late NT4Subscription frontLeftModX;
  late NT4Subscription frontLeftModY;
  late NT4Subscription frontRightModX;
  late NT4Subscription frontRightModY;
  late NT4Subscription backLeftModX;
  late NT4Subscription backLeftModY;
  late NT4Subscription backRightModX;
  late NT4Subscription backRightModY;

  String get frontRightXTopic => '$topic/FrontRight/X';
  String get frontRightYTopic => '$topic/FrontRight/Y';
  String get frontLeftXTopic => '$topic/FrontLeft/X';
  String get frontLeftYTopic => '$topic/FrontLeft/Y';
  String get backRightXTopic => '$topic/BackRight/X';
  String get backRightYTopic => '$topic/BackRight/Y';
  String get backLeftXTopic => '$topic/BackLeft/X';
  String get backLeftYTopic => '$topic/BackLeft/Y';

  ChassisSpeedModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    super.period,
    super.dataType,
  });

  ChassisSpeedModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required super.jsonData,
  }) : super.fromJson();

  @override
  void initializeSubscriptions() {
    for (int i = 0; i < 8; i++) {
      frontLeftModX = ntConnection.subscribe("$topic/frontLeft$i/X", period);
      frontLeftModY = ntConnection.subscribe("$topic/frontLeft$i/Y", period);
      frontRightModX = ntConnection.subscribe("$topic/frontRight$i/X", period);
      frontRightModY = ntConnection.subscribe("$topic/frontRight$i/Y", period);
      backLeftModX = ntConnection.subscribe("$topic/backLeft$i/X", period);
      backLeftModY = ntConnection.subscribe("$topic/backLeft$i/Y", period);
      backRightModX = ntConnection.subscribe("$topic/backRight$i/X", period);
      backRightModY = ntConnection.subscribe("$topic/backRight$i/Y", period);
    }
    frontLeftModX = ntConnection.subscribe(frontLeftXTopic, period);
    frontLeftModY = ntConnection.subscribe(frontLeftYTopic, period);
    frontRightModX = ntConnection.subscribe(frontRightXTopic, period);
    frontRightModY = ntConnection.subscribe(frontRightYTopic, period);
    backLeftModX = ntConnection.subscribe(backLeftXTopic, period);
    backLeftModY = ntConnection.subscribe(backLeftYTopic, period);
    backRightModX = ntConnection.subscribe(backRightXTopic, period);
    backRightModY = ntConnection.subscribe(backRightYTopic, period);
  }
}

class ChassisSpeed extends NTWidget {
  static const String widgetType = 'Chassis Speed';

  const ChassisSpeed({super.key});

  @override
  Widget build(BuildContext context) {
    ChassisSpeedModel model = cast(context.watch<NTWidgetModel>());
    return Center(
      child: CustomPaint(
        painter: ChassisSpeedDisplay(
          frontRightX: tryCast(model.frontRightModX.value) ?? 0.0,
          frontRightY: tryCast(model.frontRightModY.value) ?? 0.0,
          frontLeftX: tryCast(model.frontLeftModX.value) ?? 0.0,
          frontLeftY: tryCast(model.frontLeftModY.value) ?? 0.0,
          backRightX: tryCast(model.backRightModX.value) ?? 0.0,
          backRightY: tryCast(model.backRightModY.value) ?? 0.0,
          backLeftX: tryCast(model.backLeftModX.value) ?? 0.0,
          backLeftY: tryCast(model.backLeftModY.value) ?? 0.0,
        ),
      ),
    );
  }
}

class ChassisSpeedDisplay extends CustomPainter {
  double frontRightX;
  double frontRightY;
  double frontLeftX;
  double frontLeftY;
  double backRightX;
  double backRightY;
  double backLeftX;
  double backLeftY;

  ChassisSpeedDisplay({
    required this.frontRightX,
    required this.frontRightY,
    required this.frontLeftX,
    required this.frontLeftY,
    required this.backRightX,
    required this.backRightY,
    required this.backLeftX,
    required this.backLeftY,
  });

  List<Offset> getChassisVector() {
    List<Offset> vector = [];
    double vectorX = frontRightX + frontLeftX + backLeftX + backRightX;
    double vectorY = frontRightY + frontLeftY + backLeftY + backRightY;
    vector.add(Offset(0, vectorY));
    vector.add(Offset(vectorX, 0));
    return vector;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final axisPaint = Paint()
      ..color = Colors.grey
      ..strokeWidth = 1.0;

    canvas.drawLine(
      Offset(0, center.dy),
      Offset(size.width, center.dy),
      axisPaint,
    );

    canvas.drawLine(
      Offset(center.dx, 0),
      Offset(center.dx, size.height),
      axisPaint,
    );

    double totalX = frontRightX + frontLeftX + backLeftX + backRightX;
    double totalY = frontRightY + frontLeftY + backLeftY + backRightY;

    double magnitude = sqrt(totalX * totalX + totalY * totalY);
    double scaleFactor =
        magnitude > 0 ? min(size.width, size.height) * 0.3 / magnitude : 1.0;

    final vectorEnd = Offset(
      center.dx + totalX * scaleFactor,
      center.dy - totalY * scaleFactor,
    );

    final vectorPaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    canvas.drawLine(center, vectorEnd, vectorPaint);

    if (magnitude > 0.01) {
      _drawArrowHead(canvas, center, vectorEnd, Colors.blue);
    }

    final textPainter = TextPainter(
      text: TextSpan(
        text:
            'X: ${totalX.toStringAsFixed(2)}\nY: ${totalY.toStringAsFixed(2)}\nMag: ${magnitude.toStringAsFixed(2)}',
        style: TextStyle(
          color: Colors.black,
          fontSize: 12,
          backgroundColor: Colors.white.withOpacity(0.8),
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(10, 10));
  }

  void _drawArrowHead(Canvas canvas, Offset start, Offset end, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    final angle = atan2(end.dy - start.dy, end.dx - start.dx);
    final arrowSize = 15.0;

    final arrowPoint1 = Offset(
      end.dx - arrowSize * cos(angle - pi / 6),
      end.dy - arrowSize * sin(angle - pi / 6),
    );

    final arrowPoint2 = Offset(
      end.dx - arrowSize * cos(angle + pi / 6),
      end.dy - arrowSize * sin(angle + pi / 6),
    );

    canvas.drawLine(end, arrowPoint1, paint);
    canvas.drawLine(end, arrowPoint2, paint);
  }

  @override
  bool shouldRepaint(covariant ChassisSpeedDisplay oldDelegate) {
    return oldDelegate.frontRightX != frontRightX ||
        oldDelegate.frontRightY != frontRightY ||
        oldDelegate.frontLeftX != frontLeftX ||
        oldDelegate.frontLeftY != frontLeftY ||
        oldDelegate.backRightX != backRightX ||
        oldDelegate.backRightY != backRightY ||
        oldDelegate.backLeftX != backLeftX ||
        oldDelegate.backLeftY != backLeftY;
  }
}
