import 'dart:async';

import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_color_picker.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class ArrayListModel extends SingleTopicNTWidgetModel {
  @override
  String type = ArrayListWidget.widgetType;

  late Color _mainColor;
  int _selectedIndex = 0;

  Color get mainColor => _mainColor;

  set mainColor(Color value) {
    _mainColor = value;
    refresh();
  }

  int get selectedIndex => _selectedIndex;

  set selectedIndex(int value) {
    _selectedIndex = value;
    refresh();
  }

  ArrayListModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    Color mainColor = Colors.cyan,
    int selectedIndex = 0,
    super.dataType,
    super.period,
  })  : _mainColor = mainColor,
        _selectedIndex = selectedIndex,
        super();

  ArrayListModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required Map<String, dynamic> jsonData,
  }) : super.fromJson(jsonData: jsonData) {
    _mainColor = Color(tryCast(jsonData['color']) ?? Colors.cyan.toARGB32());
    _selectedIndex = tryCast(jsonData['selected_index']) ?? 0;
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'color': _mainColor.toARGB32(),
      'selected_index': _selectedIndex,
    };
  }

  @override
  List<Widget> getEditProperties(BuildContext context) {
    return [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        mainAxisSize: MainAxisSize.max,
        children: [
          Flexible(
            child: DialogColorPicker(
              onColorPicked: (color) {
                mainColor = color;
              },
              label: 'Main Color',
              initialColor: _mainColor,
              defaultColor: Colors.cyan,
            ),
          ),
        ],
      ),
    ];
  }
}

class ArrayListWidget extends NTWidget {
  static const String widgetType = 'Array List';

  const ArrayListWidget({super.key});

  @override
  Widget build(BuildContext context) {
    ArrayListModel model = cast(context.watch<NTWidgetModel>());

    return _ArrayListWidgetGraph(
      subscription: model.subscription,
      mainColor: model.mainColor,
      selectedIndex: model.selectedIndex,
      onIndexChanged: (index) {
        model.selectedIndex = index;
      },
    );
  }
}

class _ArrayListWidgetGraph extends StatefulWidget {
  final NT4Subscription? subscription;
  final Color mainColor;
  final int selectedIndex;
  final Function(int) onIndexChanged;

  const _ArrayListWidgetGraph({
    required this.subscription,
    required this.mainColor,
    required this.selectedIndex,
    required this.onIndexChanged,
  });

  @override
  State<_ArrayListWidgetGraph> createState() => _ArrayListWidgetGraphState();
}

class _ArrayListWidgetGraphState extends State<_ArrayListWidgetGraph> {
  StreamSubscription<Object?>? _subscriptionListener;

  List<List<MapEntry<String, dynamic>>> lists = [];
  List<String> names = [];

  @override
  void initState() {
    super.initState();
    _initializeListener();
  }

  @override
  void dispose() {
    _subscriptionListener?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(_ArrayListWidgetGraph oldWidget) {
    if (oldWidget.subscription != widget.subscription) {
      _subscriptionListener?.cancel();
      _initializeListener();
    }
    super.didUpdateWidget(oldWidget);
  }

  void _initializeListener() {
    _subscriptionListener?.cancel();
    _subscriptionListener =
        widget.subscription?.periodicStream(yieldAll: true).listen((data) {
      if (data != null) {
        // Keeping your logic exactly as requested
        List<String> nameGroups =
            widget.subscription!.topic.split("/").last.split(" | ");
        lists.clear();
        names.clear(); // Clear names list too
        int c = 0;
        for (String nameGroup in nameGroups) {
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

        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // --- Header: Index Selector ---
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Row(
            children: [
              const Text('Index: ', style: TextStyle(fontSize: 12)),
              Expanded(
                child: DropdownButton<int>(
                  value: widget.selectedIndex < lists.length
                      ? widget.selectedIndex
                      : (lists.isNotEmpty ? 0 : null),
                  isExpanded: true,
                  isDense: true,
                  hint: const Text('Choose Index'),
                  items: lists.isNotEmpty
                      ? List.generate(
                          lists.length,
                          (index) => DropdownMenuItem<int>(
                            value: index,
                            child: Text(
                                '${index < names.length ? names[index] : "Group $index"}:'),
                          ),
                        )
                      : null,
                  onChanged: (value) {
                    if (value != null) {
                      widget.onIndexChanged(value);
                    }
                  },
                ),
              ),
            ],
          ),
        ),

        // --- DATA DISPLAY (Scrollable List / Form Style) ---
        Expanded(
          child: lists.isNotEmpty && widget.selectedIndex < lists.length
              ? ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: lists[widget.selectedIndex].length,
                  itemBuilder: (context, index) {
                    final pair = lists[widget.selectedIndex][index];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. The Label
                          Text(
                            pair.key,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade400,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),

                          // 2. The Value Box (Fixed size, dark background, NO underline)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10.0, vertical: 8.0),
                            decoration: const BoxDecoration(
                              color: Color(0xFF252525), // Dark background
                              // Removed border: Border(...) here!
                              borderRadius: BorderRadius.all(Radius.circular(4)), // Rounded all corners
                            ),
                            child: Text(
                              tryCast<num>(pair.value)?.toStringAsFixed(2) ??
                                  pair.value.toString(),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                )
              : const Center(
                  child: Text("Waiting for data...",
                      style: TextStyle(color: Colors.white)),
                ),
        ),
      ],
    );
  }
}