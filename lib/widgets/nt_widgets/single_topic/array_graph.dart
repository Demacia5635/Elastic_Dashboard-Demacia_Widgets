import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dot_cast/dot_cast.dart';
import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ArrayGraphModel extends SingleTopicNTWidgetModel {
  static const String widgetType = 'Array Graph';

  int index = 0;
  final List<double> history = [];
  static const int maxSamples = 300;

  ArrayGraphModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    super.period,
    super.dataType,
  }) : super();

  ArrayGraphModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required Map<String, dynamic> jsonData,
  }) : super.fromJson(jsonData: jsonData) {
    index = (jsonData['index'] as num?)?.toInt() ?? 0;
  }

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'index': index,
      };

  @override
  bool get hasEditableProperties => true;

  @override
  void initializeSubscriptions() {
    history.clear();

    // חשוב: ליצור subscription ידנית
    subscription = ntConnection.subscribe(topic, period);

    subscription!.addListener(() {
      final v = subscription!.value;
      final list = _asNumList(v);
      if (list == null || list.isEmpty) return;

      if (index >= list.length) {
        index = math.max(0, list.length - 1);
      }

      history.add(list[index]);
      if (history.length > maxSamples) {
        history.removeAt(0);
      }
      notifyListeners();
    });
  }

  List<double>? _asNumList(dynamic v) {
    if (v == null) return null;

    if (v is Float64List) return v.map((e) => e.toDouble()).toList();
    if (v is Float32List) return v.map((e) => e.toDouble()).toList();
    if (v is Int32List) return v.map((e) => e.toDouble()).toList();
    if (v is Int64List) return v.map((e) => e.toDouble()).toList();

    if (v is List) {
      final out = <double>[];
      for (final e in v) {
        if (e is num) out.add(e.toDouble());
      }
      return out.isEmpty ? null : out;
    }

    if (v is Iterable) {
      final out = <double>[];
      for (final e in v) {
        if (e is num) out.add(e.toDouble());
      }
      return out.isEmpty ? null : out;
    }

    return null;
  }

  @override
  List<Widget> getEditProperties(BuildContext context) {
    // אין לנו גישה לאורך המערך תמיד, אז נותנים טווח סביר
    return [
      Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Array Index',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Slider(
              value: index.toDouble(),
              min: 0,
              max: 10,
              divisions: 10,
              label: '$index',
              onChanged: (v) {
                index = v.toInt();
                history.clear();
                notifyListeners();
              },
            ),
            const Text('Change index, then watch the graph update'),
          ],
        ),
      ),
    ];
  }
}

class ArrayGraphWidget extends NTWidget {
  const ArrayGraphWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final ArrayGraphModel model = cast(context.watch<NTWidgetModel>());

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(6),
          child: Text('Index: ${model.index}'),
        ),
        Expanded(
          child: CustomPaint(
            painter: _ArrayGraphPainter(model.history),
          ),
        ),
      ],
    );
  }
}

class _ArrayGraphPainter extends CustomPainter {
  final List<double> values;

  _ArrayGraphPainter(this.values);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Colors.black12,
    );

    if (values.length < 2) return;

    final minVal = values.reduce(math.min);
    final maxVal = values.reduce(math.max);
    double range = maxVal - minVal;
    if (range.abs() < 1e-9) range = 1;

    final p = Paint()
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..color = Colors.cyanAccent;

    final path = Path();
    final dx = size.width / (values.length - 1);

    for (int i = 0; i < values.length; i++) {
      final x = i * dx;
      final y = size.height * (1 - ((values[i] - minVal) / range));
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant _ArrayGraphPainter oldDelegate) => true;
}
