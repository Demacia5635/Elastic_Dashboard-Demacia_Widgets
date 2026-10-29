//ElevatorFancy.dart
import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/text_formatter_builder.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class ElevatorModel extends MultiTopicNTWidgetModel {
  @override
  String type = ElevatorWidget.widgetType;

  String get heightTopic => '$topic/Height';

  // The topic the slider writes to (must match the robot's "Target Height")
  String get targetTopic => '$topic/Target Height';

  late NT4Subscription heightSubscription;
  late NT4Subscription targetSubscription;

  // Slider state
  ValueNotifier<double> displayTarget = ValueNotifier(0.0);
  ValueNotifier<bool> dragging = ValueNotifier(false);
  NT4Topic? _targetNtTopic;

  // Every subscription goes in this list, so Elastic can clean them up.
  @override
  List<NT4Subscription> get subscriptions =>
      [heightSubscription, targetSubscription];

  double _minHeight = 0;
  double _maxHeight = 1.3;

  double get minHeight => _minHeight;

  set minHeight(double value) {
    _minHeight = value;
    refresh();
  }

  double get maxHeight => _maxHeight;

  set maxHeight(double value) {
    _maxHeight = value;
    refresh();
  }

  ElevatorModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    double minHeight = 0,
    double maxHeight = 1.3,
    super.dataType,
    super.period,
  })  : _minHeight = minHeight,
        _maxHeight = maxHeight,
        super();

  ElevatorModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required Map<String, dynamic> jsonData,
  }) : super.fromJson(jsonData: jsonData) {
    _minHeight = tryCast<num>(jsonData['min_height'])?.toDouble() ?? 0;
    _maxHeight = tryCast<num>(jsonData['max_height'])?.toDouble() ?? 1.3;
  }

  // Called when the widget is created, and again if the topic changes.
  @override
  void initializeSubscriptions() {
    heightSubscription = ntConnection.subscribe(heightTopic, period);
    targetSubscription = ntConnection.subscribe(targetTopic, period);
    _targetNtTopic = null; // re-resolve if the topic changed
  }

  // Writes the slider value to NetworkTables (same pattern as Number Slider)
  void publishTarget(double value) {
    bool publishTopic = _targetNtTopic == null ||
        !ntConnection.isTopicPublished(_targetNtTopic);

    _targetNtTopic ??= ntConnection.getTopicFromName(targetTopic);

    if (_targetNtTopic == null) {
      return;
    }

    if (publishTopic) {
      ntConnection.publishTopic(_targetNtTopic!);
    }

    ntConnection.updateDataFromTopic(_targetNtTopic!, value);
  }

  @override
  List<Widget> getEditProperties(BuildContext context) {
    return [
      Row(
        children: [
          Flexible(
            child: DialogTextInput(
              label: 'Min Height',
              initialText: _minHeight.toString(),
              formatter: TextFormatterBuilder.decimalTextFormatter(
                  allowNegative: true),
              onSubmit: (value) {
                final double? newMin = double.tryParse(value);
                if (newMin != null) {
                  minHeight = newMin;
                }
              },
            ),
          ),
          Flexible(
            child: DialogTextInput(
              label: 'Max Height',
              initialText: _maxHeight.toString(),
              formatter: TextFormatterBuilder.decimalTextFormatter(
                  allowNegative: true),
              onSubmit: (value) {
                final double? newMax = double.tryParse(value);
                if (newMax != null) {
                  maxHeight = newMax;
                }
              },
            ),
          ),
        ],
      ),
    ];
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'min_height': _minHeight,
      'max_height': _maxHeight,
    };
  }
}

// Draws the tick marks on both sides of the shaft.
class _ShaftTickPainter extends CustomPainter {
  // Distance from the bottom/top edge to the center of the carriage at its
  // lowest/highest position.
  final double inset;
  final int divisions;

  _ShaftTickPainter({required this.inset, this.divisions = 10});

