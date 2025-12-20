import 'dart:async';

import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class ArrayListModel extends SingleTopicNTWidgetModel {
  @override
  String type = ArrayListWidget.widgetType;

  late Color _mainColor;
  int _selectedIndex = 0;
  List<String> keyOrder = [];

  Color get mainColor => _mainColor;

  int get selectedIndex => _selectedIndex;

  set selectedIndex(int value) {
    _selectedIndex = value;
    refresh();
  }

  ArrayListModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    Color mainColor = const Color(0xFF353535),
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
    _mainColor = Color(tryCast(jsonData['color']) ?? 0xFF353535);
    _selectedIndex = tryCast(jsonData['selected_index']) ?? 0;
    keyOrder = List<String>.from(tryCast(jsonData['key_order']) ?? []);
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'color': _mainColor.toARGB32(),
      'selected_index': _selectedIndex,
      'key_order': keyOrder,
    };
  }

  void updateKeys(List<String> newKeys) {
    bool changed = false;
    for (String key in newKeys) {
      if (!keyOrder.contains(key)) {
        keyOrder.add(key);
        changed = true;
      }
    }
    if (changed) {
      // Implicitly save state
    }
  }

  @override
  List<Widget> getEditProperties(BuildContext context) {
    return [
      Center(
        child: ElevatedButton(
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => _ReorderKeysDialog(model: this),
            );
          },
          child: const Text("Order Fields"),
        ),
      ),
    ];
  }
}

// --- Dialog for Reordering Keys ---
class _ReorderKeysDialog extends StatefulWidget {
  final ArrayListModel model;

  const _ReorderKeysDialog({required this.model});

  @override
  State<_ReorderKeysDialog> createState() => _ReorderKeysDialogState();
}

class _ReorderKeysDialogState extends State<_ReorderKeysDialog> {
  late List<String> _currentOrder;

  @override
  void initState() {
    super.initState();
    _currentOrder = List.from(widget.model.keyOrder);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Order Fields"),
      content: SizedBox(
        width: 300,
        height: 400,
        child: ReorderableListView(
          onReorder: (oldIndex, newIndex) {
            setState(() {
              if (oldIndex < newIndex) {
                newIndex -= 1;
              }
              final String item = _currentOrder.removeAt(oldIndex);
              _currentOrder.insert(newIndex, item);
            });
          },
          children: [
            for (int i = 0; i < _currentOrder.length; i++)
              ListTile(
                key: ValueKey(_currentOrder[i]),
                title: Text(_currentOrder[i]),
                leading: const Icon(Icons.drag_handle),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text("Cancel"),
        ),
        TextButton(
          onPressed: () {
            widget.model.keyOrder = _currentOrder;
            widget.model.refresh();
            Navigator.of(context).pop();
          },
          child: const Text("Save"),
        ),
      ],
    );
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
      model: model,
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
  final ArrayListModel model;
  final Function(int) onIndexChanged;

  const _ArrayListWidgetGraph({
    required this.subscription,
    required this.mainColor,
    required this.selectedIndex,
    required this.model,
    required this.onIndexChanged,
  });

  @override
  State<_ArrayListWidgetGraph> createState() => _ArrayListWidgetGraphState();
}

class _ArrayListWidgetGraphState extends State<_ArrayListWidgetGraph> {
  StreamSubscription<Object?>? _subscriptionListener;
  final SearchController _searchController = SearchController();

  List<List<MapEntry<String, dynamic>>> lists = [];
  List<String> names = [];

  @override
  void initState() {
    super.initState();
    
    if (widget.subscription?.value != null) {
      _parseData(widget.subscription!.value);
    }

    _initializeListener();
  }

  @override
  void dispose() {
    _subscriptionListener?.cancel();
    _searchController.dispose();
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

  void _parseData(Object? data) {
    if (data == null) return;

    List<String> nameGroups =
        widget.subscription!.topic.split("/").last.split(" | ");
    
    List<List<MapEntry<String, dynamic>>> newLists = [];
    List<String> newNames = [];

    int c = 0;
    List<String> foundKeys = [];

    for (String nameGroup in nameGroups) {
      String groupName = nameGroup.split(":")[0];
      newNames.add(groupName);

      String content = nameGroup.split(": ")[1];
      List<String> itemNames = content.split(", ");
      List<MapEntry<String, dynamic>> currentGroupEntries = [];

      for (String itemName in itemNames) {
        if (tryCast<List<dynamic>>(data)!.length > c) {
          var value = tryCast<List<dynamic>>(data)![c];
          currentGroupEntries.add(MapEntry(itemName, value));
          foundKeys.add(itemName);
        }
        c++;
      }

      currentGroupEntries.sort((a, b) {
        int indexA = widget.model.keyOrder.indexOf(a.key);
        int indexB = widget.model.keyOrder.indexOf(b.key);

        if (indexA == -1) indexA = 999;
        if (indexB == -1) indexB = 999;

        return indexA.compareTo(indexB);
      });

      newLists.add(currentGroupEntries);
    }

    widget.model.updateKeys(foundKeys);
    
    lists = newLists;
    names = newNames;
  }

  void _initializeListener() {
    _subscriptionListener?.cancel();
    _subscriptionListener =
        widget.subscription?.periodicStream(yieldAll: true).listen((data) {
      if (data != null) {
        _parseData(data);
        if (mounted) setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Row(
            children: [
              const Text('Index: ', style: TextStyle(fontSize: 12)),
              Expanded(
                child: SearchAnchor(
                  searchController: _searchController,
                  viewBackgroundColor: const Color(0xFF1E1E1E),
                  viewHintText: 'Search groups...',
                  headerTextStyle: const TextStyle(color: Colors.white),
                  
                  builder: (BuildContext context, SearchController controller) {
                    return InkWell(
                      onTap: () {
                        controller.clear(); 
                        controller.openView();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 0.0, vertical: 4.0),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.white,
                              width: 1.0,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(right: 8.0),
                              child: Icon(Icons.search, 
                                  color: Colors.white70, size: 16),
                            ),
                            Expanded(
                              child: Text(
                                widget.selectedIndex < names.length
                                    ? names[widget.selectedIndex]
                                    : (lists.isNotEmpty
                                        ? "Select Group..."
                                        : "No Data"),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(Icons.arrow_drop_down,
                                color: Colors.white),
                          ],
                        ),
                      ),
                    );
                  },
                  
                  suggestionsBuilder:
                      (BuildContext context, SearchController controller) {
                    final keyword = controller.text.toLowerCase();

                    final List<String> matchingNames = names
                        .where((name) => name.toLowerCase().contains(keyword))
                        .toList();

                    return matchingNames.map((String item) {
                      final int originalIndex = names.indexOf(item);

                      return ListTile(
                        title: Text(item,
                            style: const TextStyle(color: Colors.white)),
                        onTap: () {
                          setState(() {
                            widget.onIndexChanged(originalIndex);
                            controller.closeView(item);
                          });
                        },
                      );
                    }).toList();
                  },
                ),
              ),
            ],
          ),
        ),

        // --- DATA DISPLAY ---
        Expanded(
          child: lists.isNotEmpty && widget.selectedIndex < lists.length
              ? ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: lists[widget.selectedIndex].length,
                  itemBuilder: (context, index) {
                    final pair = lists[widget.selectedIndex][index];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12.0, vertical: 10.0),
                        decoration: BoxDecoration(
                          color: const Color(0xFF353535),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white12, width: 0.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pair.key,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              tryCast<num>(pair.value)?.toStringAsFixed(2) ??
                                  pair.value.toString(),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[300],
                              ),
                            ),
                          ],
                        ),
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