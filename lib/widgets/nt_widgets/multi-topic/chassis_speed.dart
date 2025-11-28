import 'dart:math';

import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class ChassisSpeedModel extends MultiTopicNTWidgetModel {
  @override
  String type = ChassisSpeedWidget.widgetType;

  late NT4Subscription _normalSpeedValueSubscription;
  late NT4Subscription _normalSpeedAngleSubscription;
  late NT4Subscription _angularSpeedSubscription;

  // Define distinct topics for each piece of data
  // These should be configured to match what your robot publishes.
  String get linearSpeedValueTopic => '$topic/LinearSpeedValue';
  String get linearSpeedAngleTopic => '$topic/LinearSpeedAngle'; // Degrees
  String get angularSpeedTopic => '$topic/AngularSpeed'; // Radians/sec

  @override
  List<NT4Subscription> get subscriptions => [
        _normalSpeedValueSubscription,
        _normalSpeedAngleSubscription,
        _angularSpeedSubscription
      ];

  ChassisSpeedModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    super.period,
    super.dataType,
  }) : super();

  ChassisSpeedModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required super.jsonData,
  }) : super.fromJson();

  @override
  void initializeSubscriptions() {
    _normalSpeedValueSubscription =
        ntConnection.subscribe(linearSpeedValueTopic, super.period);
    _normalSpeedAngleSubscription =
        ntConnection.subscribe(linearSpeedAngleTopic, super.period);
    _angularSpeedSubscription =
        ntConnection.subscribe(angularSpeedTopic, super.period);

    // 🔥 IMPORTANT: Without these the widget NEVER updates
    _normalSpeedValueSubscription.listen((value, timestamp) {
      notifyListeners();
    });
    _normalSpeedAngleSubscription.listen((value, timestamp) {
      notifyListeners();
    });
    _angularSpeedSubscription.listen((value, timestamp) {
      notifyListeners();
    });
  }

  // --- FIX APPLIED HERE: Robust type casting ---
  // We first try to cast to 'num' (which covers int and double) and then
  // convert to double. If that fails, we default to 0.0.
  double get linearSpeedValue {
    final num? value = tryCast(_normalSpeedValueSubscription.currentValue);
    return value?.toDouble() ?? 20;
  }

  double get linearSpeedAngle {
    return tryCast(_normalSpeedAngleSubscription.currentValue) ?? 20.0;
    //return value?.toDouble() ?? 5;
  }

  double get angularSpeed {
    final num? value = tryCast(_angularSpeedSubscription.currentValue);
    return value?.toDouble() ?? 0.0;
  }
  // ---------------------------------------------
}

// ----------------------------------------------------------------------
// 2. WIDGET (Renders data using a CustomPainter)
// ----------------------------------------------------------------------

class ChassisSpeedWidget extends NTWidget {
  static const String widgetType = 'ChassisSpeedVisualizer';

