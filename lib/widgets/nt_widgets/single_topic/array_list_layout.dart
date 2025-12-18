import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// =============================
///          MODEL
/// =============================
class ArrayListModel extends SingleTopicNTWidgetModel {
  static const String widgetType = 'ArrayList';

  List<dynamic> values = const [];

  ArrayListModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    super.period,
    super.dataType,
  });

  ArrayListModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required Map<String, dynamic> jsonData,
  }) : super.fromJson(jsonData: jsonData);

  @override
  String get type => widgetType;

  @override
  bool get hasEditableProperties => false;

  @override
  bool supportsDataType(String dataType) {
    return dataType.endsWith('Arr');
  }
}

/// =============================
///          WIDGET
/// =============================
class ArrayListWidget extends NTWidget {
  static const String widgetType = 'ArrayList';

  const ArrayListWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final model = context.watch<NTWidgetModel>() as ArrayListModel;
    return _ArrayListView(model: model);
  }
}

/// =============================
///           VIEW
/// =============================
class _ArrayListView extends StatefulWidget {
  final ArrayListModel model;

  const _ArrayListView({required this.model});

  @override
  State<_ArrayListView> createState() => _ArrayListViewState();
}

class _ArrayListViewState extends State<_ArrayListView> {
  NT4Subscription? _subscription;

  @override
  void initState() {
    super.initState();

    _subscription = widget.model.subscription;

    _subscription?.listen((value, timestamp) {//[1,2,3] Smart.putNumArray("pos, vel, ang")
      if (!mounted) return;

      if (value is Iterable) {
        setState(() {
          widget.model.values = List<dynamic>.from(value);
        });
      }
    });
  }

  Widget getNames(int index, String name){
    Text text;
    final removeSlash = name.substring(16, name.length);;
    final arrayNames = removeSlash.split(',');
    if(arrayNames.length <= index){
      text = Text(
                '[$index]',
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                ),
              );
    }else{
      text = Text(
                '[${arrayNames[index]}]',
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                ),
              );
    }
    return text;
  }

  @override
  Widget build(BuildContext context) {
    final values = widget.model.values;

    if (values.isEmpty) {
      return const Center(
        child: Text(
          'Array is empty',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    return ListView.builder(
      itemCount: values.length,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF2D2D2D),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
             getNames(index, widget.model.topic),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  values[index].toString(),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
