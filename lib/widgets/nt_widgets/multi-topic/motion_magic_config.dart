import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/text_formatter_builder.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class MotionMagicConfigModel extends MultiTopicNTWidgetModel {
  @override
  String type = MotionMagicConfigWidget.widgetType;

  double _velLastValue = 0.0;
  double _accLastValue = 0.0;
  double _jerkLastValue = 0.0;

  get velLastValue => _velLastValue;
  set velLastValue(value) => _velLastValue = value;
  get accLastValue => _accLastValue;
  set accLastValue(value) => _accLastValue = value;
  get jerkLastValue => _jerkLastValue;
  set jerkLastValue(value) => _jerkLastValue = value;

  TextEditingController? velTextController;
  TextEditingController? accTextController;
  TextEditingController? jerkTextController;

  NT4Topic? _velTopic;
  NT4Topic? _accTopic;
  NT4Topic? _jerkTopic;

  NT4Topic? updateMotorTopic;

  get velTopic => '$topic/Vel';
  get accTopic => '$topic/Acc';
  get jerkTopic => '$topic/Jerk';
  
  get updateMotorTopicName => '$topic/Update';

  late NT4Subscription velSubscription;
  late NT4Subscription accSubscription;
  late NT4Subscription jerkSubscription;
  late NT4Subscription updateMotorSubscription;

  @override
  List<NT4Subscription> get subscriptions => [
    velSubscription,
    accSubscription,
    jerkSubscription,
    updateMotorSubscription,
  ];

  MotionMagicConfigModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    super.period,
    super.dataType,
  }) : super();

  MotionMagicConfigModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required super.jsonData,
  }) : super.fromJson();

  @override
  void initializeSubscriptions() {
    velSubscription = ntConnection.subscribe(velTopic, super.period);
    accSubscription = ntConnection.subscribe(accTopic, super.period);
    jerkSubscription = ntConnection.subscribe(jerkTopic, super.period);
    
    updateMotorSubscription = ntConnection.subscribe(updateMotorTopicName, super.period);
  }

  @override
  void resetSubscription() {
    _velTopic = null;
    _accTopic = null;
    _jerkTopic = null;

    updateMotorTopic = null;

    for(NT4Subscription subscription in subscriptions) {
      ntConnection.unSubscribe(subscription);
    }

    initializeSubscriptions();
    super.resetSubscription();
  }

  void publishVel() {
    bool publishTopic = _velTopic == null;

    _velTopic ??= ntConnection.getTopicFromName(velTopic);

    double? data = double.tryParse(velTextController?.text ?? '');

    if (_velTopic == null || data == null) {
      return;
    }

    if (publishTopic) {
      ntConnection.publishTopic(_velTopic!);
    }

    ntConnection.updateDataFromTopic(_velTopic!, data);
  }

  void publishAcc() {
    bool publishTopic = _accTopic == null;

    _accTopic ??= ntConnection.getTopicFromName(accTopic);

    double? data = double.tryParse(accTextController?.text ?? '');

    if (_accTopic == null || data == null) {
      return;
    }

    if (publishTopic) {
      ntConnection.publishTopic(_accTopic!);
    }

    ntConnection.updateDataFromTopic(_accTopic!, data);
  }

  void publishJerk() {
    bool publishTopic = _jerkTopic == null;

    _jerkTopic ??= ntConnection.getTopicFromName(jerkTopic);

    double? data = double.tryParse(jerkTextController?.text ?? '');

    if (_jerkTopic == null || data == null) {
      return;
    }

    if (publishTopic) {
      ntConnection.publishTopic(_jerkTopic!);
    }

    ntConnection.updateDataFromTopic(_jerkTopic!, data);
  }

}

class MotionMagicConfigWidget extends NTWidget {
  static const String widgetType = "Motion Magic Config";

  const MotionMagicConfigWidget({super.key});

