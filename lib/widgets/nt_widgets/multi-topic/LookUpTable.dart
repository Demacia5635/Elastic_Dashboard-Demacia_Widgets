import 'package:dot_cast/dot_cast.dart';
import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';

class LookUpTableModel extends MultiTopicNTWidgetModel {
  @override
  String type = LookUpTableWidget.widgetType;

  String get tableTopic => '$topic/LUP';
  String get typeTopic => '$topic/.type';

  late NT4Subscription tableSubscription;
  late NT4Subscription typeSubscription;

  @override
  List<NT4Subscription> get subscriptions =>
      [tableSubscription, typeSubscription];

  LookUpTableModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    super.period,
    super.dataType,
  }) : super();

  LookUpTableModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required super.jsonData,
  }) : super.fromJson();

  @override
  void initializeSubscriptions() {
    tableSubscription = ntConnection.subscribe(tableTopic, super.period);
    typeSubscription = ntConnection.subscribe(typeTopic, super.period);

    // Publish the widget type so it gets recorded
    _publishWidgetType();
  }

  void _publishWidgetType() {
    ntConnection.updateDataFromTopic(
      NT4Topic(
        name: typeTopic,
        type: NT4TypeStr.kString,
        properties: {},
      ),
      LookUpTableWidget.widgetType,
    );
  }
}

class LookUpTableWidget extends NTWidget {
  static const String widgetType = 'LookUpTable';

  const LookUpTableWidget({super.key}) : super();

  @override
  Widget build(BuildContext context) {
    LookUpTableModel model = cast(context.watch<NTWidgetModel>());

    return ValueListenableBuilder(
      valueListenable: model.tableSubscription,
      builder: (context, data, child) {
        Map<String, List<double>> table = {};

        if (data != null && data is String) {
          try {
            Map<String, dynamic> jsonData = jsonDecode(data);
            jsonData.forEach((key, value) {
              if (value is List) {
                table[key] = value.map((e) => (e as num).toDouble()).toList();
              }
            });
          } catch (e) {
            print('Error parsing table: $e');
          }
        }

        return LookUpTableDisplay(
          model: model,
          initialTable: table,
        );
      },
    );
  }
}

class LookUpTableDisplay extends StatefulWidget {
  final LookUpTableModel model;
  final Map<String, List<double>> initialTable;

  const LookUpTableDisplay({
    super.key,
    required this.model,
    required this.initialTable,
  });

  @override
  State<LookUpTableDisplay> createState() => _LookUpTableDisplayState();
}

class _LookUpTableDisplayState extends State<LookUpTableDisplay> {
  late Map<String, List<double>> table;
  final TextEditingController keyController = TextEditingController();
  final TextEditingController valueController = TextEditingController();

  @override
  void initState() {
    super.initState();
    table = Map.from(widget.initialTable);
  }

  @override
  void didUpdateWidget(LookUpTableDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTable != oldWidget.initialTable) {
      setState(() {
        table = Map.from(widget.initialTable);
      });
    }
  }

  bool isSameLen(List<double> value) {
    if (table.isEmpty) return true;
    return value.length == table.values.first.length;
  }

  void addOrUpdate() {
    final key = keyController.text.trim();
    final valueText = valueController.text.trim();
    if (key.isEmpty || valueText.isEmpty) return;

    List<double> value;
    String cleanText = valueText.replaceAll(RegExp(r'[\[\]]'), '').trim();
    List<String> parts = cleanText.split(',').map((e) => e.trim()).toList();

    try {
      value = parts.map(double.parse).toList();
    } catch (_) {
      _showError('Invalid array format');
      return;
    }

    if (!isSameLen(value)) {
      if (table.isNotEmpty && value.length < table.values.first.length) {
        while (value.length < table.values.first.length) {
          value.add(0);
        }
      } else {
        _showError('Value must have the same length as existing entries');
        return;
      }
    }

    setState(() => table[key] = value);
    _publishTable();

    keyController.clear();
    valueController.clear();
  }

  void deleteEntry(String key) {
    setState(() => table.remove(key));
    _publishTable();
  }

  void _publishTable() {
    String jsonString = jsonEncode(table);
    widget.model.ntConnection.updateDataFromTopic(
      NT4Topic(
        name: widget.model.tableTopic,
        type: NT4TypeStr.kString,
        properties: {},
      ),
      jsonString,
    );
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: Duration(seconds: 2)),
      );
    }
  }

  String formatValue(List<double> value) {
    return '[${value.map((e) => e.toStringAsFixed(2)).join(', ')}]';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(8),
          child: Text(
            "Look-up Table",
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),

        // Input section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Column(
            children: [
              TextField(
                controller: keyController,
                decoration: const InputDecoration(
                  labelText: "Key (number)",
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: valueController,
                decoration: const InputDecoration(
                  labelText: "Values (e.g., 1.5, 2.3, 4.0)",
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: addOrUpdate,
                  child: const Text("Add/Update"),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Table entries
        Expanded(
          child: table.isEmpty
              ? Center(
                  child: Text(
                    "No entries yet",
                    style: TextStyle(color: Theme.of(context).hintColor),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  itemCount: table.entries.length,
                  itemBuilder: (context, index) {
                    final entry = table.entries.elementAt(index);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        dense: true,
                        title: Text(
                          'Key: ${entry.key}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(formatValue(entry.value)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => deleteEntry(entry.key),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    keyController.dispose();
    valueController.dispose();
    super.dispose();
  }
}
