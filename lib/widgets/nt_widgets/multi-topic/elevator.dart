//Elevator.dart
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

  late NT4Subscription heightSubscription;

  // Every subscription goes in this list, so Elastic can clean them up.
  @override
  List<NT4Subscription> get subscriptions => [heightSubscription];

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

class ElevatorWidget extends NTWidget {
  static const String widgetType = 'Elevator';

  const ElevatorWidget({super.key});

  @override
  Widget build(BuildContext context) {
    ElevatorModel model = cast(context.watch<NTWidgetModel>());

    return ValueListenableBuilder(
      valueListenable: model.heightSubscription,
      builder: (context, data, child) {
        double value = tryCast<num>(data)?.toDouble() ?? model.minHeight;

        double range = model.maxHeight - model.minHeight;
        double fraction = range <= 0
            ? 0.0
            : ((value - model.minHeight) / range).clamp(0.0, 1.0);

        return LayoutBuilder(
          builder: (context, constraints) {
            const double carriageHeight = 24;
            double travel = constraints.maxHeight - carriageHeight;
            if (travel < 0) {
              travel = 0;
            }

            return Row(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      // The shaft
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey, width: 2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      // The carriage
                      Positioned(
                        left: 4,
                        right: 4,
                        bottom: fraction * travel,
                        height: carriageHeight,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  value.toStringAsFixed(2),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            );
          },
        );
      },
    );
  }
}