  @override
  Widget build(BuildContext context) {
    MotionMagicConfigModel model = cast(context.watch<NTWidgetModel>());

    return ListenableBuilder(
      listenable: Listenable.merge([
        ...model.subscriptions,
        model.velTextController,
        model.accTextController,
        model.jerkTextController,
      ]),
      builder: (context, child) {
        double vel = tryCast(model.velSubscription.value) ?? 0;
        double acc = tryCast(model.accSubscription.value) ?? 0;
        double jerk = tryCast(model.jerkSubscription.value) ?? 0;

        bool wasNull = model.velTextController == null ||
              model.accTextController == null ||
              model.jerkTextController == null;
        
        model.velTextController ??= TextEditingController(text: vel.toString());
        model.accTextController ??= TextEditingController(text: acc.toString());
        model.jerkTextController ??= TextEditingController(text: jerk.toString());

        if (wasNull) {
          model.refresh();
        }

        if (vel != model.velLastValue) {
          model.velTextController!.text = vel.toString();
        }
        model.velLastValue = vel;

        if (acc != model.accLastValue) {
          model.accTextController!.text = acc.toString();
        }
        model.accLastValue = acc;

        if (jerk != model.jerkLastValue) {
          model.jerkTextController!.text = jerk.toString();
        }
        model.jerkLastValue = jerk;

        bool showWarning = 
          vel != double.tryParse(model.velTextController!.text) ||
          acc != double.tryParse(model.accTextController!.text) ||
          jerk != double.tryParse(model.jerkTextController!.text);

        TextStyle labelStyle = Theme.of(context)
          .textTheme
          .bodyLarge!
          .copyWith(fontWeight: FontWeight.bold);

        void update() {
          bool publishTopic = model.updateMotorTopic == null;

          model.updateMotorTopic ??= model.ntConnection.getTopicFromName(model.updateMotorTopicName);

          if (model.updateMotorTopic == null) {
            return;
          }

          if (publishTopic) {
            model.ntConnection.publishTopic(model.updateMotorTopic!);
          }

          bool running = model.updateMotorSubscription.value?.tryCast<bool>() ?? false;

          model.ntConnection.updateDataFromTopic(model.updateMotorTopic!, !running);
        }

        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Spacer(),
                Text('Vel', style: labelStyle),
                const Spacer(),
                Flexible(
                  flex: 5,
                  child: TextField(
                    controller: model.velTextController,
                    textAlign: TextAlign.left,
                    inputFormatters: [
                      TextFormatterBuilder.decimalTextFormatter()
                    ],
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                      labelText: 'velocity',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4)
                      )
                    ),
                  ),
                ),
                const Spacer(),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Spacer(),
                Text('Acc', style: labelStyle),
                const Spacer(),
                Flexible(
                  flex: 5,
                  child: TextField(
                    controller: model.accTextController,
                    textAlign: TextAlign.left,
                    inputFormatters: [
                      TextFormatterBuilder.decimalTextFormatter()
                    ],
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                      labelText: 'acceleration',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4)),
                    ),
                    onSubmitted: (value) {},
                  ),
                ),
                const Spacer(),
              ],
            ),
            // kD
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Spacer(),
                Text('Jerk', style: labelStyle),
                const Spacer(),
                Flexible(
                  flex: 5,
                  child: TextField(
                    controller: model.jerkTextController,
                    textAlign: TextAlign.left,
                    inputFormatters: [
                      TextFormatterBuilder.decimalTextFormatter()
                    ],
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                      labelText: 'Jerk',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4)),
                    ),
                    onSubmitted: (value) {},
                  ),
                ),
                const Spacer(),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton(
                  onPressed: () {
                    model.publishVel();
                    model.publishAcc();
                    model.publishJerk();
                    update();
                  },
                  style: ButtonStyle(
                    shape: WidgetStatePropertyAll(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5.0),
                      ),
                    ),
                  ),
                  child: const Text('Publish Values'),
                ),
                const SizedBox(width: 10),
                Icon(
                  (showWarning) ? Icons.priority_high : Icons.check,
                  color: (showWarning) ? Colors.red : Colors.green,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}