  @override
  void paint(Canvas canvas, Size size) {
    final double travel = size.height - 2 * inset;
    if (travel <= 0) {
      return;
    }

    final Paint paint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1;

    for (int i = 0; i <= divisions; i++) {
      final double y = size.height - inset - travel * i / divisions;
      final bool major = i % 5 == 0;
      final double length = major ? 8 : 4;

      canvas.drawLine(Offset(0, y), Offset(length, y), paint);
      canvas.drawLine(
          Offset(size.width - length, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ShaftTickPainter oldDelegate) {
    return oldDelegate.inset != inset || oldDelegate.divisions != divisions;
  }
}

class ElevatorWidget extends NTWidget {
  static const String widgetType = 'Elevator';

  const ElevatorWidget({super.key});

  static const Color _blue = Color.fromRGBO(33, 150, 243, 1);
  static const Color _blueGlow = Color.fromRGBO(33, 150, 243, 0.5);
  static const Color _trailLow = Color.fromRGBO(33, 150, 243, 0.05);
  static const Color _trailHigh = Color.fromRGBO(33, 150, 243, 0.35);
  static const Color _targetColor = Colors.amber;

  @override
  Widget build(BuildContext context) {
    ElevatorModel model = cast(context.watch<NTWidgetModel>());

    return ListenableBuilder(
      listenable: Listenable.merge([
        model.heightSubscription,
        model.targetSubscription,
        model.displayTarget,
        model.dragging,
      ]),
      builder: (context, child) {
        double value =
            tryCast<num>(model.heightSubscription.value)?.toDouble() ??
                model.minHeight;

        double range = model.maxHeight - model.minHeight;
        bool validRange = range > 0;

        double fraction = range <= 0
            ? 0.0
            : ((value - model.minHeight) / range).clamp(0.0, 1.0);

        // Target / slider values
        double sliderMin = model.minHeight;
        double sliderMax = validRange ? model.maxHeight : model.minHeight + 1;
        bool hasTarget = model.targetSubscription.value != null;
        double robotTarget =
            tryCast<num>(model.targetSubscription.value)?.toDouble() ??
                model.minHeight;
        double shownTarget =
            (model.dragging.value ? model.displayTarget.value : robotTarget)
                .clamp(sliderMin, sliderMax)
                .toDouble();
        double targetFraction = range <= 0
            ? 0.0
            : ((shownTarget - model.minHeight) / range)
                .clamp(0.0, 1.0)
                .toDouble();

        final TextStyle? labelStyle =
            Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white54,
                  letterSpacing: 1.2,
                );

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ---------- The shaft ----------
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const double carriageHeight = 28;
                  const double pad = 4;
                  const Duration animation = Duration(milliseconds: 150);

                  double travel =
                      constraints.maxHeight - carriageHeight - 2 * pad;
                  if (travel < 0) {
                    travel = 0;
                  }

                  double bottomFor(double f) => pad + f * travel;

                  return Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white24, width: 1.5),
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF1E1E22), Color(0xFF2A2A30)],
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8.5),
                      child: Stack(
                        children: [
                          // Tick marks
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _ShaftTickPainter(
                                inset: pad + carriageHeight / 2,
                              ),
                            ),
                          ),
                          // Glowing trail under the carriage
                          AnimatedPositioned(
                            duration: animation,
                            curve: Curves.easeOut,
                            left: 2,
                            right: 2,
                            bottom: 2,
                            height: pad + fraction * travel + carriageHeight / 2,
                            child: Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [_trailLow, _trailHigh],
                                ),
                              ),
                            ),
                          ),
                          // Target marker
                          if (hasTarget)
                            AnimatedPositioned(
                              duration: animation,
                              curve: Curves.easeOut,
                              left: 0,
                              right: 0,
                              bottom: bottomFor(targetFraction) +
                                  carriageHeight / 2 -
                                  1,
                              height: 2,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _targetColor,
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color.fromRGBO(255, 193, 7, 0.6),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          // The carriage
                          AnimatedPositioned(
                            duration: animation,
                            curve: Curves.easeOut,
                            left: 10,
                            right: 10,
                            bottom: bottomFor(fraction),
                            height: carriageHeight,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.blue.shade300,
                                    Colors.blue.shade700,
                                  ],
                                ),
                                border: Border.all(
                                  color: Colors.white30,
                                  width: 1,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: _blueGlow,
                                    blurRadius: 10,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              // Grip lines
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: List.generate(
                                    3,
                                    (_) => Container(
                                      width: 18,
                                      height: 2,
                                      margin: const EdgeInsets.symmetric(
                                          vertical: 1),
                                      decoration: BoxDecoration(
                                        color: Colors.white54,
                                        borderRadius: BorderRadius.circular(1),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 2),

            // ---------- Target slider ----------
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                activeTrackColor: _targetColor,
                inactiveTrackColor: Colors.white24,
                thumbColor: _targetColor,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                overlayShape:
                    const RoundSliderOverlayShape(overlayRadius: 14),
                disabledActiveTrackColor: Colors.white24,
                disabledThumbColor: Colors.white38,
              ),
              child: RotatedBox(
                quarterTurns: 3,
                child: Slider(
                  min: sliderMin,
                  max: sliderMax,
                  value: shownTarget,
                  onChangeStart: validRange
                      ? (_) {
                          model.displayTarget.value = shownTarget;
                          model.dragging.value = true;
                        }
                      : null,
                  onChanged: validRange
                      ? (newValue) {
                          model.displayTarget.value = newValue;
                        }
                      : null,
                  onChangeEnd: validRange
                      ? (newValue) {
                          model.publishTarget(newValue);
                          model.dragging.value = false;
                        }
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 4),

            // ---------- Readout ----------
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('HEIGHT', style: labelStyle),
                  Text(
                    value.toStringAsFixed(2),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _blue,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'TARGET',
                    style: labelStyle?.copyWith(color: Colors.amber.shade200),
                  ),
                  Text(
                    hasTarget ? shownTarget.toStringAsFixed(2) : '--',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: _targetColor,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${model.minHeight.toStringAsFixed(1)} - '
                    '${model.maxHeight.toStringAsFixed(1)}',
                    style: labelStyle,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}