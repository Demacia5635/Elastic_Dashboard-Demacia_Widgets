import 'dart:math' as math;

import 'package:dot_cast/dot_cast.dart';
import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// =============================
///        MODEL
/// =============================
class ArrayIndexGraphModel extends SingleTopicNTWidgetModel {
  static const String widgetType = 'ArrayIndexGraph';

  int index = 0;
  int arrayLength = 0; // 🔥 אורך המערך בפועל

  final List<double> history = [];
  static const int maxSamples = 200;

  ArrayIndexGraphModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    super.period,
    super.dataType,
  });

  ArrayIndexGraphModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required Map<String, dynamic> jsonData,
  }) : super.fromJson(jsonData: jsonData) {
    index = jsonData['index'] ?? 0;
  }

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'index': index,
      };

  @override
  bool get hasEditableProperties => true;

  /// 🔥 חובה: SingleTopic לא יוצר subscription לבד
  @override
  void initializeSubscriptions() {
    history.clear();

    subscription = ntConnection.subscribe(topic, period);

    subscription!.addListener(() {
      final value = subscription!.value;

      if (value is Iterable) {
        final list = value.toList();
        arrayLength = list.length;

        // 🔒 הגנה: index מחוץ לטווח
        if (arrayLength == 0) return;

        if (index >= arrayLength) {
          index = arrayLength - 1;
          history.clear();
        }

        if (list[index] is num) {
          history.add((list[index] as num).toDouble());

          if (history.length > maxSamples) {
            history.removeAt(0);
          }

          notifyListeners();
        }
      }
    });
  }

  @override
    List<Widget> getEditProperties(BuildContext context) {
      final value = subscription?.value;

      final int arrayLength =
          value is Iterable ? value.length : 1;

      final int maxIndex =
          arrayLength > 0 ? arrayLength - 1 : 0;

      // הגנה אם index יצא מגבולות המערך
      index = index.clamp(0, maxIndex);

      return [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Array Index (0 – $maxIndex)',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Slider(
                value: index.toDouble(),
                min: 0,
                max: maxIndex.toDouble(),
                divisions: maxIndex > 0 ? maxIndex : null,
                label: index.toString(),
                onChanged: (v) {
                  index = v.toInt();
                  history.clear();
                  notifyListeners();
                },
              ),
            ],
          ),
        ),
      ];
    }
}

/// =============================
///        WIDGET
/// =============================
class ArrayIndexGraphWidget extends NTWidget {
  const ArrayIndexGraphWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final model = cast<ArrayIndexGraphModel>(
      context.watch<NTWidgetModel>(),
    );

    return CustomPaint(
      painter: _ArrayGraphPainter(model.history),
      size: Size.infinite,
    );
  }
}

/// =============================
///        PAINTER
/// =============================
class _ArrayGraphPainter extends CustomPainter {
  final List<double> values;

  _ArrayGraphPainter(this.values);

  @override
  void paint(Canvas canvas, Size size) {
    // רקע
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Colors.black12,
    );

    if (values.length < 2) {
      final textPainter = TextPainter(
        text: const TextSpan(
          text: 'Waiting for data…',
          style: TextStyle(color: Colors.white70),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(
          (size.width - textPainter.width) / 2,
          (size.height - textPainter.height) / 2,
        ),
      );
      return;
    }


    final minVal = values.reduce(math.min);
    final maxVal = values.reduce(math.max);
    final range =
        (maxVal - minVal).abs() < 1e-6 ? 1.0 : maxVal - minVal;

    final paint = Paint()
      ..color = Colors.cyanAccent
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    final dx = size.width / (values.length - 1);

    for (int i = 0; i < values.length; i++) {
      final x = i * dx;
      final y =
          size.height * (1 - (values[i] - minVal) / range);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ArrayGraphPainter oldDelegate) => true;
}
