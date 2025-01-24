// ignore_for_file: constant_identifier_names

import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:flutter/services.dart';
import 'package:flutter_box_transform/flutter_box_transform.dart';
import 'package:hexagon/hexagon.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

import 'dart:math' as math;

class ReefModel extends MultiTopicNTWidgetModel {
  @override
  String type = ReefWidget.widgetType;

  NT4Topic? _L2Topic;
  NT4Topic? _L3Topic;
  NT4Topic? _L4Topic;


  get L2Topic => '$topic/L2';
  get L3Topic => '$topic/L3';
  get L4Topic => '$topic/L4';

  late NT4Subscription L2Subscription;
  late NT4Subscription L3Subscription;
  late NT4Subscription L4Subscription;

  TextEditingController controller = TextEditingController();
  ReefLevel currentLevel = ReefLevel.L2;

  TextEditingController controller2 = TextEditingController();
  List<double> l2 = List<double>.filled(12, 0);

  @override
  List<NT4Subscription> get subscriptions => [
    L2Subscription,
    L3Subscription,
    L4Subscription,
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
    L2Subscription = ntConnection.subscribe(L2Topic, super.period);
    L3Subscription = ntConnection.subscribe(L3Topic, super.period);
    L4Subscription = ntConnection.subscribe(L4Topic, super.period);
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

class ReefWidget extends NTWidget {
  static const String widgetType = "Reef";

  const ReefWidget({super.key});

  @override
  Widget build(BuildContext context) {
    ReefModel model = cast(context.watch<NTWidgetModel>());

    return ListenableBuilder(
      listenable: Listenable.merge([
        ...model.subscriptions,
        model.controller,
        model.controller2
      ]), 
      builder: (context, child) {
        List<ReefLevel> options = [ReefLevel.L2, ReefLevel.L3, ReefLevel.L4];
        const List<Offset> locations = [
          Offset(50, 210), Offset(50, 110), 
          Offset(60, 90), Offset(140, 40),
          Offset(186, 40), Offset(240, 90),
          Offset(260, 120), Offset(250, 210),
          Offset(240, 240), Offset(170, 280),
          Offset(140, 280), Offset(60, 230)
        ];


        return Row(
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: ToggleButtons(
                  direction: Axis.vertical,
                  onPressed: (index) {
                    model.currentLevel = options[index];
                    model.controller.text = model.currentLevel.name;
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
            Transform.rotate(
              angle: 0.5 * math.pi,
              child: GestureDetector(
                onTapDown: (details) => {
                  print(details.localPosition),
                  for (Offset location in locations) {
                    if ((details.localPosition.dx - location.dx).abs() < 20 
                    && (details.localPosition.dy - location.dy).abs() < 20) {
                      model.l2[locations.indexOf(location)] += 2,
                      model.controller2.text = locations.indexOf(location).toString()
                    }
                  }
                },
                child: Container(
                  margin: const EdgeInsets.all(10),
                  child: HexagonWidget.pointy(
                    child: Text(
                      model.controller2.text,
                      style: TextStyle(color: Colors.black),
                    ),
                    width: 300,
                    color: model.currentLevel == ReefLevel.L2 
                    ? Colors.red 
                    : model.currentLevel == ReefLevel.L3
                      ? Colors.orange
                      : Colors.yellow,
                    elevation: 8,
                  ),
                )
              )
            )
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