import 'dart:async';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ActiveWidgetModel extends MultiTopicNTWidgetModel {
  NT4Subscription? activeSubscription; 
  NT4Subscription? timerSubscription;
  String get timerTopic => '$topic/Timer';  
  String get fmsTopic => '$topic/GameSpecificMessage';
  
  @override
  String type = ActiveWidget.widgetType;

  // Blinking state managed in the model
  bool isBlinkRed = false;
  bool first30SecPassed = false;
  double blinkTime = 0.0;
  Timer? blinkTimer;

  ActiveWidgetModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    super.dataType,
    super.period,
  });

  @override
  void init() {
    super.init();
    activeSubscription = ntConnection.subscribe(fmsTopic, super.period);
    timerSubscription = ntConnection.subscribe(timerTopic, super.period);
    
    
    // activeSubscription?.addListener(() {
    //   notifyListeners();
    // });
    
    // timerSubscription?.addListener(() {
    //   notifyListeners();
    // });

    
    blinkTimer = Timer.periodic(const Duration(milliseconds: 20), (timer) {
      blinkTime += 0.02;
      if (blinkTime >= 25000 && first30SecPassed == true) { 
        blinkTime = 0.0;
        isBlinkRed = !isBlinkRed;
        notifyListeners(); 
      }

      if(blinkTime >= 30000 && first30SecPassed == false) {
        first30SecPassed = true;
        blinkTime = 0.0;
        isBlinkRed = (activeSubscription?.value as String) == 'R';
      }
    });
  }

  ActiveWidgetModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required super.jsonData,
  }) : super.fromJson();


  Color getColor() {
    int? timerValue = timerSubscription?.value as int?;
    
    // Purple during first/last 30 seconds
    if (timerValue != null && (timerValue <= 30 || timerValue >= 130)) {
      return Colors.purple;
    }
    
    // Blink between red and blue
    return isBlinkRed ? Colors.red : Colors.blue;
  }
}

class ActiveWidget extends NTWidget {
  static const String widgetType = 'ActiveWidget';

  ActiveWidget({super.key});
  late ActiveWidgetModel model;

  Widget resetBtn(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        model.activeSubscription?.addListener(() {
      model.notifyListeners();
        });
        
      },
      child: const Text('Reset'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<ActiveWidgetModel>();
    
    return Stack(
      children: [ 
        Container(
          color: model.getColor(),
        )
      ]
    );
  }
}
