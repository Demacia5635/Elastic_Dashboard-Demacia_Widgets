import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_dropdown_chooser.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import 'dart:math';

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

  double _radianStartAngle = 0;
  double _degreeStartAngle = 0;

  double get radianStartAngle => _radianStartAngle;

  set radianStartAngle(double value) {
    _radianStartAngle = value;
    refresh();
  }

  double get degreeStartAngle => _degreeStartAngle;

  set degreeStartAngle(double value) {
    _degreeStartAngle = value;
    refresh();
  }

  ArmAngleModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    String angleDisplayMode = 'Radians',
    double radianStartAngle = 0,
    double degreeStartAngle = 0,
    super.dataType,
    super.period,
  })  : _angleDisplayMode = angleDisplayMode,
        _degreeStartAngle = degreeStartAngle,
        _radianStartAngle = radianStartAngle,
        super();

  ArmAngleModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required Map<String, dynamic> jsonData,
  }) : super.fromJson(jsonData: jsonData) {
    _angleDisplayMode = tryCast(jsonData['angle_display_mode']) ?? 'Radians';

    _angleDisplayOptions.firstWhere(
        (e) => e.toUpperCase() == _angleDisplayMode.toUpperCase(),
        orElse: () => 'Radians');

    _radianStartAngle =
        tryCast<num>(jsonData['Radian_start_angle'])?.toDouble() ??
            _radianStartAngle;
    _degreeStartAngle =
        tryCast<num>(jsonData['Degree_start_angle'])?.toDouble() ??
            _degreeStartAngle;
  }

  @override
  List<Widget> getEditProperties(BuildContext context) {
    return [
      Column(
        children: [
          const Text('Angle Display Mode'),
          DialogDropdownChooser<String>(
            initialValue: _angleDisplayMode,
            choices: const ['Radians', 'Degrees'],
            onSelectionChanged: (value) {
              if (value == null) {
                return;
              }

              angleDisplayMode = value;
            },
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Flexible(
                child: Tooltip(
                  message:
                      'The time (in seconds) where time will begin to display in red',
                  waitDuration: const Duration(milliseconds: 750),
                  child: DialogTextInput(
                    label: 'Red Start Time',
                    initialText: _radianStartAngle.toString(),
                    onSubmit: (value) {
                      double? newRedTime = double.tryParse(value);

                      if (newRedTime == null) {
                        return;
                      }

                      radianStartAngle = newRedTime;
                    },
                    formatter: FilteringTextInputFormatter.digitsOnly,
                  ),
                ),
              ),
              Flexible(
                child: Tooltip(
                  message:
                      'The time (in seconds) where time will begin to display in yellow',
                  waitDuration: const Duration(milliseconds: 750),
                  child: DialogTextInput(
                    label: 'Yellow Start Time',
                    initialText: _degreeStartAngle.toString(),
                    onSubmit: (value) {
                      double? newYellowTime = double.tryParse(value);

                      if (newYellowTime == null) {
                        return;
                      }

                      degreeStartAngle = newYellowTime;
                    },
                    formatter: FilteringTextInputFormatter.digitsOnly,
                  ),
                ),
              ),
            ],
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
      'Radian_start_angle': _radianStartAngle,
      'Degree_start_angle': _degreeStartAngle,
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
      builder: (context, data, child) {
        double angle = tryCast(data) ?? 0;

        if (model.angleDisplayMode == 'Degrees') {
          angle = angle * pi / 180;
        }

        return CustomPaint(
          size: Size.infinite,
            painter: ArmPainter(angle),
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
