import 'dart:async';

import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import 'package:elastic_dashboard/services/log.dart';
import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/text_formatter_builder.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_color_picker.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class ArrayGraphModel extends SingleTopicNTWidgetModel {
  @override
  String type = ArrayGraphWidget.widgetType;

  late double _timeDisplayed;
  double? _minValue;
  double? _maxValue;
  late Color _mainColor;
  late double _lineWidth;
  bool enableScrolling = true;
  int maxHistoricalPoints = 2000;
  double maxTime = 2.5 * 60 * 1e6;
  int _selectedIndex = 0;

  double get timeDisplayed => _timeDisplayed;

  set timeDisplayed(double value) {
    _timeDisplayed = value;
    refresh();
  }

  double? get minValue => _minValue;

  set minValue(double? value) {
    _minValue = value;
    refresh();
  }

  double? get maxValue => _maxValue;

  set maxValue(double? value) {
    _maxValue = value;
    refresh();
  }

  Color get mainColor => _mainColor;

  set mainColor(Color value) {
    _mainColor = value;
    refresh();
  }

  double get lineWidth => _lineWidth;

  set lineWidth(double value) {
    _lineWidth = value;
    refresh();
  }

  int get selectedIndex => _selectedIndex;

  set selectedIndex(int value) {
    _selectedIndex = value;
    refresh();
  }

  List<_GraphPoint> _graphData = [];
  _ArrayGraphWidgetGraph? _graphWidget;

  ArrayGraphModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    double timeDisplayed = 5.0,
    double? minValue,
    double? maxValue,
    Color mainColor = Colors.cyan,
    double lineWidth = 2.0,
    int maxHistoricalPoints = 2000,
    double maxTime = 2.5 * 60 * 1e6,
    int selectedIndex = 0,
    super.dataType,
    super.period,
  })  : _timeDisplayed = timeDisplayed,
        _minValue = minValue,
        _maxValue = maxValue,
        _mainColor = mainColor,
        _lineWidth = lineWidth,
        _selectedIndex = selectedIndex,
        super();

  ArrayGraphModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required Map<String, dynamic> jsonData,
  }) : super.fromJson(jsonData: jsonData) {
    _timeDisplayed = tryCast(jsonData['time_displayed']) ??
        tryCast(jsonData['visibleTime']) ??
        5.0;
    _minValue = tryCast(jsonData['min_value']);
    _maxValue = tryCast(jsonData['max_value']);
    _mainColor = Color(tryCast(jsonData['color']) ?? Colors.cyan.toARGB32());
    _lineWidth = tryCast(jsonData['line_width']) ?? 2.0;
    enableScrolling = tryCast(jsonData['enable_scrolling']) ?? true;
    maxHistoricalPoints = tryCast(jsonData['max_historical_points']) ?? 2000;
    maxTime = tryCast(jsonData['max_time']) ?? 2.5 * 60 * 1e6;
    _selectedIndex = tryCast(jsonData['selected_index']) ?? 0;
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'time_displayed': _timeDisplayed,
      if (_minValue != null) 'min_value': _minValue,
      if (_maxValue != null) 'max_value': _maxValue,
      'color': _mainColor.toARGB32(),
      'line_width': _lineWidth,
      'enable_scrolling': enableScrolling,
      'max_historical_points': maxHistoricalPoints,
      'max_time': maxTime,
      'selected_index': _selectedIndex,
    };
  }

  @override
  List<Widget> getEditProperties(BuildContext context) {
    return [
      // First row: Color and Time Displayed
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        mainAxisSize: MainAxisSize.max,
        children: [
          Flexible(
            child: DialogColorPicker(
              onColorPicked: (color) {
                mainColor = color;
              },
              label: 'Graph Color',
              initialColor: _mainColor,
              defaultColor: Colors.cyan,
            ),
          ),
          Flexible(
            child: DialogTextInput(
              onSubmit: (value) {
                double? newTime = double.tryParse(value);

                if (newTime == null) {
                  return;
                }
                timeDisplayed = newTime;
              },
              formatter: TextFormatterBuilder.decimalTextFormatter(),
              label: 'Time Displayed (Seconds)',
              initialText: _timeDisplayed.toString(),
            ),
          ),
        ],
      ),
      const SizedBox(height: 5),

      // Second row: Min, Max, Line Width
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        mainAxisSize: MainAxisSize.max,
        children: [
          Flexible(
            child: DialogTextInput(
              onSubmit: (value) {
                double? newMinimum = double.tryParse(value);
                bool refreshGraph = newMinimum != _minValue;

                _minValue = newMinimum;

                if (refreshGraph) {
                  refresh();
                }
              },
              formatter: TextFormatterBuilder.decimalTextFormatter(
                  allowNegative: true),
              label: 'Minimum',
              initialText: _minValue?.toString(),
              allowEmptySubmission: true,
            ),
          ),
          Flexible(
            child: DialogTextInput(
              onSubmit: (value) {
                double? newMaximum = double.tryParse(value);
                bool refreshGraph = newMaximum != _maxValue;

                _maxValue = newMaximum;

                if (refreshGraph) {
                  refresh();
                }
              },
              formatter: TextFormatterBuilder.decimalTextFormatter(
                  allowNegative: true),
              label: 'Maximum',
              initialText: _maxValue?.toString(),
              allowEmptySubmission: true,
            ),
          ),
          Flexible(
            child: DialogTextInput(
              onSubmit: (value) {
                double? newWidth = double.tryParse(value);

                if (newWidth == null || newWidth < 0.01) {
                  return;
                }

                lineWidth = newWidth;
              },
              formatter: TextFormatterBuilder.decimalTextFormatter(),
              label: 'Line Width',
              initialText: _lineWidth.toString(),
            ),
          ),
        ],
      ),
      const SizedBox(height: 5),

      // Third row: Enable Scrolling and Max Historical Points
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Flexible(
            child: CheckboxListTile(
              title: const Text('Enable Time Scrolling'),
              value: enableScrolling,
              onChanged: (value) {
                enableScrolling = value ?? true;
                refresh();
              },
            ),
          ),
          Flexible(
            child: DialogTextInput(
              onSubmit: (value) {
                int? newMax = int.tryParse(value);
                if (newMax == null || newMax < 100) {
                  return;
                }
                maxHistoricalPoints = newMax;
                refresh();
              },
              formatter: TextFormatterBuilder.decimalTextFormatter(),
              label: 'Max Historical Points',
              initialText: maxHistoricalPoints.toString(),
            ),
          ),
        ],
      ),
    ];
  }
}

