import 'dart:async';

import 'package:dot_cast/dot_cast.dart';
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

  // Game constants
  static const double gameDuration = 160.0; // 2:40 minutes
  static const double purpleDuration = 30.0; // 20 auto + 10 teleop
  static const double colorSwitchInterval = 25.0; // החלפת צבע כל 25 שניות
  
  // State tracking
  String? initialColor; // הצבע הראשון שהתקבל מההודעה
  Timer? colorUpdateTimer;

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
    
    // הוספת listeners כדי לעדכן את הUI כשמגיעים ערכים חדשים
    activeSubscription?.addListener(() {
      // שומר את הצבע הראשוני כשמגיעה ההודעה
      if (initialColor == null) {
        String? message = activeSubscription?.value as String?;
        if (message != null && message.isNotEmpty) {
          initialColor = message;
          print('Initial color set to: $initialColor');
        }
      }
      notifyListeners();
    });
    
    timerSubscription?.addListener(() {
      notifyListeners();
    });

    // Timer שמעדכן כל 500ms לעדכון UI
    colorUpdateTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    colorUpdateTimer?.cancel();
    super.dispose();
  }

  ActiveWidgetModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required super.jsonData,
  }) : super.fromJson();

  Color getColor() {
    double? timerValue = timerSubscription?.value as double?;
    
    if (timerValue == null) {
      return Colors.grey; // אין ערך - אפור
    }
    
    // מחשב כמה זמן עבר מתחילת המשחק
    double elapsed = gameDuration - timerValue;
    
    // 30 שניות ראשונות - סגול (20 auto + 10 teleop)
    if (elapsed < purpleDuration) {
      return Colors.purple;
    }
    
    // 30 שניות אחרונות - סגול (endgame)
    if (timerValue <= purpleDuration) {
      return Colors.purple;
    }
    
    // בדיקה אם כבר הגיעה הודעה מ-FMS
    String? message = activeSubscription?.value as String?;
    String? currentMessage = message ?? initialColor;
    
    // אם עדיין לא הגיעה הודעה - להישאר סגול ולהמתין
    if (currentMessage == null || currentMessage.isEmpty) {
      print('WARNING: No FMS message received yet! Staying purple...');
      return Colors.purple;
    }
    
    // אמצע המשחק - מחליף בין צבעים כל 25 שניות
    double afterPurple = elapsed - purpleDuration;
    int cycleNumber = (afterPurple / colorSwitchInterval).floor();
    bool isFirstColor = (cycleNumber % 2 == 0);
    
    if (isFirstColor) {
      // מחזור זוגי - הצבע המקורי
      return currentMessage == 'R' ? Colors.red : Colors.blue;
    } else {
      // מחזור אי-זוגי - הצבע המנוגד
      return currentMessage == 'R' ? Colors.blue : Colors.red;
    }
  }
  
  String getDebugInfo() {
    double? timerValue = timerSubscription?.value as double?;
    if (timerValue == null) return 'No Timer';
    
    double elapsed = gameDuration - timerValue;
    
    if (elapsed < purpleDuration) {
      return 'Purple Phase - Start (${elapsed.toStringAsFixed(1)}s)';
    }
    
    if (timerValue <= purpleDuration) {
      return 'Purple Phase - Endgame (${timerValue.toStringAsFixed(1)}s left)';
    }
    
    String? message = activeSubscription?.value as String?;
    String? currentMessage = message ?? initialColor;
    
    if (currentMessage == null || currentMessage.isEmpty) {
      return '⚠️ Waiting for FMS message...';
    }
    
    double afterPurple = elapsed - purpleDuration;
    int cycleNumber = (afterPurple / colorSwitchInterval).floor();
    double cycleProgress = afterPurple % colorSwitchInterval;
    
    bool isFirstColor = (cycleNumber % 2 == 0);
    String color = isFirstColor ? currentMessage : (currentMessage == 'R' ? 'B' : 'R');
    
    return 'Cycle $cycleNumber - $color (${cycleProgress.toStringAsFixed(1)}s / ${colorSwitchInterval}s)';
  }
}

class ActiveWidget extends NTWidget {
  static const String widgetType = 'ActiveWidget';

  ActiveWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final ActiveWidgetModel model = cast(context.watch<NTWidgetModel>());
    
    final double? timerValue = model.timerSubscription?.value as double?;
    final String message = model.activeSubscription?.value?.toString() ?? '';
      
    return Stack(
      children: [ 
        // רקע צבעוני
        Positioned.fill(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            color: model.getColor(),
          ),
        ),

        // תוכן מעל הרקע
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // טיימר
              Text(
                timerValue != null
                    ? '⏱ ${timerValue.toStringAsFixed(1)}'
                    : '⏱ --',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      blurRadius: 10.0,
                      color: Colors.black,
                      offset: Offset(2, 2),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // הודעת FMS
              Text(
                message.isNotEmpty ? 'StartingTeam: $message' : 'No Message',
                style: const TextStyle(
                  fontSize: 20,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      blurRadius: 10.0,
                      color: Colors.black,
                      offset: Offset(2, 2),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              
              // Debug info
              const SizedBox(height: 15),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  model.getDebugInfo(),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                    fontFamily: 'monospace',
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}