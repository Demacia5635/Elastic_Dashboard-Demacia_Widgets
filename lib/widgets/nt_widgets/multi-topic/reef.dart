// ignore_for_file: constant_identifier_names, camel_case_types

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class ReefModel extends MultiTopicNTWidgetModel {
  @override
  String type = ReefWidget.widgetType;

  NT4Topic? _fieldPositionTopic;
  NT4Topic? _levelTopic;

  get fieldPositionTopic => '$topic/Field Position';
  get levelTopic => '$topic/Level';

  late NT4Subscription fieldPositionSubscription;
  late NT4Subscription levelSubscription;

  @override
  List<NT4Subscription> get subscriptions => [
        fieldPositionSubscription,
        levelSubscription,
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
  }) : super.fromJson();

  @override
  void initializeSubscriptions() {
    fieldPositionSubscription =
        ntConnection.subscribe(fieldPositionTopic, super.period);
    levelSubscription = ntConnection.subscribe(levelTopic, super.period);
  }

  @override
  void resetSubscription() {
    _fieldPositionTopic = null;
    _levelTopic = null;

    for (NT4Subscription subscription in subscriptions) {
      ntConnection.unSubscribe(subscription);
    }

    initializeSubscriptions();
    super.resetSubscription();
  }

  TextEditingController? levelController;
  TextEditingController? coralStationController;
  TextEditingController? reefController;

  SAVED_LEVEL lastSavedLevel = SAVED_LEVEL.L3_LEFT;
  SAVED_CORAL_STATION lastCoralStation = SAVED_CORAL_STATION.LEFT;
  SAVED_REEF lastReef = SAVED_REEF.A;

  double lastFieldPosition = 0;
  double lastLevel = 6;

  void chooseReef(SAVED_REEF reef) {
    lastReef = reef;
    reefController?.text = reef.name;

    bool publishTopic = fieldPositionTopic == null || levelTopic == null;

    _fieldPositionTopic ??= ntConnection.getTopicFromName(fieldPositionTopic);
    _levelTopic ??= ntConnection.getTopicFromName(levelTopic);

    if (fieldPositionTopic == null || levelTopic == null) {
      return;
    }

    // if (publishTopic) {
      ntConnection.publishTopic(_fieldPositionTopic!);
      ntConnection.publishTopic(_levelTopic!);
    // }

    ntConnection.updateDataFromTopic(_fieldPositionTopic!, reef.index + 2);
    ntConnection.updateDataFromTopic(_levelTopic!, lastLevel);

    lastFieldPosition = reef.index + 2;
  }

  void chooseLevel(SAVED_LEVEL level) {
    if (level == SAVED_LEVEL.L1_LEFT) {
      level = SAVED_LEVEL.L2_LEFT;
    } else if (level == SAVED_LEVEL.L1_RIGHT) {
      level = SAVED_LEVEL.L2_RIGHT;
    } else if (level == SAVED_LEVEL.L4_LEFT) {
      level = SAVED_LEVEL.L3_LEFT;
    } else if (level == SAVED_LEVEL.L4_RIGHT) {
      level = SAVED_LEVEL.L3_RIGHT;
    }

    lastSavedLevel = level;
    levelController?.text = level.name;

    bool publishTopic = levelTopic == null || fieldPositionTopic == null;

    _levelTopic ??= ntConnection.getTopicFromName(levelTopic);
    _fieldPositionTopic ??= ntConnection.getTopicFromName(fieldPositionTopic);

    if (levelTopic == null || fieldPositionTopic == null) {
      return;
    }

    // if (publishTopic) {
      ntConnection.publishTopic(_levelTopic!);
      ntConnection.publishTopic(_fieldPositionTopic!);
    // }

    double data = level.index - 2;
    if (level == SAVED_LEVEL.ALGAE_BOTTOM || level == SAVED_LEVEL.ALGAE_TOP) {
      data -= 2;
    }

    ntConnection.updateDataFromTopic(_levelTopic!, data);
    ntConnection.updateDataFromTopic(_fieldPositionTopic!, lastFieldPosition);
    
    lastLevel = data;
  }

  void chooseCoralStation(SAVED_CORAL_STATION coralStation) {
    lastCoralStation = coralStation;
    coralStationController?.text = coralStation.name;

    bool publishTopic = fieldPositionTopic == null || levelTopic == null;

    _fieldPositionTopic ??= ntConnection.getTopicFromName(fieldPositionTopic);
    _levelTopic ??= ntConnection.getTopicFromName(levelTopic);

    if (fieldPositionTopic == null || levelTopic == null) {
      return;
    }

    // if (publishTopic) {
      ntConnection.publishTopic(_fieldPositionTopic!);
      ntConnection.publishTopic(_levelTopic!);
    // }

    ntConnection.updateDataFromTopic(_fieldPositionTopic!, coralStation == SAVED_CORAL_STATION.LEFT ? 0 : 1);
    ntConnection.updateDataFromTopic(_levelTopic!, 6);
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
        model.levelController,
        model.coralStationController,
        model.reefController,
      ]),
      builder: (context, child) {
        FIELD_POSITION fieldPosition = FIELD_POSITION.values.elementAt(tryCast(model.fieldPositionSubscription.value) ?? 0);
        LEVEL level = LEVEL.values.elementAt(tryCast(model.levelSubscription.value) ?? 0);

        bool wasNull = model.levelController == null ||
            model.coralStationController == null ||
            model.reefController == null;

        if (fieldPosition == FIELD_POSITION.FEEDER_LEFT || fieldPosition == FIELD_POSITION.FEEDER_RIGHT) {
          model.reefController ??= TextEditingController(text: model.lastCoralStation.name);
          model.levelController ??= TextEditingController(text: model.lastSavedLevel.name);
          if (fieldPosition == FIELD_POSITION.FEEDER_LEFT) {
            model.coralStationController ??= TextEditingController(text: SAVED_CORAL_STATION.LEFT.name);
          } else {
            model.coralStationController ??= TextEditingController(text: SAVED_CORAL_STATION.RIGHT.name);
          }
        } else {
          model.reefController ??= TextEditingController(text: fieldPosition.name);
          model.levelController ??= TextEditingController(text: level.name);
          model.coralStationController ??= TextEditingController(text: model.lastCoralStation.name);
        }

        if (wasNull) {
          model.refresh();
        }

        double angle;
        const Offset hexagonCenter = Offset(180, 170);

        const Offset algeaTopCenter = Offset(75, 100);
        const Offset algeaBottomCenter = Offset(75, 175);

        const double L4Height = 65;
        const double L3Height = 145;
        const double L2Height = 220;
        const double L1Height = 285;

        return Row(
          children: [
            GestureDetector(
                onTapDown: (details) => {
                      angle = math.atan(
                          (hexagonCenter.dy - details.localPosition.dy) /
                              (hexagonCenter.dx - details.localPosition.dx)),
                      if (details.localPosition.dy > hexagonCenter.dy)
                        {
                          if (angle > 0)
                            {
                              if (angle < math.pi / 6)
                                {
                                  model.chooseReef(SAVED_REEF.C),
                                }
                              else if (angle > math.pi / 3)
                                {
                                  model.chooseReef(SAVED_REEF.B),
                                }
                              else
                                {
                                  model.chooseReef(SAVED_REEF.C),
                                }
                            }
                          else
                            {
                              if (angle > -math.pi / 6)
                                {
                                  model.chooseReef(SAVED_REEF.A),
                                }
                              else if (angle < -math.pi / 3)
                                {
                                  model.chooseReef(SAVED_REEF.B),
                                }
                              else
                                {
                                  model.chooseReef(SAVED_REEF.A),
                                }
                            }
                        }
                      else
                        {
                          if (angle > 0)
                            {
                              if (angle < math.pi / 6)
                                {
                                  model.chooseReef(SAVED_REEF.F),
                                }
                              else if (angle > math.pi / 3)
                                {
                                  model.chooseReef(SAVED_REEF.E),
                                }
                              else
                                {
                                  model.chooseReef(SAVED_REEF.F),
                                }
                            }
                          else
                            {
                              if (angle > -math.pi / 6)
                                {
                                  model.chooseReef(SAVED_REEF.D),
                                }
                              else if (angle < -math.pi / 3)
                                {
                                  model.chooseReef(SAVED_REEF.E),
                                }
                              else
                                {
                                  model.chooseReef(SAVED_REEF.D),
                                }
                            }
                        }
                    },
                child: Container(
                  // margin: const EdgeInsets.all(),
                  child: Image.asset(
                    "assets/reef/Reef.png",
                  ),
                )),
            GestureDetector(
              onTapDown: (details) => {
                if (math.sqrt(
                  math.pow(details.localPosition.dx - algeaTopCenter.dx, 2) 
                  + math.pow(details.localPosition.dy - algeaTopCenter.dy, 2)) <= 30) {
                    model.chooseLevel(SAVED_LEVEL.ALGAE_TOP),
                } else if (math.sqrt(
                  math.pow(details.localPosition.dx - algeaBottomCenter.dx, 2)
                  + math.pow(details.localPosition.dy - algeaBottomCenter.dy , 2)) <= 30) {
                    model.chooseLevel(SAVED_LEVEL.ALGAE_BOTTOM),
                } else {
                  if (details.localPosition.dx > 75) {
                    if (details.localPosition.dy < L4Height) {
                      model.chooseLevel(SAVED_LEVEL.L4_RIGHT),
                    } else if (details.localPosition.dy < L3Height) {
                      model.chooseLevel(SAVED_LEVEL.L3_RIGHT),
                    } else if (details.localPosition.dy < L2Height) {
                      model.chooseLevel(SAVED_LEVEL.L2_RIGHT),
                    } else if (details.localPosition.dy < L1Height) {
                      model.chooseLevel(SAVED_LEVEL.L1_RIGHT),
                    }
                  } else {
                    if (details.localPosition.dy < L4Height) {
                      model.chooseLevel(SAVED_LEVEL.L4_LEFT),
                    } else if (details.localPosition.dy < L3Height) {
                      model.chooseLevel(SAVED_LEVEL.L3_LEFT),
                    } else if (details.localPosition.dy < L2Height) {
                      model.chooseLevel(SAVED_LEVEL.L2_LEFT),
                    } else if (details.localPosition.dy < L1Height) {
                      model.chooseLevel(SAVED_LEVEL.L1_LEFT),
                    }
                  }
                }
              },
              child: Container(
                margin: const EdgeInsets.all(1),
                child: Image.asset("assets/reef/levelSelector.png")
              ),
            ),
            Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 20, bottom: 20),
                  child: Text(
                    "${model.reefController?.text} \n ${model.levelController?.text} \n ${model.coralStationController?.text}"
                  ),
                ),
                GestureDetector(
                  onTapDown: (details) => {
                    if (details.localPosition.dx > 50) {
                      model.chooseCoralStation(SAVED_CORAL_STATION.RIGHT),
                    } else {
                      model.chooseCoralStation(SAVED_CORAL_STATION.LEFT),
                    }
                  },
                  child: Container(
                    // margin: const EdgeInsets.only(right: 1,
                    child: Image.asset("assets/reef/coralStationSelector.png")
                  ),
                ),
              ],
            )
          ],
        );
      },
    );
  }
}

enum FIELD_POSITION { 
  FEEDER_LEFT, 
  FEEDER_RIGHT, 
  A, 
  B, 
  C, 
  D, 
  E, 
  F 
}

enum LEVEL {
  L2_RIGHT,
  L2_LEFT,
  L3_RIGHT,
  L3_LEFT,
  ALGAE_BOTTOM,
  ALGAE_TOP,
  FEEDER
}

enum SAVED_CORAL_STATION {
  LEFT,
  RIGHT
}

enum SAVED_LEVEL {
  L1_RIGHT,
  L1_LEFT,
  L2_RIGHT,
  L2_LEFT,
  L3_RIGHT,
  L3_LEFT,
  L4_RIGHT,
  L4_LEFT,
  ALGAE_BOTTOM,
  ALGAE_TOP
}

enum SAVED_REEF { A, B, C, D, E, F }
