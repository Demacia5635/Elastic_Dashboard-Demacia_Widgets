import 'package:dot_cast/dot_cast.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/models/widget_container_model.dart';
import 'package:flutter/material.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import 'package:provider/provider.dart';

class LookUpTableModel extends SingleTopicNTWidgetModel {
  @override
  String type = 'LookUpTable';

  LookUpTableModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    super.dataType,
    super.period,
  }) : super();

  LookUpTableModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required Map<String, dynamic> jsonData,
  }) : super.fromJson(jsonData: jsonData);

  @override
  void init() {
    super.init();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void disposeWidget({bool deleting = false}) {}

  @override
  List<String> getAvailableDisplayTypes() => ['Default'];

  @override
  void resetSubscription() {}

  @override
  void unSubscribe() {}
}

class LookUpTableWidget extends NTWidget {
  static const String widgetType = 'LookUpTable';
  late LookUpTableModel model;

  LookUpTableWidget({Key? key}) : super(key: key) {
    //model = LookUpTableModel(ntConnection: ); //WidgetContainerModel as LookUpTableModel;
  }

  @override
  Widget build(BuildContext context) {
    model = cast(context.watch<NTWidgetModel>());
    return LookUpTableDisplay(model: model);
  }
}


class LookUpTableDisplay extends StatefulWidget {
  final LookUpTableModel model;

  const LookUpTableDisplay({super.key, required this.model});

  @override
  State<LookUpTableDisplay> createState() => _LookUpTableDisplayState();
}

class _LookUpTableDisplayState extends State<LookUpTableDisplay> {
  Map<String, dynamic> table = {};
  final TextEditingController keyController = TextEditingController();
  final TextEditingController valueController = TextEditingController();
  bool isArrayMode = false;

  void addOrUpdate() {
    final key = keyController.text.trim();
    final valueText = valueController.text.trim();
    if (key.isEmpty || valueText.isEmpty) return;

    dynamic value;
    if (isArrayMode) {
      String cleanText = valueText.replaceAll(RegExp(r'[\[\]]'), '').trim();
      List<String> parts = cleanText.split(',').map((e) => e.trim()).toList();
      try {
        value = parts.map(double.parse).toList();
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid array format'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }
    } else {
      try {
        value = double.parse(valueText);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid number format'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }
    }

    setState(() => table[key] = value);

    // שליחה ל-NT
    widget.model.ntConnection.updateDataFromTopic(
      NT4Topic(
        name: '${widget.model.topic}/table',
        type: NT4TypeStr.kString,
        properties: {},
      ),
      table,
    );

    keyController.clear();
    valueController.clear();
  }

  void deleteEntry(String key) {
    setState(() => table.remove(key));

    widget.model.ntConnection.updateDataFromTopic(
      NT4Topic(
        name: '${widget.model.topic}/table',
        type: NT4TypeStr.kString,
        properties: {},
      ),
      table,
    );
  }

  String formatValue(dynamic value) {
    if (value is List) return value.map((e) => e.toString()).join(', ');
    return value.toString();
  }

@override
Widget build(BuildContext context) {
  return Column(
    children: [
      // Header - קבוע למעלה
      Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 4), // הקטנתי את הpadding התחתון
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Look-up Table",
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4), // הקטנתי מ-8 ל-4
            Row(
              children: [
                Text(
                  isArrayMode ? "Array Mode" : "Single Value Mode",
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: isArrayMode,
                  onChanged: (v) => setState(() => isArrayMode = v),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ],
        ),
      ),
      
      // Scrollable content
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Column(
            children: [
              TextField(
                controller: keyController,
                decoration: const InputDecoration(
                  labelText: "Key",
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 6), // הקטנתי
                ),
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: valueController,
                decoration: InputDecoration(
                  labelText:
                      isArrayMode ? "Array (e.g., 1,2,3,4)" : "Value (double)",
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6), // הקטנתי
                ),
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 6), // הקטנתי מ-8
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: addOrUpdate,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 6), // הקטנתי
                  ),
                  child: const Text(
                    "Add/Update",
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              
              // List of entries
              if (table.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text(
                    "No entries yet",
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).hintColor,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: table.entries.length,
                  itemBuilder: (context, index) {
                    final entry = table.entries.elementAt(index);
                    final isArray = entry.value is List;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Theme.of(context).dividerColor,
                          width: 0.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isArray ? Icons.list : Icons.numbers,
                                size: 14,
                                color:
                                    isArray ? Colors.blue : Colors.green,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  entry.key,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              InkWell(
                                onTap: () => deleteEntry(entry.key),
                                child: const Icon(
                                  Icons.delete_outline,
                                  size: 16,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color:
                                  Theme.of(context).colorScheme.background,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              formatValue(entry.value),
                              style: TextStyle(
                                fontSize: 10,
                                fontFamily: 'Courier',
                                color: isArray
                                    ? Colors.blue.shade700
                                    : Colors.green.shade700,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
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