  const ChassisSpeedWidget({super.key});
  @override
  Widget build(BuildContext context) {
    // This automatically rebuilds when notifyListeners() fires
    final ChassisSpeedModel model = cast(context.watch<NTWidgetModel>());

    final double speedValue = model.linearSpeedValue;
    final double speedAngle = model.linearSpeedAngle;
    final double angularSpeed = model.angularSpeed;

    return Stack(
      children: [
        CustomPaint(
          size: Size.infinite,
          painter: ChassisSpeedPainter(
            linearSpeed: speedValue,
            linearAngle: speedAngle,
            angularSpeed: angularSpeed,
            vectorColor: Theme.of(context).colorScheme.primary,
            angularColor: Theme.of(context).colorScheme.tertiary,
            centerColor: Theme.of(context).colorScheme.onSurface,
          ),
        ),

        /// Debug overlay
        Positioned(
          top: 5,
          left: 5,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Linear Speed: ${speedValue.toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.white, fontSize: 10)),
                Text('Linear Angle: ${speedAngle.toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.white, fontSize: 10)),
                Text('Angular Speed: ${angularSpeed.toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.white, fontSize: 10)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ----------------------------------------------------------------------
// 3. CUSTOM PAINTER (Draws the two vectors)
// ----------------------------------------------------------------------

class ChassisSpeedPainter extends CustomPainter {
  final double linearSpeed; // Magnitude of linear velocity
  final double linearAngle; // Direction in degrees (e.g., 0 = forward)
  final double angularSpeed; // Magnitude of angular velocity
  final Color vectorColor;
  final Color angularColor;
  final Color centerColor;

  // Configuration constants for visualization scaling
  // Set to 20.0 to handle your input of 15
  static const double maxSpeedScale = 20.0;
  static const double maxAngularScale = 10.0;
  static const double arrowHeadSize = 10.0;
  static const double arcRadius = 40.0;
  // Threshold for drawing the vector
  static const double minVectorDrawLength = 1.0;

  ChassisSpeedPainter({
    required this.linearSpeed,
    required this.linearAngle,
    required this.angularSpeed,
    required this.vectorColor,
    required this.angularColor,
    required this.centerColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double centerX = size.width / 2;
    final double centerY = size.height / 2;
    final Offset center = Offset(centerX, centerY);

    // --- 1. Draw the Chassis Center ---
    final Paint centerPaint = Paint()..color = centerColor;
    canvas.drawCircle(center, 5.0, centerPaint);

    // --- 2. Draw the Linear Speed Vector ---
    _drawLinearSpeed(canvas, center, size);

    // --- 3. Draw the Angular Speed Vector ---
    _drawAngularSpeed(canvas, center);
  }

  void _drawLinearSpeed(Canvas canvas, Offset center, Size size) {
    // Determine the maximum length the vector can be (e.g., 40% of the smallest dimension)
    final double maxLength = min(size.width, size.height) * 0.40;

    // Scale the actual speed value to the drawing length
    final double speedMagnitude = linearSpeed.abs().clamp(0.0, maxSpeedScale);
    final double vectorLength = (speedMagnitude / maxSpeedScale) * maxLength;

    if (vectorLength < minVectorDrawLength) return;

    // Convert angle (degrees) to radians.
    // We adjust the angle to make 0 degrees point up (North) on the screen.
    final double angleInRadians = (linearAngle - 90.0) * (pi / 180.0);

    // Calculate the end point of the vector
    final double endX = center.dx + vectorLength * cos(angleInRadians);
    final double endY = center.dy + vectorLength * sin(angleInRadians);
    final Offset endPoint = Offset(endX, endY);

    // Setup the vector paint
    final Paint vectorPaint = Paint()
      ..color = vectorColor
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw the main vector line
    canvas.drawLine(center, endPoint, vectorPaint);

    // Draw the arrowhead at the end point
    _drawArrowhead(canvas, endPoint, angleInRadians, vectorPaint);
  }

  void _drawArrowhead(Canvas canvas, Offset point, double angle, Paint paint) {
    // Calculate the points for the arrowhead, which is an isosceles triangle
    final double halfAngle = atan(arrowHeadSize / (2 * arrowHeadSize));
    final double angle1 = angle + pi - halfAngle;
    final double angle2 = angle + pi + halfAngle;

    final Path path = Path()
      ..moveTo(point.dx, point.dy)
      // Point 1
      ..lineTo(
        point.dx + arrowHeadSize * cos(angle1),
        point.dy + arrowHeadSize * sin(angle1),
      )
      // Point 2
      ..lineTo(
        point.dx + arrowHeadSize * cos(angle2),
        point.dy + arrowHeadSize * sin(angle2),
      )
      ..close();

    canvas.drawPath(path, paint..style = PaintingStyle.fill);
  }

  void _drawAngularSpeed(Canvas canvas, Offset center) {
    // Clamp the angular speed magnitude for visualization
    final double magnitude = angularSpeed.abs().clamp(0.0, maxAngularScale);

    if (magnitude < 0.1) return; // Skip if speed is too small

    // Calculate arc properties
    // Max sweep angle is PI/2 (90 degrees)
    final double maxSweepAngle = pi / 2;
    final double sweepAngle = (magnitude / maxAngularScale) * maxSweepAngle;

    // The arc is centered at the origin, starting from a fixed angle (e.g., 45 degrees)
    const double startAngle = pi / 4; // Start at 45 degrees (top-right)

    // Setup the angular vector paint
    final Paint angularPaint = Paint()
      ..color = angularColor
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    // Define the bounding box for the arc
    final Rect rect = Rect.fromCircle(center: center, radius: arcRadius);

    // Angular speed sign determines rotation direction (clockwise or counter-clockwise)
    final bool isClockwise = angularSpeed > 0;

    // Adjust start and sweep angle based on direction
    double finalStartAngle = startAngle;
    double finalSweepAngle = sweepAngle;

    // If rotating counter-clockwise, we start from the end point and sweep backwards
    if (!isClockwise) {
      finalStartAngle = startAngle + sweepAngle;
      finalSweepAngle = -sweepAngle;
    }

    // Draw the arc
    canvas.drawArc(
      rect,
      finalStartAngle,
      finalSweepAngle,
      false, // Use center is false for just the arc line
      angularPaint,
    );

    // Draw a small arrowhead on the arc to indicate rotation direction
    // Arrowhead is placed at the end of the arc sweep.
    final double arrowAngle =
        isClockwise ? startAngle + sweepAngle : startAngle;

    final double arrowX = center.dx + arcRadius * cos(arrowAngle);
    final double arrowY = center.dy + arcRadius * sin(arrowAngle);

    // Calculate perpendicular angle for the arrowhead wings
    final double perpendicularAngle =
        arrowAngle + (isClockwise ? pi / 2 : -pi / 2);

    canvas.drawLine(
      Offset(arrowX, arrowY),
      Offset(arrowX + 8 * cos(perpendicularAngle - 0.2),
          arrowY + 8 * sin(perpendicularAngle - 0.2)),
      angularPaint,
    );
    canvas.drawLine(
      Offset(arrowX, arrowY),
      Offset(arrowX + 8 * cos(perpendicularAngle + 0.2),
          arrowY + 8 * sin(perpendicularAngle + 0.2)),
      angularPaint,
    );
  }

  @override
  bool shouldRepaint(covariant ChassisSpeedPainter oldDelegate) {
    // Only repaint if the data has changed
    return oldDelegate.linearSpeed != linearSpeed ||
        oldDelegate.linearAngle != linearAngle ||
        oldDelegate.angularSpeed != angularSpeed;
  }
}