class ArrayGraphWidget extends NTWidget {
  static const String widgetType = 'Array Graph';

  const ArrayGraphWidget({super.key});

  @override
  Widget build(BuildContext context) {
    ArrayGraphModel model = cast(context.watch<NTWidgetModel>());

    List<_GraphPoint>? currentGraphData = model._graphWidget?.getCurrentData();

    if (currentGraphData != null) {
      model._graphData = currentGraphData;
    }

    return model._graphWidget = _ArrayGraphWidgetGraph(
      initialData: model._graphData,
      subscription: model.subscription,
      timeDisplayed: model.timeDisplayed,
      lineWidth: model.lineWidth,
      mainColor: model.mainColor,
      minValue: model.minValue,
      maxValue: model.maxValue,
      enableScrolling: model.enableScrolling,
      maxHistoricalPoints: model.maxHistoricalPoints,
      maxTime: model.maxTime,
      selectedIndex: model.selectedIndex,
      onIndexChanged: (index) {
        model.selectedIndex = index;
      },
    );
  }
}

class _ArrayGraphWidgetGraph extends StatefulWidget {
  final NT4Subscription? subscription;
  final double? minValue;
  final double? maxValue;
  final Color mainColor;
  final double timeDisplayed;
  final double lineWidth;

  final List<_GraphPoint> initialData;

  final List<_GraphPoint> _currentData;

  final int maxHistoricalPoints;
  final bool enableScrolling;
  final double maxTime;
  final int selectedIndex;
  final Function(int) onIndexChanged;

  set currentData(List<_GraphPoint> data) => _currentData
    ..clear()
    ..addAll(data);

  const _ArrayGraphWidgetGraph({
    required this.initialData,
    required this.subscription,
    required this.timeDisplayed,
    required this.mainColor,
    required this.lineWidth,
    required this.enableScrolling,
    required this.maxHistoricalPoints,
    required this.maxTime,
    required this.selectedIndex,
    required this.onIndexChanged,
    this.minValue,
    this.maxValue,
  }) : _currentData = initialData;

  List<_GraphPoint> getCurrentData() {
    return _currentData;
  }

  @override
  State<_ArrayGraphWidgetGraph> createState() => _ArrayGraphWidgetGraphState();
}

