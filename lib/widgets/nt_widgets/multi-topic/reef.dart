// ignore_for_file: constant_identifier_names

import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

import 'dart:math' as math;

class ReefModel extends MultiTopicNTWidgetModel {
  @override
  String type = ReefWidget.widgetType;

  NT4Topic? _wantedReefTopic;

  get wantedReefTopic => '$topic/Wanted Reef';

  late NT4Subscription wantedReefSubscription;

  @override
  List<NT4Subscription> get subscriptions => [
    wantedReefSubscription
  ];

  ReefModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    super.period,
    super.dataType,
  }) : super();

  ReefModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required super.jsonData,
  }): super.fromJson();

  @override
  void initializeSubscriptions() {
    wantedReefSubscription = ntConnection.subscribe(wantedReefTopic, super.period);
  }

  @override
  void resetSubscription() {
    for (NT4Subscription subscription in subscriptions) {
      ntConnection.unSubscribe(subscription);
    }
    initializeSubscriptions();
    super.resetSubscription();
  }

  TextEditingController? currentLevelController;
  ReefLevel currentLevel = ReefLevel.L2;

  void sendReefAndLevel(ReefLevel level, Reef reef) {
    bool publishTopic = _wantedReefTopic == null;

    _wantedReefTopic ??= ntConnection.getTopicFromName(wantedReefTopic);

    if (publishTopic) {
      ntConnection.publishTopic(_wantedReefTopic!);
    }

    ntConnection.updateDataFromTopic(_wantedReefTopic!, "${reef.name} ${level.name}");
  }

  void sendReef(Reef reef) {
    sendReefAndLevel(currentLevel, reef);
  }
}

class ReefWidget extends NTWidget {
  static const String widgetType = "Reef";

  const ReefWidget({super.key});

  @override
  Widget build(BuildContext context) {
    ReefModel model = cast(context.watch<NTWidgetModel>());

    return ListenableBuilder(
      listenable: Listenable.merge([
        ...model.subscriptions,
        model.currentLevelController,
      ]), 
      builder: (context, child) {
        bool wasNull = model.currentLevelController == null;
        model.currentLevelController ??= TextEditingController(text: model.currentLevel.name);
        if (wasNull) {
          model.refresh();
        }
        
        List<ReefLevel> options = [ReefLevel.L2, ReefLevel.L3, ReefLevel.L4];

        double angle;
        const Offset hexagonCenter = Offset(180, 170);
        String currentReef = tryCast(model.wantedReefSubscription.value) ?? "";

        return Column(
          children: [
            Container(
              margin: EdgeInsets.all(8),
                child: SingleChildScrollView(
                  child: ToggleButtons(
                    direction: Axis.horizontal,
                    onPressed: (index) {
                      model.currentLevel = options[index];
                      model.currentLevelController!.text = model.currentLevel.name;
                    },
                    isSelected: options.map((ReefLevel option) {
                      if (option == model.currentLevel) {
                        return true;
                      }
                      return false;
                    }).toList(),
                    children: options.map((ReefLevel option) {
                      return Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(option.name),
                      );
                    }).toList(),
                  ),
                ),
            ),
            GestureDetector(
              onTapDown: (details) => {
                angle = math.atan((hexagonCenter.dy - details.localPosition.dy) / (hexagonCenter.dx - details.localPosition.dx)),
                if (details.localPosition.dy > hexagonCenter.dy) {
                  if (angle > 0) {
                    if (angle < math.pi / 6) {
                      model.sendReef(Reef.C2),
                    } else if (angle > math.pi / 3) {
                      model.sendReef(Reef.B2),
                    } else {
                      model.sendReef(Reef.C1),
                    }
                  } else {
                    if (angle > -math.pi / 6) {
                      model.sendReef(Reef.A1),
                    } else if (angle < -math.pi / 3) {
                      model.sendReef(Reef.B1),
                    } else {
                      model.sendReef(Reef.A2),
                    }
                  }
                } else {
                  if (angle > 0) {
                    if (angle < math.pi / 6) {
                      model.sendReef(Reef.F2),
                    } else if (angle > math.pi / 3) {
                      model.sendReef(Reef.E2),
                    } else {
                      model.sendReef(Reef.F1),
                    }
                  } else {
                    if (angle > -math.pi / 6) {
                      model.sendReef(Reef.D1),
                    } else if (angle < -math.pi / 3) {
                      model.sendReef(Reef.E1),
                    } else {
                      model.sendReef(Reef.D2),
                    }
                  }
                }
              },
              child: Container(
                margin: const EdgeInsets.all(10),
                child: Image.asset(
                  "assets/fields/Reef.png",
                ),
              )
            ),
            Text(
              currentReef,
              style: const TextStyle(
                fontSize: 20,
              ),
            ),
          ],
        );
      },
    );
  }
}

enum ReefLevel {
  L2,
  L3,
  L4,
}

enum Reef {
  A1,A2,
  B1,B2,
  C1,C2,
  D1,D2,
  E1,E2,
  F1,F2,
}