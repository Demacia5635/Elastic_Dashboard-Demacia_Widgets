import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/text_formatter_builder.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class rollingNumberButtonModel extends MultiTopicNTWidgetModel {
  @override
  String type = rollingNumberButtonWidget.widgetType;

  String get numTopicName => '$topic/theRandomNumber';
  String get reRollNumTopicName => '$topic/reRoll';


  NT4Topic? _numTopic;
  NT4Topic? _reRollNumTopic;


  late NT4Subscription numSubscription;
  late NT4Subscription reRollNumSubscription;

  @override
  List<NT4Subscription> get subscriptions => [
        numSubscription,
        reRollNumSubscription,
      ];

  TextEditingController? numTextController;
  TextEditingController? reRollNumTextController;

  double _numLastValue = 0.0;
  double _reRollNumLastValue = 0.0;

  get numLastValue => _numLastValue;

  set numLastValue(value) => _numLastValue = value;

  get reRollNumLastValue => _reRollNumLastValue;

  set reRollNumLastValue(value) => _reRollNumLastValue = value;

  rollingNumberButtonModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    super.dataType,
    super.period,
  }) : super();

  rollingNumberButtonModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required super.jsonData,
  }) : super.fromJson();

  @override
  void initializeSubscriptions() {
    numSubscription = ntConnection.subscribe(numTopicName, super.period);
    reRollNumSubscription = ntConnection.subscribe(reRollNumTopicName, super.period);
  }

  @override
  void resetSubscription() {
    _numTopic = null;
    _reRollNumTopic = null;


    super.resetSubscription();
  }

  void publishReRollNum() {
    bool publishTopic = _reRollNumTopic == null;

    _reRollNumTopic ??= ntConnection.getTopicFromName(reRollNumTopicName);

    if (_reRollNumTopic == null ) {
      return;
    }

    if (publishTopic) {
      ntConnection.publishTopic(_reRollNumTopic!);
    }

    ntConnection.updateDataFromTopic(_reRollNumTopic!, true);
  }
}
class rollingNumberButtonWidget extends NTWidget {
  static const String widgetType = 'rolingNumberButton';

  const rollingNumberButtonWidget({super.key}) : super();

  @override
  Widget build(BuildContext context) {
    rollingNumberButtonModel model = cast(context.watch<NTWidgetModel>());

    return ListenableBuilder(
        listenable: Listenable.merge([
          ...model.subscriptions,
          model.numTextController,
          model.reRollNumTextController,
        ]),
        builder: (context, child) {
          double num = tryCast(model.numSubscription.value) ?? 0.0;
          double reRollNum = tryCast(model.reRollNumSubscription.value) ?? 0.0;

          // Creates the text editing controllers if they are null
          bool wasNull = model.numTextController == null ||
              model.reRollNumTextController == null ;

          model.numTextController ??= TextEditingController(text: num.toString());
          model.reRollNumTextController ??= TextEditingController(text: reRollNum.toString());


          // Since they were null they're not being listened to when created during build
          if (wasNull) {
            model.refresh();
          }

          // Updates the text of the text editing controller if the kp value has changed
          if (num != model.numLastValue) {
            model.numTextController!.text = num.toString();
          }
          model.numLastValue = num;

          // Updates the text of the text editing controller if the ki value has changed
          if (reRollNum != model.reRollNumLastValue) {
            model.reRollNumTextController!.text = reRollNum.toString();
          }
          model.reRollNumLastValue = num;

          TextStyle labelStyle = Theme.of(context)
              .textTheme
              .bodyLarge!
              .copyWith(fontWeight: FontWeight.bold);

          bool showWarning = num !=
                  double.tryParse(model.numTextController!.text) ||
              reRollNum != double.tryParse(model.reRollNumTextController!.text) ;

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('$num',
                    style: TextStyle(fontSize: 48),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: model.publishReRollNum, 
                child: Text("Re-Roll"),
              )
            ],
          );
        });
  }
}
