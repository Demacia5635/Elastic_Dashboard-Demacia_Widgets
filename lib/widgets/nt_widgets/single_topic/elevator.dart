import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_dropdown_chooser.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class elevatorModel extends SingleTopicNTWidgetModel {
  @override
  String type = elevatorWidget.widgetType;

  String _timeDisplayMode = '';

  String get timeDisplayMode => _timeDisplayMode;

  set timeDisplayMode(String value) {
    _timeDisplayMode = value;
    refresh();
  }

  static final List<String> _timeDisplayOptions = [
    '',
  ];

  int _minimumHight = 0;
  int _MaxHight = 5;
  
  int get minimumHight => _minimumHight;

  set minimumHight(int value) {
    _minimumHight = value;
    refresh();
  }

  int get maximumHight => _MaxHight;

  set maximumHight(int value) {
    _MaxHight = value;
    refresh();
  }

  

  elevatorModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    String timeDisplayMode = 'Minutes and Seconds',
    int minimumHight = 0,
    int maximumHight = 5,
    super.dataType,
    super.period,
  })  : _timeDisplayMode = timeDisplayMode,
        _MaxHight = maximumHight,
        _minimumHight = minimumHight,
        super();

  elevatorModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required Map<String, dynamic> jsonData,
  }) : super.fromJson(jsonData: jsonData) {
    _timeDisplayMode =
        tryCast(jsonData['time_display_mode']) ?? 'Minutes and Seconds';

    _timeDisplayOptions.firstWhere(
        (e) => e.toUpperCase() == _timeDisplayMode.toUpperCase(),
        orElse: () => 'Minutes and Seconds');

    _minimumHight =
        tryCast<num>(jsonData['minimum_height'])?.toInt() ?? _minimumHight;
    _MaxHight = tryCast<num>(jsonData['maximum_height'])?.toInt() ??
        _MaxHight;
  }

  @override
  List<Widget> getEditProperties(BuildContext context) {
    return [
     Flexible(
            child: DialogTextInput(
              onSubmit: (value) {
                double? newMax = double.tryParse(value);
                if (newMax == null) {
                  return;
                }
                _maxValue = newMax;
              },
              formatter: TextFormatterBuilder.decimalTextFormatter(
                  allowNegative: true),
              label: 'Max Value',
              initialText: _maxValue.toString(),
            ),
          ),
        ],

              timeDisplayMode = value;
            },
       
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
                    initialText: _redStartTime.toString(),
                    onSubmit: (value) {
                      int? newRedTime = int.tryParse(value);

                      if (newRedTime == null) {
                        return;
                      }

                      redStartTime = newRedTime;
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
                    initialText: _yellowStartTime.toString(),
                    onSubmit: (value) {
                      int? newYellowTime = int.tryParse(value);

                      if (newYellowTime == null) {
                        return;
                      }

                      yellowStartTime = newYellowTime;
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
      'time_display_mode': _timeDisplayMode,
      'red_start_time': _redStartTime,
      'yellow_start_time': _yellowStartTime,
    };
  }
}

class elevatorWidget extends NTWidget {
  static const String widgetType = 'elevator';

  const elevatorWidget({super.key});

  Color _getTimeColor(elevatorModel model, num time) {
    if (time <= model.redStartTime) {
      return Colors.red;
    } else if (time <= model.yellowStartTime) {
      return Colors.yellow;
    } else if (time <= 60.0) {
      return Colors.green;
    }

    return Colors.blue;
  }

  String _secondsToMinutes(num time) {
    return '${(time / 60.0).floor()}:${(time % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    MatchTimeModel model = cast(context.watch<NTWidgetModel>());

    return ValueListenableBuilder(
      valueListenable: model.subscription!,
      builder: (context, data, child) {
        double time = tryCast(data) ?? -1.0;
        time = time.floorToDouble();

        String timeDisplayString;
        if (model.timeDisplayMode == 'Minutes and Seconds' && time >= 0) {
          timeDisplayString = _secondsToMinutes(time.toInt());
        } else {
          timeDisplayString = time.toInt().toString();
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              child: FittedBox(
                fit: BoxFit.contain,
                child: Text(
                  timeDisplayString,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    height: 1.0,
                    color: _getTimeColor(model, time),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
