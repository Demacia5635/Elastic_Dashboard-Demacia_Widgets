import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class ElevatorModel extends SingleTopicNTWidgetModel {
  @override
  String type = ElevatorWidget.widgetType;

  double _minHeight;
  double _maxHeight;

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
    double minHeight = 0.0,
    double maxHeight = 5.0,
    super.dataType,
    super.period,
  })  : _minHeight = minHeight,
        _maxHeight = maxHeight,
        super();

  ElevatorModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required Map<String, dynamic> jsonData,
  })  : _minHeight = tryCast<num>(jsonData['minimum_height'])?.toDouble() ?? 0.0,
        _maxHeight = tryCast<num>(jsonData['maximum_height'])?.toDouble() ?? 5.0,
        super.fromJson(jsonData: jsonData);

  @override
  List<Widget> getEditProperties(BuildContext context) {
    return [
      Row(
        children: [
          Flexible(
            child: DialogTextInput(
              label: 'Minimum Height',
              initialText: _minHeight.toString(),
              formatter: TextFormatterBuilder.decimalTextFormatter(
                allowNegative: true,
              ),
              onSubmit: (value) {
                double? newMin = double.tryParse(value);
                if (newMin == null) {
                  return;
                }
                minHeight = newMin;
              },
            ),
          ),
          Flexible(
            child: DialogTextInput(
              label: 'Maximum Height',
              initialText: _maxHeight.toString(),
              formatter: TextFormatterBuilder.decimalTextFormatter(
                allowNegative: true,
              ),
              onSubmit: (value) {
                double? newMax = double.tryParse(value);
                if (newMax == null) {
                  return;
                }
                maxHeight = newMax;
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
      'minimum_height': _minHeight,
      'maximum_height': _maxHeight,
    };
  }
}

class ElevatorWidget extends NTWidget {
  static const String widgetType = 'elevator';

  const ElevatorWidget({super.key});

  @override
  Widget build(BuildContext context) {
    ElevatorModel model = cast(context.watch<NTWidgetModel>());

    return ValueListenableBuilder(
      valueListenable: model.subscription!,
      builder: (context, data, child) {
        double value = tryCast<num>(data)?.toDouble() ?? model.minHeight;

        double range = model.maxHeight - model.minHeight;
        double fraction = range <= 0
            ? 0.0
            : ((value - model.minHeight) / range).clamp(0.0, 1.0);

        return Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: FractionallySizedBox(
                    heightFactor: fraction,
                    widthFactor: 1.0,
                    child: Container(color: Colors.blue),
                  ),
                ),
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
  }
}