class _ArrayGraphWidgetGraphState extends State<_ArrayGraphWidgetGraph>
    with WidgetsBindingObserver {
  late List<_GraphPoint> _graphData;
  late List<_GraphPoint> _allHistoricalData;
  StreamSubscription<Object?>? _subscriptionListener;

  // Time scrolling variables
  double _timeScrollPosition = 0.0;
  bool _isLiveMode = true;
  Timer? _liveUpdateTimer;

  int _arrayLength = 0;

  List<List<MapEntry<String, dynamic>>> lists = [];
  List<String> names = [];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _graphData = List.of(widget.initialData);
    _allHistoricalData = List.of(widget.initialData);

    if (_graphData.length < 2) {
      final double x = DateTime.now().microsecondsSinceEpoch.toDouble();
      final double y = _getValueFromArray(widget.subscription?.value);

      _graphData = [
        _GraphPoint(x: x - widget.timeDisplayed * 1e6, y: y),
        _GraphPoint(x: x, y: y),
      ];
      _allHistoricalData = List.of(_graphData);
    }

    widget.currentData = _graphData;

    _initializeListener();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscriptionListener?.cancel();
    _liveUpdateTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(_ArrayGraphWidgetGraph oldWidget) {
    if (oldWidget.subscription != widget.subscription) {
      _resetGraphData();
      _subscriptionListener?.cancel();
      _initializeListener();
    }

    super.didUpdateWidget(oldWidget);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (widget.subscription?.value == null) {
      return;
    }
    if (state == AppLifecycleState.resumed) {
      logger.debug(
        "State resumed, refreshing graph for ${widget.subscription?.topic}",
      );
      setState(() {});
    }
  }

  double _getValueFromArray(Object? data) {
    if (data != null && data is List) {
      _arrayLength = data.length;
      if (widget.selectedIndex < data.length) {
        final value = data[widget.selectedIndex];
        return tryCast<num>(value)?.toDouble() ?? widget.minValue ?? 0.0;
      }
    }

    if (lists.isNotEmpty) {
      int currentCount = 0;
      for (List<MapEntry<String, dynamic>> group in lists) {
        if (widget.selectedIndex < currentCount + group.length) {
          int indexInGroup = widget.selectedIndex - currentCount;
          var value = group[indexInGroup].value;
          return tryCast<num>(value)?.toDouble() ?? widget.minValue ?? 0.0;
        }
        currentCount += group.length;
      }
    }

    return widget.minValue ?? 0.0;
  }

  void _resetGraphData() {
    final double x = DateTime.now().microsecondsSinceEpoch.toDouble();
    final double y = _getValueFromArray(widget.subscription?.value);

    setState(() {
      _graphData
        ..clear()
        ..addAll([
          _GraphPoint(
            x: x - widget.timeDisplayed * 1e6,
            y: y,
          ),
          _GraphPoint(x: x, y: y),
        ]);

      _allHistoricalData = List.of(_graphData);
      _timeScrollPosition = 0.0;
      _isLiveMode = true;

      widget.currentData = _graphData;
    });
  }

  void _initializeListener() {
    _subscriptionListener?.cancel();
    _subscriptionListener =
        widget.subscription?.periodicStream(yieldAll: true).listen((data) {
      if (data != null) {
        final double time = DateTime.now().microsecondsSinceEpoch.toDouble();
        final double y = _getValueFromArray(data);

        final _GraphPoint newPoint = _GraphPoint(x: time, y: y);

        _allHistoricalData.add(newPoint);

        final double maxTimeInMicroseconds = 2.5 * 60 * 1e6;
        final double cutoffTime = time - maxTimeInMicroseconds;

        _allHistoricalData.removeWhere((point) => point.x < cutoffTime);

        List<String> nameGroups = widget.subscription!.topic.split("/").last.split(" | ");
        lists.clear();
        int c = 0;
        for (String nameGroup in nameGroups){
          String groupName = nameGroup.split(":")[0];
          names.add(groupName);
          
          String content = nameGroup.split(": ")[1];
          List<String> itemNames = content.split(", ");
          List<MapEntry<String, dynamic>> currentGroupEntries = [];
          for (String itemName in itemNames) {
            var value = tryCast<List<dynamic>>(data)![c];
            currentGroupEntries.add(MapEntry(itemName, value));
            c++;
          }
          lists.add(currentGroupEntries);
        }

        // Update visible data only if in live mode
        if (_isLiveMode) {
          _updateVisibleData();
        }
      } else if (_graphData.length > 2) {
        _resetGraphData();
      }

      widget.currentData = _graphData;
    });
  }

  void _updateVisibleData() {
    if (_allHistoricalData.isEmpty) return;

    final double currentTime = DateTime.now().microsecondsSinceEpoch.toDouble();
    final double timeWindow = widget.timeDisplayed * 1e6;

    double windowEndTime;
    if (_isLiveMode) {
      windowEndTime = currentTime;
    } else {
      final double oldestTime = _allHistoricalData.first.x;
      final double newestTime = _allHistoricalData.last.x;
      final double totalTimeSpan = newestTime - oldestTime;

      if (totalTimeSpan <= timeWindow) {
        windowEndTime = newestTime;
      } else {
        windowEndTime =
            newestTime - (_timeScrollPosition * (totalTimeSpan - timeWindow));
      }
    }

    final double windowStartTime = windowEndTime - timeWindow;

    final List<_GraphPoint> displayData = _allHistoricalData
        .where((point) => point.x >= windowStartTime && point.x <= windowEndTime)
        .toList();

    if (displayData.isEmpty) return;

    if (displayData.first.x > windowStartTime) {
      displayData.insert(
          0,
          _GraphPoint(
            x: windowStartTime,
            y: displayData.first.y,
          ));
    }

    if (displayData.last.x < windowEndTime) {
      displayData.add(_GraphPoint(
        x: windowEndTime,
        y: displayData.last.y,
      ));
    }

    setState(() {
      _graphData = displayData;
    });
  }

  void _onTimeScrollChanged(double value) {
    setState(() {
      _timeScrollPosition = value;
      _isLiveMode = value == 0.0;
    });

    _updateVisibleData();
  }

  void _goToLiveMode() {
    setState(() {
      _timeScrollPosition = 0.0;
      _isLiveMode = true;
    });
    _updateVisibleData();
  }

  List<FastLineSeries<_GraphPoint, num>> _getChartData() {
    return <FastLineSeries<_GraphPoint, num>>[
      FastLineSeries<_GraphPoint, num>(
        animationDuration: 0.0,
        animationDelay: 0.0,
        sortingOrder: SortingOrder.ascending,
        color: widget.mainColor,
        width: widget.lineWidth,
        dataSource: _graphData,
        xValueMapper: (value, index) {
          return value.x;
        },
        yValueMapper: (value, index) {
          return value.y;
        },
        sortFieldValueMapper: (datum, index) {
          return datum.x;
        },
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Index selector dropdown
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Row(
            children: [
              const Text('Index: ', style: TextStyle(fontSize: 12)),
              Expanded(
                child: DropdownButton<int>(
                  value: widget.selectedIndex < _arrayLength
                      ? widget.selectedIndex
                      : (_arrayLength > 0 ? 0 : null),
                  isExpanded: true,
                  isDense: true,
                  hint: const Text('Choose Index'),
                  items: _arrayLength > 0
                    ? List.generate(
                        _arrayLength,
                        (index) {
                          String label = "Index $index";
                          int count = 0;
                          
                          for (int i = 0; i < lists.length; i++) {
                            if (index < count + lists[i].length) {
                              int subIndex = index - count;
                              
                              String groupName = i < names.length ? names[i] : "";
                              String itemKey = lists[i][subIndex].key;
                              
                              label = groupName + itemKey; 
                              break;
                            }
                            count += lists[i].length;
                          }

                          return DropdownMenuItem<int>(
                            value: index,
                            child: Text('$label:'),
                          );
                        },
                      )
                    : null,
                  onChanged: (value) {
                    if (value != null) {
                      widget.onIndexChanged(value);
                      _resetGraphData();
                    }
                  },
                ),
              ),
            ],
          ),
        ),

        // Chart
        Expanded(
          child: SfCartesianChart(
            zoomPanBehavior: ZoomPanBehavior(
              enablePanning: true,
              enablePinching: true,
              zoomMode: ZoomMode.x,
            ),
            series: _getChartData(),
            margin: const EdgeInsets.only(top: 8.0),
            primaryXAxis: NumericAxis(
              labelStyle: const TextStyle(color: Colors.transparent),
              desiredIntervals: 5,
            ),
            primaryYAxis: NumericAxis(
              minimum: widget.minValue,
              maximum: widget.maxValue,
            ),
          ),
        ),

        // Time scrolling controls
        if (widget.enableScrolling && _allHistoricalData.isNotEmpty)
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxHeight >= 80) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 2),
                    Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 1, vertical: 1),
                      child: Row(
                        children: [
                          const Icon(Icons.history, size: 10),
                          Expanded(
                            child: Slider(
                              value: _timeScrollPosition,
                              min: 0.0,
                              max: 1.0,
                              divisions: 100,
                              onChanged: _onTimeScrollChanged,
                            ),
                          ),
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: IconButton(
                              icon: const Icon(Icons.skip_next),
                              onPressed: _goToLiveMode,
                              tooltip: 'Go to Live',
                              iconSize: 10,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      height: 12,
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: _isLiveMode
                                  ? Colors.green.shade100
                                  : Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: Text(
                              _isLiveMode ? 'LIVE' : 'HIST',
                              style: TextStyle(
                                fontSize: 6,
                                color: _isLiveMode
                                    ? Colors.green.shade800
                                    : Colors.orange.shade800,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              } else {
                return const SizedBox.shrink();
              }
            },
          ),
      ],
    );
  }
}

class _GraphPoint {
  final double x;
  final double y;

  const _GraphPoint({required this.x, required this.y});
}