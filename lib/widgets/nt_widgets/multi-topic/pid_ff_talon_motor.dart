import 'package:elastic_dashboard/services/text_formatter_builder.dart';
import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class PidFfTalonMotorModel extends MultiTopicNTWidgetModel {
  @override
  String type = PidFfTalonMotorWidget.widgetType;

  double _kPLastValue = 0.0;
  double _kILastValue = 0.0;
  double _kDLastValue = 0.0;
  double _kSLastValue = 0.0;
  double _kVLastValue = 0.0;
  double _kALastValue = 0.0;
  double _kGLastValue = 0.0;

  get kpLastValue => _kPLastValue;
  set kpLastValue(value) => _kPLastValue = value;
  get kiLastValue => _kILastValue;
  set kiLastValue(value) => _kILastValue = value;
  get kdLastValue => _kDLastValue;
  set kdLastValue(value) => _kDLastValue = value;
  get kSLastValue => _kSLastValue;
  set kSLastValue(value) => _kSLastValue = value;
  get kVLastValue => _kVLastValue;
  set kVLastValue(value) => _kVLastValue = value;
  get kALastValue => _kALastValue;
  set kALastValue(value) => _kALastValue = value;
  get kGLastValue => _kGLastValue;
  set kGLastValue(value) => _kGLastValue = value;

  TextEditingController? kpTextController;
  TextEditingController? kiTextController;
  TextEditingController? kdTextController;
  TextEditingController? ksTextController;
  TextEditingController? kvTextController;
  TextEditingController? kaTextController;
  TextEditingController? kgTextController;

  NT4Topic? _kPTopic;
  NT4Topic? _kITopic;
  NT4Topic? _kDTopic;
  NT4Topic? _kSTopic;
  NT4Topic? _kVTopic;
  NT4Topic? _kATopic;
  NT4Topic? _kGTopic;

  NT4Topic? updateMotorTopic;

  get kPTopic => '$topic/kP';
  get kITopic => '$topic/kI';
  get kDTopic => '$topic/kD';
  get kSTopic => '$topic/kS';
  get kVTopic => '$topic/kV';
  get kATopic => '$topic/kA';
  get kGTopic => '$topic/kG';

  get updateMotorTopicName => '$topic/update';

  late NT4Subscription kPSubscription;
  late NT4Subscription kISubscription;
  late NT4Subscription kDSubscription;
  late NT4Subscription kSSubscription;
  late NT4Subscription kVSubscription;
  late NT4Subscription kASubscription;
  late NT4Subscription kGSubscription;
  late NT4Subscription updateMotorSubscription;

  @override
  List<NT4Subscription> get subscriptions => [
    kPSubscription,
    kISubscription,
    kDSubscription,
    kSSubscription,
    kVSubscription,
    kASubscription,
    kGSubscription,
    updateMotorSubscription,
  ];

  PidFfTalonMotorModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    super.period,
    super.dataType,
  }) : super();

  PidFfTalonMotorModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required super.jsonData,
  }) : super.fromJson();

  @override
  void initializeSubscriptions() {
    kPSubscription = ntConnection.subscribe(kPTopic, super.period);
    kISubscription = ntConnection.subscribe(kITopic, super.period);
    kDSubscription = ntConnection.subscribe(kDTopic, super.period);
    kSSubscription = ntConnection.subscribe(kSTopic, super.period);
    kVSubscription = ntConnection.subscribe(kVTopic, super.period);
    kASubscription = ntConnection.subscribe(kATopic, super.period);
    kGSubscription = ntConnection.subscribe(kGTopic, super.period);
    updateMotorSubscription = ntConnection.subscribe(updateMotorTopicName, super.period);
  }

  @override
  void resetSubscription() {
    _kPTopic = null;
    _kITopic = null;
    _kDTopic = null;
    _kSTopic = null;
    _kVTopic = null;
    _kATopic = null;
    _kGTopic = null;
    updateMotorTopic = null;

    for (NT4Subscription subscription in subscriptions) {
      ntConnection.unSubscribe(subscription);
    }

    initializeSubscriptions();
    super.resetSubscription();
  }

  void publishKP() {
    bool publishTopic = _kPTopic == null;

    _kPTopic ??= ntConnection.getTopicFromName(kPTopic);

    double? data = double.tryParse(kpTextController?.text ?? '');

    if (_kPTopic == null || data == null) {
      return;
    }

    if (publishTopic) {
      ntConnection.publishTopic(_kPTopic!);
    }

    ntConnection.updateDataFromTopic(_kPTopic!, data);
  }

  void publishKI() {
    bool publishTopic = _kITopic == null;

    _kITopic ??= ntConnection.getTopicFromName(kITopic);

    double? data = double.tryParse(kiTextController?.text ?? '');

    if (_kITopic == null || data == null) {
      return;
    }

    if (publishTopic) {
      ntConnection.publishTopic(_kITopic!);
    }

    ntConnection.updateDataFromTopic(_kITopic!, data);
  }

  void publishKD() {
    bool publishTopic = _kDTopic == null;

    _kDTopic ??= ntConnection.getTopicFromName(kDTopic);

    double? data = double.tryParse(kdTextController?.text ?? '');

    if (_kDTopic == null || data == null) {
      return;
    }

    if (publishTopic) {
      ntConnection.publishTopic(_kDTopic!);
    }

    ntConnection.updateDataFromTopic(_kDTopic!, data);
  }

  void publishKS() {
    bool publishTopic = _kSTopic == null;

    _kSTopic ??= ntConnection.getTopicFromName(kSTopic);

    double? data = double.tryParse(ksTextController?.text ?? '');

    if (_kSTopic == null || data == null) {
      return;
    }

    if (publishTopic) {
      ntConnection.publishTopic(_kSTopic!);
    }

    ntConnection.updateDataFromTopic(_kSTopic!, data);
  }

  void publishKV() {
    bool publishTopic = _kVTopic == null;

    _kVTopic ??= ntConnection.getTopicFromName(kVTopic);

    double? data = double.tryParse(kvTextController?.text ?? '');

    if (_kVTopic == null || data == null) {
      return;
    }

    if (publishTopic) {
      ntConnection.publishTopic(_kVTopic!);
    }

    ntConnection.updateDataFromTopic(_kVTopic!, data);
  }

  void publishKA() {
    bool publishTopic = _kATopic == null;

    _kATopic ??= ntConnection.getTopicFromName(kATopic);

    double? data = double.tryParse(kaTextController?.text ?? '');

    if (_kATopic == null || data == null) {
      return;
    }

    if (publishTopic) {
      ntConnection.publishTopic(_kATopic!);
    }

    ntConnection.updateDataFromTopic(_kATopic!, data);
  }

  void publishKG() {
    bool publishTopic = _kGTopic == null;

    _kGTopic ??= ntConnection.getTopicFromName(kGTopic);

    double? data = double.tryParse(kgTextController?.text ?? '');

    if (_kGTopic == null || data == null) {
      return;
    }

    if (publishTopic) {
      ntConnection.publishTopic(_kGTopic!);
    }

    ntConnection.updateDataFromTopic(_kGTopic!, data);
  }

}

