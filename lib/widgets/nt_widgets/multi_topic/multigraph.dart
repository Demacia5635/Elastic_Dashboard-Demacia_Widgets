import 'dart:math' as math;

import 'package:dot_cast/dot_cast.dart';
import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// MODEL
class MultiGraphModel extends MultiTopicNTWidgetModel {
  @override
  String type = MultiGraphWidget.widgetType;

  // רשימת ה-subs הממשית
  final List<NT4Subscription> _subscriptions = [];

  @override
  List<NT4Subscription> get subscriptions => _subscriptions;

  MultiGraphModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    super.period,
    String dataType = '',
  }) : super();

  MultiGraphModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required super.jsonData,
  }) : super.fromJson();

  /// מפענח את ה-topic הבסיסי לרשימת טופיקים:
  /// "[a, b, c]" או "a,b,c" -> ["a","b","c"]
  List<String> _parseTopics() {
    String raw = topic.trim();
    if (raw.isEmpty) return [];

    if (raw.startsWith('[') && raw.endsWith(']')) {
      raw = raw.substring(1, raw.length - 1);
    }

    return raw
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  @override
  void initializeSubscriptions() {
    _subscriptions.clear();

    final topicNames = _parseTopics();
    for (final name in topicNames) {
      final sub = ntConnection.subscribe(name, period);
      _subscriptions.add(sub);
    }
  }
}

/// VIEW
class MultiGraphWidget extends NTWidget {
  static const String widgetType = 'MultiGraph';

  const MultiGraphWidget({super.key}) : super();

  @override
  Widget build(BuildContext context) {
    final MultiGraphModel model = cast(context.watch<NTWidgetModel>());
    return _MultiGraphDisplay(model: model);
  }
}

class _MultiGraphDisplay extends StatefulWidget {
  final MultiGraphModel model;

  const _MultiGraphDisplay({super.key, required this.model});

  @override
  State<_MultiGraphDisplay> createState() => _MultiGraphDisplayState();
}

class _MultiGraphDisplayState extends State<_MultiGraphDisplay> {
  static const int maxSamples = 300;

  /// history[topicName] = list of values over time
  final Map<String, List<double>> history = {};

  final List<VoidCallback> _listeners = [];

  List<NT4Subscription> get _subs => widget.model.subscriptions;

  @override
  void initState() {
    super.initState();
    _attachListeners();
  }

  @override
  void didUpdateWidget(covariant _MultiGraphDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!identical(oldWidget.model, widget.model)) {
      _detachListeners(oldWidget.model.subscriptions);
      history.clear();
      _attachListeners();
    }
  }

  void _attachListeners() {
    for (final sub in _subs) {
      final String seriesName = sub.topic; // אצלך topic הוא String

      history[seriesName] = [];

      void listener() {
        final value = sub.value;
        if (value is num) {
          setState(() {
            final list = history[seriesName]!;
            list.add(value.toDouble());
            if (list.length > maxSamples) {
              list.removeAt(0);
            }
          });
        }
      }

      sub.addListener(listener);
      _listeners.add(listener);
    }
  }

  void _detachListeners(List<NT4Subscription> subs) {
    for (int i = 0; i < subs.length && i < _listeners.length; i++) {
      subs[i].removeListener(_listeners[i]);
    }
    _listeners.clear();
  }

  @override
  void dispose() {
    _detachListeners(_subs);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_subs.isEmpty) {
      return const Center(child: Text('No topics configured'));
    }

    return Container(
      padding: const EdgeInsets.all(8),
      child: CustomPaint(
        painter: _MultiGraphPainter(history),
        child: Container(),
      ),
    );
  }
}

/// הציור של הגרף
class _MultiGraphPainter extends CustomPainter {
  final Map<String, List<double>> history;

  final List<Color> colors = const [
    Colors.red,
    Colors.green,
    Colors.blue,
    Colors.orange,
    Colors.purple,
    Colors.cyan,
    Colors.amber,
  ];

  _MultiGraphPainter(this.history);

  @override
  void paint(Canvas canvas, Size size) {
    // רקע קל
    final bgPaint = Paint()..color = Colors.black12;
    canvas.drawRect(Offset.zero & size, bgPaint);

    int seriesIndex = 0;

    for (final entry in history.entries) {
      final values = entry.value;
      if (values.length < 2) {
        seriesIndex++;
        continue;
      }

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = colors[seriesIndex % colors.length];

      final double minVal =
          values.reduce((a, b) => math.min(a, b));
      final double maxVal =
          values.reduce((a, b) => math.max(a, b));

      double range = maxVal - minVal;
      if (range.abs() < 1e-9) {
        range = 1; // כל הערכים אותו דבר
      }

      final double dx = size.width / (values.length - 1);
      final path = Path();

      for (int i = 0; i < values.length; i++) {
        final double x = i * dx;
        final double norm = (values[i] - minVal) / range;
        final double y = size.height * (1 - norm);

        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      canvas.drawPath(path, paint);

      seriesIndex++;
    }
  }

  @override
  bool shouldRepaint(covariant _MultiGraphPainter oldDelegate) => true;
}
