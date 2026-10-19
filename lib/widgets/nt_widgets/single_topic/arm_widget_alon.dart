import 'dart:math';

import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_dropdown_chooser.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_toggle_switch.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class ArmAngleModel extends SingleTopicNTWidgetModel {
  @override
  String type = ArmAngleWidget.widgetType;

  String _angleDisplayMode = 'Radians';

  String get angleDisplayMode => _angleDisplayMode;

  set angleDisplayMode(String value) {
    _angleDisplayMode = value;
    refresh();
  }

  static final List<String> _angleDisplayOptions = [
    'Radians',
    'Degrees',
  ];

  bool _counterClockwisePositive = true;

  bool get counterClockwisePositive => _counterClockwisePositive;

  set counterClockwisePositive(bool value) {
    _counterClockwisePositive = value;
    refresh();
  }

  ArmAngleModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    String angleDisplayMode = 'Radians',
    bool counterClockwisePositive = true,
    super.dataType,
    super.period,
  })  : _angleDisplayMode = angleDisplayMode,
        _counterClockwisePositive = counterClockwisePositive,
        super();

  ArmAngleModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required Map<String, dynamic> jsonData,
  }) : super.fromJson(jsonData: jsonData) {
    _angleDisplayMode = tryCast(jsonData['angle_display_mode']) ?? 'Radians';

    _counterClockwisePositive =
        tryCast<bool>(jsonData['counter_clockwise_positive']) ??
            _counterClockwisePositive;
  }

  @override
  List<Widget> getEditProperties(BuildContext context) {
    return [
      Column(
        children: [
          const Text('Angle Display Mode'),
          DialogDropdownChooser<String>(
            initialValue: _angleDisplayMode,
            choices: _angleDisplayOptions,
            onSelectionChanged: (value) {
              if (value == null) {
                return;
              }

              angleDisplayMode = value;
            },
          ),
          const SizedBox(height: 5),
          DialogToggleSwitch(
            label: 'Counter Clockwise Positive',
            initialValue: _counterClockwisePositive,
            onToggle: (value) => counterClockwisePositive = value,
          ),
        ],
      ),
    ];
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'angle_display_mode': _angleDisplayMode,
      'counter_clockwise_positive': _counterClockwisePositive,
    };
  }
}

class ArmAngleWidget extends NTWidget {
  static const String widgetType = 'Arm Angle';

  const ArmAngleWidget({super.key});

  @override
  Widget build(BuildContext context) {
    ArmAngleModel model = cast(context.watch<NTWidgetModel>());

    return ValueListenableBuilder(
      valueListenable: model.subscription!,
      builder: (_, data, __) {
        double angle = tryCast<num>(data)?.toDouble() ?? 0;
        if (model.angleDisplayMode == 'Degrees') {
          angle = angle * pi / 180;
        }
        if (model.counterClockwisePositive) {
          angle = -angle;
        }

        return TweenAnimationBuilder<double>(
          tween: _ShortestAngleTween(end: angle),
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          builder: (_, animatedAngle, __) {
            return CustomPaint(
              size: Size.infinite,
              painter: ArmPainter(animatedAngle),
            );
          },
        );
      },
    );
  }
}

class ArmPainter extends CustomPainter {
  final double angle; // in radians

  ArmPainter(this.angle);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final length = min(size.width, size.height) / 2 * 0.9;

    final end = Offset(
      center.dx + length * sin(angle),
      center.dy - length * cos(angle),
    );

    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(center, end, paint);
  }

  @override
  bool shouldRepaint(ArmPainter old) => old.angle != angle;
}

class _ShortestAngleTween extends Tween<double> {
  _ShortestAngleTween({super.begin, super.end});

  @override
  double lerp(double t) {
    final diff = (end! - begin! + pi) % (2 * pi) - pi;
    return begin! + diff * t;
  }
}
