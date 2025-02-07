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

  NT4Topic? _positionTopic;
  NT4Topic? _elementPositionTopic;
  NT4Topic? _levelTopic;

  get positionTopic => '$topic/Position';
  get elementPositionTopic => '$topic/Element Position';
  get levelTopic => '$topic/Level';

  late NT4Subscription positionSubscription;
  late NT4Subscription elementPositionSubscription;
  late NT4Subscription levelSubscription;

  @override
  List<NT4Subscription> get subscriptions => [
        positionSubscription,
        elementPositionSubscription,
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
    positionSubscription =
        ntConnection.subscribe(positionTopic, super.period);
    elementPositionSubscription = ntConnection.subscribe(elementPositionTopic, super.period);
    levelSubscription = ntConnection.subscribe(levelTopic, super.period);
  }

  @override
  void resetSubscription() {
    _positionTopic = null;
    _elementPositionTopic = null;
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

  double lastPositon = 0;
  double lastElementPosition = 0;
  double lastLevel = 0;

  bool hasFeed = false;

  void chooseReef(SAVED_REEF reef) {
    lastReef = reef;
    reefController?.text = reef.name;

    _positionTopic ??= ntConnection.getTopicFromName(positionTopic);
    _elementPositionTopic ??= ntConnection.getTopicFromName(elementPositionTopic);
    _levelTopic ??= ntConnection.getTopicFromName(levelTopic);

    if (positionTopic == null || elementPositionTopic == null || levelTopic == null) {
      return;
    }

    // if (publishTopic) {
      ntConnection.publishTopic(_positionTopic!);
      if (hasFeed) {
        ntConnection.publishTopic(_elementPositionTopic!);
        ntConnection.publishTopic(_levelTopic!);
      }
    // }

    ntConnection.updateDataFromTopic(_positionTopic!, reef.index);

    lastPositon = reef.index.toDouble();

    if (hasFeed) {
      ntConnection.updateDataFromTopic(_elementPositionTopic!, lastElementPosition);
      ntConnection.updateDataFromTopic(_levelTopic!, lastLevel);
    }
  }

  void chooseLevel(SAVED_LEVEL level) {
    if (level == SAVED_LEVEL.L1) {
      level = SAVED_LEVEL.L2_LEFT;
    } else if (level == SAVED_LEVEL.L4_LEFT) {
      level = SAVED_LEVEL.L3_LEFT;
    } else if (level == SAVED_LEVEL.L4_RIGHT) {
      level = SAVED_LEVEL.L3_RIGHT;
    }

    lastSavedLevel = level;
    levelController?.text = level.name;

    _levelTopic ??= ntConnection.getTopicFromName(levelTopic);
    _elementPositionTopic ??= ntConnection.getTopicFromName(elementPositionTopic);
    _positionTopic ??= ntConnection.getTopicFromName(positionTopic);

    if (levelTopic == null || elementPositionTopic == null || positionTopic == null) {
      return;
    }

    // if (publishTopic) {
      ntConnection.publishTopic(_levelTopic!);
      ntConnection.publishTopic(_elementPositionTopic!);
      if (hasFeed) {
        ntConnection.publishTopic(_positionTopic!);
      }
    // }

    double elementPositionData = switch (level) {
      SAVED_LEVEL.L1 => 1,
      SAVED_LEVEL.L2_RIGHT => 1,
      SAVED_LEVEL.L2_LEFT => 0,
      SAVED_LEVEL.L3_RIGHT => 1,
      SAVED_LEVEL.L3_LEFT => 0,
      SAVED_LEVEL.L4_RIGHT => 1,
      SAVED_LEVEL.L4_LEFT => 0,
      SAVED_LEVEL.ALGAE_BOTTOM => 2,
      SAVED_LEVEL.ALGAE_TOP => 2,
    };

    double levelData = switch (level) {
      SAVED_LEVEL.L1 => 0,
      SAVED_LEVEL.L2_RIGHT => 0,
      SAVED_LEVEL.L2_LEFT => 0,
      SAVED_LEVEL.L3_RIGHT => 1,
      SAVED_LEVEL.L3_LEFT => 1,
      SAVED_LEVEL.L4_RIGHT => 1,
      SAVED_LEVEL.L4_LEFT => 1,
      SAVED_LEVEL.ALGAE_BOTTOM => 3,
      SAVED_LEVEL.ALGAE_TOP => 4,
    };

    ntConnection.updateDataFromTopic(_elementPositionTopic!, elementPositionData);
    ntConnection.updateDataFromTopic(_levelTopic!, levelData);
    
    lastElementPosition = elementPositionData;
    lastLevel = levelData;

    if (hasFeed) {
      ntConnection.updateDataFromTopic(_positionTopic!, lastPositon);
    }
  }

  void chooseCoralStation(SAVED_CORAL_STATION coralStation) {
    hasFeed = true;
    lastCoralStation = coralStation;
    coralStationController?.text = coralStation.name;

    _positionTopic ??= ntConnection.getTopicFromName(positionTopic);
    _elementPositionTopic ??= ntConnection.getTopicFromName(elementPositionTopic);
    _levelTopic ??= ntConnection.getTopicFromName(levelTopic);

    if (positionTopic == null || elementPositionTopic == null || levelTopic == null) {
      return;
    }

    // if (publishTopic) {
      ntConnection.publishTopic(_positionTopic!);
      ntConnection.publishTopic(_elementPositionTopic!);
      ntConnection.publishTopic(_levelTopic!);
    // }

    ntConnection.updateDataFromTopic(_positionTopic!, coralStation == SAVED_CORAL_STATION.LEFT ? 6 : 7);
    ntConnection.updateDataFromTopic(_elementPositionTopic!, 3);
    ntConnection.updateDataFromTopic(_levelTopic!, 2);
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
        POSITION fieldPosition = POSITION.values.elementAt(tryCast(model.positionSubscription.value) ?? 0);
        ELEMENT_POSITON elementPosition = ELEMENT_POSITON.values.elementAt(tryCast(model.elementPositionSubscription.value) ?? 0);
        LEVEL level = LEVEL.values.elementAt(tryCast(model.levelSubscription.value) ?? 0);

        bool wasNull = model.levelController == null ||
            model.coralStationController == null ||
            model.reefController == null;

        if (fieldPosition == POSITION.FEEDER_LEFT || fieldPosition == POSITION.FEEDER_RIGHT) {
          model.reefController ??= TextEditingController(text: model.lastCoralStation.name);
          model.levelController ??= TextEditingController(text: model.lastSavedLevel.name);
          if (fieldPosition == POSITION.FEEDER_LEFT) {
            model.coralStationController ??= TextEditingController(text: SAVED_CORAL_STATION.LEFT.name);
          } else {
            model.coralStationController ??= TextEditingController(text: SAVED_CORAL_STATION.RIGHT.name);
          }
        } else {
          model.reefController ??= TextEditingController(text: fieldPosition.name);
          model.levelController ??= TextEditingController(
            text: 
              elementPosition == ELEMENT_POSITON.ALGEA 
              ? level.name 
              : elementPosition == ELEMENT_POSITON.CORAL_LEFT 
                ? level == LEVEL.L2 
                  ? "L2_LEFT" 
                  : "L3_LEFT" 
                : level == LEVEL.L2 
                  ? "L2_RIGHT" 
                : "L3_RIGHT"
          );
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

        Image reefImage() {
          try {
            return Image.asset("assets/reef/reefSelector/${model.reefController!.text}.png");
          } catch (e) {
            return Image.asset("assets/reef/Reef.png");
          }
        }

        Image levelImage() {
          try {
            return Image.asset("assets/reef/levelSelector/${model.levelController!.text}.png");
          } catch (e) {
            return Image.asset("assets/reef/LevelSelector.png");
          }
        }

        Image coralStationImage() {
          try {
            return Image.asset("assets/reef/coralStationSelector/${model.coralStationController!.text}.png");
          } catch (e) {
            return Image.asset("assets/reef/CoralStationSelector.png");
          }
        }

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
                  child: reefImage(),
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
                      model.chooseLevel(SAVED_LEVEL.L1),
                    }
                  } else {
                    if (details.localPosition.dy < L4Height) {
                      model.chooseLevel(SAVED_LEVEL.L4_LEFT),
                    } else if (details.localPosition.dy < L3Height) {
                      model.chooseLevel(SAVED_LEVEL.L3_LEFT),
                    } else if (details.localPosition.dy < L2Height) {
                      model.chooseLevel(SAVED_LEVEL.L2_LEFT),
                    } else if (details.localPosition.dy < L1Height) {
                      model.chooseLevel(SAVED_LEVEL.L1),
                    }
                  }
                }
              },
              child: Container(
                margin: const EdgeInsets.all(1),
                child: levelImage(),
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
                    child: coralStationImage(),
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

enum POSITION { 
  A, 
  B, 
  C, 
  D, 
  E, 
  F, 
  FEEDER_LEFT, 
  FEEDER_RIGHT, 
}

enum ELEMENT_POSITON {
  CORAL_LEFT,
  CORAL_RIGTH,
  ALGEA,
  FEEDER,
}

enum LEVEL {
  L2,
  L3,
  FEEDER,
  ALGAE_BOTTOM,
  ALGAE_TOP
}

enum SAVED_CORAL_STATION {
  LEFT,
  RIGHT
}

enum SAVED_LEVEL {
  L1,
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