class PidFfTalonMotorWidget extends NTWidget {
  static const String widgetType = "pid+ff Talon motor";

  const PidFfTalonMotorWidget({super.key});

  @override
  Widget build(BuildContext context) {
    PidFfTalonMotorModel model = cast(context.watch<NTWidgetModel>());

    return ListenableBuilder(
      listenable: Listenable.merge([
        ...model.subscriptions,
        model.kpTextController,
        model.kiTextController,
        model.kdTextController,
        model.ksTextController,
        model.kvTextController,
        model.kaTextController,
        model.kgTextController,
      ]),
      builder: (context, child) {
        double kP = tryCast(model.kPSubscription.value) ?? 0;
        double kI = tryCast(model.kISubscription.value) ?? 0;
        double kD = tryCast(model.kDSubscription.value) ?? 0;
        double kS = tryCast(model.kSSubscription.value) ?? 0;
        double kV = tryCast(model.kVSubscription.value) ?? 0;
        double kA = tryCast(model.kASubscription.value) ?? 0;
        double kG = tryCast(model.kGSubscription.value) ?? 0;

        bool wasNull = model.kpTextController == null ||
              model.kiTextController == null ||
              model.kdTextController == null ||
              model.ksTextController == null ||
              model.kvTextController == null ||
              model.kaTextController == null ||
              model.kgTextController == null;

        model.kpTextController ??= TextEditingController(text: kP.toString());
        model.kiTextController ??= TextEditingController(text: kI.toString());
        model.kdTextController ??= TextEditingController(text: kD.toString());
        model.ksTextController ??= TextEditingController(text: kS.toString());
        model.kvTextController ??= TextEditingController(text: kV.toString());
        model.kaTextController ??= TextEditingController(text: kA.toString());
        model.kgTextController ??= TextEditingController(text: kG.toString());

        // Since they were null they're not being listened to when created during build
        if (wasNull) {
          model.refresh();
        }

        // Updates the text of the text editing controller if the kp value has changed
        if (kP != model.kpLastValue) {
          model.kpTextController!.text = kP.toString();
        }
        model.kpLastValue = kP;

        // Updates the text of the text editing controller if the ki value has changed
        if (kI != model.kiLastValue) {
          model.kiTextController!.text = kI.toString();
        }
        model.kiLastValue = kI;

        // Updates the text of the text editing controller if the kd value has changed
        if (kD != model.kdLastValue) {
          model.kdTextController!.text = kD.toString();
        }
        model.kdLastValue = kD;

        if (kS != model.kSLastValue) {
          model.ksTextController!.text = kS.toString();
        }
        model.kSLastValue = kS;

        if (kV != model.kVLastValue) {
          model.kvTextController!.text = kV.toString();
        }
        model.kVLastValue = kV;

        if (kA != model.kALastValue) {
          model.kaTextController!.text = kA.toString();
        }
        model.kALastValue = kA;

        if (kG != model.kGLastValue) {
          model.kgTextController!.text = kG.toString();
        }
        model.kGLastValue = kG;

        bool showWarning = 
            kP != double.tryParse(model.kpTextController!.text) ||
            kI != double.tryParse(model.kiTextController!.text) ||
            kD != double.tryParse(model.kdTextController!.text) ||
            kS != double.tryParse(model.ksTextController!.text) ||
            kV != double.tryParse(model.kvTextController!.text) ||
            kA != double.tryParse(model.kaTextController!.text) ||
            kG != double.tryParse(model.kgTextController!.text);

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

        return Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Spacer(),
                      Text('kP', style: labelStyle),
                      const Spacer(),
                      Flexible(
                        flex: 5,
                        child: TextField(
                          controller: model.kpTextController,
                          textAlign: TextAlign.left,
                          inputFormatters: [
                            TextFormatterBuilder.decimalTextFormatter()
                          ],
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                            labelText: 'kP',
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
                      Text('kI', style: labelStyle),
                      const Spacer(),
                      Flexible(
                        flex: 5,
                        child: TextField(
                          controller: model.kiTextController,
                          textAlign: TextAlign.left,
                          inputFormatters: [
                            TextFormatterBuilder.decimalTextFormatter()
                          ],
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                            labelText: 'kI',
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
                      Text('kD', style: labelStyle),
                      const Spacer(),
                      Flexible(
                        flex: 5,
                        child: TextField(
                          controller: model.kdTextController,
                          textAlign: TextAlign.left,
                          inputFormatters: [
                            TextFormatterBuilder.decimalTextFormatter()
                          ],
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                            labelText: 'kD',
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
                          model.publishKP();
                          model.publishKI();
                          model.publishKD();
                          model.publishKS();
                          model.publishKV();
                          model.publishKA();
                          model.publishKG();
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
              )
            ),

            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Spacer(),
                      Text('kS', style: labelStyle),
                      const Spacer(),
                      Flexible(
                        flex: 5,
                        child: TextField(
                          controller: model.ksTextController,
                          textAlign: TextAlign.left,
                          inputFormatters: [
                            TextFormatterBuilder.decimalTextFormatter()
                          ],
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                            labelText: 'kS',
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
                      Text('kV', style: labelStyle),
                      const Spacer(),
                      Flexible(
                        flex: 5,
                        child: TextField(
                          controller: model.kvTextController,
                          textAlign: TextAlign.left,
                          inputFormatters: [
                            TextFormatterBuilder.decimalTextFormatter()
                          ],
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                            labelText: 'kV',
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
                      const Spacer(),
                      Text('kA', style: labelStyle),
                      const Spacer(),
                      Flexible(
                        flex: 5,
                        child: TextField(
                          controller: model.kaTextController,
                          textAlign: TextAlign.left,
                          inputFormatters: [
                            TextFormatterBuilder.decimalTextFormatter()
                          ],
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                            labelText: 'kA',
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
                      const Spacer(),
                      Text('kG', style: labelStyle),
                      const Spacer(),
                      Flexible(
                        flex: 5,
                        child: TextField(
                          controller: model.kgTextController,
                          textAlign: TextAlign.left,
                          inputFormatters: [
                            TextFormatterBuilder.decimalTextFormatter()
                          ],
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                            labelText: 'kG',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4)),
                          ),
                          onSubmitted: (value) {},
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                ],
              )
            )
          ]
        );
      }
    );
  }
}