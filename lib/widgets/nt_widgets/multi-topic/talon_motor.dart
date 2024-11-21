import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

class TalonMotorModel extends MultiTopicNTWidgetModel {
  @override
  String type = TalonMotorWidget.widgetType;

  get controlModeTopic => '$topic/controlMode';
  get closeLoopSPTopic => '$topic/CloseLoopSP';
  get closeLoopErrorTopic => '$topic/CloseLoopError';
  get positionTopic => '$topic/position';
  get velocityTopic => '$topic/velocity';
  get accelerationTopic => '$topic/acceleration';
  get isInvertTopic => '$topic/isInvert';
  get voltageTopic => '$topic/voltage';

  late NT4Subscription controlModeSubscription;
  late NT4Subscription closeLoopSPSubscription;
  late NT4Subscription closeLoopErrorSubscription;
  late NT4Subscription positionSubscription;
  late NT4Subscription velocitySubscription;
  late NT4Subscription accelerationSubscription;
  late NT4Subscription isInvertSubscription;
  late NT4Subscription voltageSubscription;

  @override
  List<NT4Subscription> get subscriptions => [
    controlModeSubscription,
    closeLoopSPSubscription,
    closeLoopErrorSubscription,
    positionSubscription,
    velocitySubscription,
    accelerationSubscription,
    isInvertSubscription,
    voltageSubscription
  ];

  TalonMotorModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    super.period,
    super.dataType,
  }) : super();

  TalonMotorModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required super.jsonData,
  }) : super.fromJson();

  @override
  void initializeSubscriptions() {
    controlModeSubscription = ntConnection.subscribe(controlModeTopic, super.period);
    closeLoopSPSubscription = ntConnection.subscribe(closeLoopSPTopic, super.period);
    closeLoopErrorSubscription = ntConnection.subscribe(closeLoopErrorTopic, super.period);
    positionSubscription = ntConnection.subscribe(positionTopic, super.period);
    velocitySubscription = ntConnection.subscribe(velocityTopic, super.period);
    accelerationSubscription = ntConnection.subscribe(accelerationTopic, super.period);
    isInvertSubscription = ntConnection.subscribe(isInvertTopic, super.period);
    voltageSubscription = ntConnection.subscribe(voltageTopic, super.period);
  }

  @override
  void resetSubscription() {
    for (NT4Subscription subscription in subscriptions) {
      ntConnection.unSubscribe(subscription);
    }

    initializeSubscriptions();

    super.resetSubscription();
  }
}

class TalonMotorWidget extends NTWidget {
  static const String widgetType = "TalonMotor";

  const TalonMotorWidget({super.key});

  @override
  Widget build(BuildContext context) {
    TalonMotorModel model = cast(context.watch<NTWidgetModel>());

    return ListenableBuilder(
      listenable: Listenable.merge(model.subscriptions),
      builder: (context, child) {
        String controlMode = tryCast(model.controlModeSubscription.value) ?? "Empty ControlMode";
        double closeLoopSP = tryCast(model.closeLoopSPSubscription.value) ?? 0;
        double closeLoopError = tryCast(model.closeLoopErrorSubscription.value) ?? 0;
        double position = tryCast(model.positionSubscription.value) ?? 0;
        double velocity = tryCast(model.velocitySubscription.value) ?? 0;
        double acceleration = tryCast(model.accelerationSubscription.value) ?? 0;
        bool isInvert = tryCast(model.isInvertSubscription.value) ?? false;
        double voltage = tryCast(model.voltageSubscription.value) ?? 0;
        voltage = voltage.abs();

        return Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  // color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(5.0),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: [
                    Text(
                      controlMode,
                      style: const TextStyle(
                        fontSize: 17
                      ),
                      textAlign: TextAlign.center,
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(5.0),
                                color: Theme.of(context).colorScheme.surface
                              ),
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              child: Text(
                                'SP: ${closeLoopSP.toStringAsFixed(2)}',
                                textAlign: TextAlign.center,
                              ),
                            )
                          ),
                          const SizedBox(
                            width: 5,
                          ),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(5.0),
                                color: Theme.of(context).colorScheme.surface
                              ),
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              child: Text(
                                'Error: ${closeLoopError.toStringAsFixed(2)}',
                                textAlign: TextAlign.center,
                              ),
                            )
                          ),
                        ],
                      )
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(5.0),
                                color: Theme.of(context).colorScheme.surface
                              ),
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              child: Text(
                                'pos:\n${position.toStringAsFixed(2)}',
                                textAlign: TextAlign.center,
                              ),
                            )
                          ),
                          const SizedBox(
                            width: 2,
                          ),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(5.0),
                                color: Theme.of(context).colorScheme.surface
                              ),
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              child: Text(
                                'vel:\n${velocity.toStringAsFixed(2)}',
                                textAlign: TextAlign.center,
                              ),
                            )
                          ),
                          const SizedBox(
                            width: 2,
                          ),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(5.0),
                                color: Theme.of(context).colorScheme.surface
                              ),
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              child: Text(
                                'acc:\n${acceleration.toStringAsFixed(2)}',
                                textAlign: TextAlign.center,
                              ),
                            )
                          ),
                        ],
                      )
                    ),
                    const SizedBox(
                      height: 3,
                    ),
                    Transform.flip(
                      flipX: (velocity > 0 && isInvert) || (velocity < 0 && !isInvert),
                      child: Icon(
                        velocity.abs() > 0.2 ?
                        Icons.autorenew : Icons.circle,
                        color: velocity.abs() < 0.2 ? Colors.grey : isInvert ? Colors.red : Colors.green,
                        size: 65.0,
                      ),
                    ),
                    const SizedBox(
                      height: 2,
                    ),
                    SfLinearGauge(
                      key: UniqueKey(),
                      maximum: 12.0,
                      minimum: 0,
                      barPointers: [
                        LinearBarPointer(
                          value: voltage,
                          color: Colors.yellow.shade600,
                          edgeStyle: LinearEdgeStyle.bothCurve,
                          animationDuration: 0,
                          thickness: 5,
                        ),
                      ],
                      axisTrackStyle: const LinearAxisTrackStyle(
                        thickness: 5,
                        edgeStyle: LinearEdgeStyle.bothCurve,
                      ),
                      labelFormatterCallback: (value) => '$value V',
                      orientation: LinearGaugeOrientation.horizontal,
                      isAxisInversed: false,
                      interval: 3,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }
    );
  }
}