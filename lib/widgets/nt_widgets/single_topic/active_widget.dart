import 'dart:async';

import 'package:dot_cast/dot_cast.dart';
import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ActiveWidgetModel extends MultiTopicNTWidgetModel {
  NT4Subscription? activeSubscription; 
  NT4Subscription? timerSubscription;
  NT4Subscription? enabledSub;
  NT4Subscription? autoSub;
  NT4Subscription? teleopSub;
  NT4Subscription? allianceSub;
  NT4Subscription? isTestingSub;
  NT4Subscription? isReset;
  NT4Subscription? countSub;

  NT4Topic? _countTopic;
  int localCount = 0;
  int _lastCount = 0;



  String get timerTopic => '$topic/Timer';  
  String get fmsTopic => '$topic/GameSpecificMessage';
  String get enabledTopic => '$topic/IsEnabled';
  String get autoTopic => '$topic/IsAutonomous';
  String get teleopTopic => '$topic/IsTeleop';
  String get allianceTopic => '$topic/Alliance';
  String get isTestingTopic => '$topic/IsTesting';
  String get isResetTopic => '$topic/IsReset';
  String get countTopic => '$topic/Count';

  @override
  String type = ActiveWidget.widgetType;

  // Game constants
  static const double autoDuration = 20.0; // אוטונומי
  static const double transitionDuration = 10.0; // מעבר
  static const double endgameDuration = 30.0; // אנדגיים
  static const double colorSwitchInterval = 25.0; // החלפת צבע
  
  
  // State tracking
  String? initialColor; // הצבע הראשון שהתקבל מההודעה
  Timer? colorUpdateTimer;
  bool isBlinking = false; // מצב הבהוב
  bool _lastTeleop = false;
  double? _teleopStartRemaining; // למשל 110 בתחילת טלאופ, מה-DS
  double? _lastTimerValue;


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
    enabledSub = ntConnection.subscribe(enabledTopic, super.period);
    autoSub = ntConnection.subscribe(autoTopic, super.period);
    teleopSub = ntConnection.subscribe(teleopTopic, super.period);
    allianceSub = ntConnection.subscribe(allianceTopic, super.period);
    isReset = ntConnection.subscribe(isResetTopic, super.period);
    countSub = ntConnection.subscribe(countTopic, super.period);

    activeSubscription?.addListener(() {
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
      final double? t = timerSubscription?.value as double?;
      if (t != null && _lastTimerValue != null) {
        // אם הטיימר "קפץ קדימה" משמעותית => כנראה reset/run חדש
        if (t - _lastTimerValue! > 1.0) {
          _teleopStartRemaining = null;
          // אם אתה רוצה להתחיל צבע מחדש כל run:
          // initialColor = null;
        }
      }
      _lastTimerValue = t;
      notifyListeners();
    });

    enabledSub?.addListener(() {
      notifyListeners();
    });

    autoSub?.addListener(() {
      notifyListeners();
    });

    teleopSub?.addListener(() {
      final bool isTeleop = (teleopSub?.value as bool?) ?? false;
      _lastTeleop = isTeleop;
      notifyListeners();
    });

    // Timer שמעדכן כל 500ms לעדכון UI והבהוב
    colorUpdateTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      isBlinking = !isBlinking;
      notifyListeners();
    });

    allianceSub?.addListener(() => notifyListeners());
    countSub?.addListener(() {
      final v = countSub?.value;
      final prev = localCount;

      if (v is int) {
        localCount = v;
      } else if (v is double) {
        localCount = v.toInt();
      }

      // אם עברנו ל-RESET (1) או חזרנו ל-RUN (0) - מאפסים latch כדי שיתחיל נקי
      if (localCount != prev) {
        _teleopStartRemaining = null;
        initialColor = null; // אופציונלי: אם אתה רוצה שייקלט צבע מחדש לריצה חדשה
      }

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

  void _latchTeleopStartIfNeeded() {
    if (_teleopStartRemaining != null) return;

    final double? t = timerSubscription?.value as double?;
    if (t == null || t < 0) return;

    final bool isAuto = (autoSub?.value as bool?) ?? false;
    final bool isTeleop = (teleopSub?.value as bool?) ?? false;

    // ננעל רק כשבאמת Teleop (ולא Auto)
    if (!isTeleop || isAuto) return;

    _teleopStartRemaining = t; // "הטיימר שנשאר בתחילת טלאופ" (למשל 135)
    print('Latched teleop start: $_teleopStartRemaining');
  }

  void incrementCount() {
    // נקרא פעם ראשונה – מביאים topic ומפרסמים אותו
    bool publish = _countTopic == null;
    _countTopic ??= ntConnection.getTopicFromName(countTopic);
    if (_countTopic == null) return;

    if (publish) {
      ntConnection.publishTopic(_countTopic!);
    }

    final next = (localCount + 1) % 2;
    localCount = next;

    // שולח ל-NT
    ntConnection.updateDataFromTopic(_countTopic!, next);

    notifyListeners();
  }

  String? _getAllianceLetter() {
    final String? a = allianceSub?.value as String?;
    if (a == null) return null;
    final s = a.trim().toUpperCase();
    if (s == 'R' || s == 'B') return s;
    return null;
  }

  String? _getGameLetter() {
    final String? msg = activeSubscription?.value as String?;
    final String? colorMsg = (msg != null && msg.isNotEmpty) ? msg : initialColor;
    final s = colorMsg?.trim().toUpperCase();
    if (s == 'R' || s == 'B') return s;
    return null;
  }

  // מחזיר R/B של הצבע "הלוגי" הנוכחי (cycle current)
  String? _getCurrentLogicalCycleLetter(double t) {
    _latchTeleopStartIfNeeded();

    final double start = _teleopStartRemaining ?? t;
    final double teleopElapsed = (start - t).clamp(0.0, 999.0);

    if (teleopElapsed < transitionDuration) return null; // עדיין transition

    final String? base = _getGameLetter(); // R/B מהשופטים
    if (base == null) return null;

    final double afterTransition = teleopElapsed - transitionDuration;
    final int cycleNumber = (afterTransition / colorSwitchInterval).floor();
    final bool isFirstColor = (cycleNumber % 2 == 0);

    if (isFirstColor) return base;
    return base == 'R' ? 'B' : 'R';
  }

  // מחזיר את הזמן שנשאר לסייקל הנוכחי
  double getTimeLeftInCurrentCycle() {
    final double? t = timerSubscription?.value as double?;
    //print("t=$t auto=${autoSub?.value} tele=${teleopSub?.value} start=$_teleopStartRemaining");
    if (t == null) return 0.0;

    if (t < 0) {
      _teleopStartRemaining = null; // אין משחק פעיל
      return 0.0;
    }
    final bool isAuto = (autoSub?.value as bool?) ?? false;
    final bool isTeleop = (teleopSub?.value as bool?) ?? false;

    // AUTO: DS מחזיר זמן שנשאר באוטו (20->0)
    if (isAuto) {
      _teleopStartRemaining = null;
      return t.clamp(0.0, autoDuration);
    }

    // DELAY/Between: לא מציגים delay => קפוא על 0 עד שטלאופ מתחיל
    if (!isTeleop) {
      return 0.0;
    }

    // TELEOP:
    _latchTeleopStartIfNeeded();

    // ENDGAME: 30 שניות אחרונות של טלאופ
    if (t <= endgameDuration) {
      return t.clamp(0.0, endgameDuration);
    }

    final double start = _teleopStartRemaining ?? t; // fallback אם פספסנו edge
    final double teleopElapsed = (start - t).clamp(0.0, 999.0);

    // TRANSITION: 10 שניות ראשונות של טלאופ
    if (teleopElapsed < transitionDuration) {
      return (transitionDuration - teleopElapsed).clamp(0.0, transitionDuration);
    }

    // COLOR CYCLES: אחרי transition
    final double afterTransition = teleopElapsed - transitionDuration;
    final double cycleProgress = afterTransition % colorSwitchInterval;
    return (colorSwitchInterval - cycleProgress).clamp(0.0, colorSwitchInterval);
  }

  // מחזיר את שם הסייקל הנוכחי
  String getCurrentCycleName() {
    final double? t = timerSubscription?.value as double?;
    if (t == null) return 'Unknown';

    if (t < 0) return 'Unknown';

    final bool isAuto = (autoSub?.value as bool?) ?? false;
    final bool isTeleop = (teleopSub?.value as bool?) ?? false;

    if (isAuto) return 'Auto';

    // Delay/Between => נשארים על Auto (קפוא על 0) עד טלאופ
    if (!isTeleop) return 'Auto';
    _latchTeleopStartIfNeeded();

    // Endgame רק בטלאופ
    if (t <= endgameDuration) return 'Endgame';

    final double start = _teleopStartRemaining ?? t;
    final double teleopElapsed = (start - t).clamp(0.0, 999.0);

    if (teleopElapsed < transitionDuration) return 'Transition';

    // צבעים
    String? msg = activeSubscription?.value as String?;
    String? colorMsg = (msg != null && msg.isNotEmpty) ? msg : initialColor;

    if (colorMsg == null || colorMsg.isEmpty) return 'Unknown';

    final String? alliance = _getAllianceLetter();
    final String? logical = _getCurrentLogicalCycleLetter(t);

    if (alliance == null || logical == null) {
      return 'Unknown';
    }

    return (logical == alliance) ? 'Demacia': 'Enemy';
  }

  // מחזיר את שם הסייקל הבא
  String? getNextCycleName() {
    final double? t = timerSubscription?.value as double?;
    if (t == null) return null;

    final bool isAuto = (autoSub?.value as bool?) ?? false;
    final bool isTeleop = (teleopSub?.value as bool?) ?? false;

    // Auto -> (אחרי הדיליי) Transition
    if (isAuto) {
      return 'Transition';
    }

    // Delay/Between (אחרי Auto ולפני Teleop) -> Transition
    if (!isTeleop) {
      return 'Transition';
    }
    _latchTeleopStartIfNeeded();

    // אם אנחנו כבר ב-Endgame אין "Next"
    if (t <= endgameDuration) {
      return null;
    }

    // ב-Teleop (לא Endgame): מחשבים כמה עבר מאז תחילת Teleop
    final double start = _teleopStartRemaining ?? t;
    final double teleopElapsed = (start - t).clamp(0.0, 999.0);

    // אם אנחנו ב-Transition אז ה-Next הוא הצבע הראשון לפי ההודעה
    if (teleopElapsed < transitionDuration) {
      final String? msg = activeSubscription?.value as String?;
      final String? colorMsg = (msg != null && msg.isNotEmpty) ? msg : initialColor;
      if (colorMsg == null || colorMsg.isEmpty) return 'Unknown';
      final String? alliance = _getAllianceLetter();
      final String firstLogical = (colorMsg == 'R') ? 'R' : 'B';
      if (alliance == null) return 'Unknown';
      return (firstLogical == alliance) ? 'Demacia' : 'Enemy';
    }

    // אנחנו בתוך Cycles:
    // אם הסייקל הבא ייפול כבר לתוך Endgame (כלומר נשאר פחות/שווה 30) => Next = Endgame
    // הדרך הנכונה: להסתכל על matchTime עצמו (t)
    // "Next" משתנה רק בסוף סייקל, אבל כדי להציג נכון:
    final double start2 = _teleopStartRemaining ?? t;
    final double teleopElapsed2 = (start2 - t).clamp(0.0, 999.0);
    final double afterTransition = teleopElapsed2 - transitionDuration;

    final int cycleNumber = (afterTransition / colorSwitchInterval).floor();
    final bool isFirstColor = (cycleNumber % 2 == 0);

    // צבע ראשון נקבע לפי ההודעה שנקלטה פעם אחת
    final String? msg = activeSubscription?.value as String?;
    final String? colorMsg = (msg != null && msg.isNotEmpty) ? msg : initialColor;
    if (colorMsg == null || colorMsg.isEmpty) return 'Unknown';

    // הצבע הבא הוא ההופכי לצבע הנוכחי
    String nextColor;
    if (isFirstColor) {
      nextColor = (colorMsg == 'R') ? 'Blue' : 'Red';
    } else {
      nextColor = (colorMsg == 'R') ? 'Red' : 'Blue';
    }

    // אם לפני החלפה הבאה כבר ניכנס ל-Endgame:
    final double timeLeftInThisCycle = getTimeLeftInCurrentCycle();
    final double tAtNextBoundary = t - timeLeftInThisCycle;
    if (tAtNextBoundary <= endgameDuration) {
      return 'Endgame';
    }

    final String? alliance = _getAllianceLetter();
    if (alliance == null) return 'Unknown';

    final String nextLogical = (nextColor == 'Red') ? 'R' : 'B';
    return (nextLogical == alliance) ? 'Demacia' : 'Enemy';
  }

  // בודק אם צריך להבהב (3 שניות אחרונות)
  bool shouldBlink() {
    double timeLeft = getTimeLeftInCurrentCycle();
    return timeLeft <= 3.0 && timeLeft > 0;
  }

  Color getColor() {
    final double? t = timerSubscription?.value as double?;
    if (t == null) return Colors.grey;

    if (t < 0) return Colors.purple;

    if (shouldBlink() && isBlinking) return Colors.white;

    final bool isAuto = (autoSub?.value as bool?) ?? false;
    final bool isTeleop = (teleopSub?.value as bool?) ?? false;

    // Auto סגול
    if (isAuto) return Colors.purple;

    // Delay/Between סגול (קפוא)
    if (!isTeleop) return Colors.purple;
    _latchTeleopStartIfNeeded();

    // Endgame סגול
    if (t <= endgameDuration) return Colors.purple;

    final double start = _teleopStartRemaining ?? t;
    final double teleopElapsed = (start - t).clamp(0.0, 999.0);

    // Transition סגול
    if (teleopElapsed < transitionDuration) return Colors.purple;

    // Cycles -> OUR alliance = green, opponent = grey
    final String? alliance = _getAllianceLetter();
    final String? logical = _getCurrentLogicalCycleLetter(t);

    if (alliance == null || logical == null) {
      return Colors.purple; // או Colors.grey אם אתה מעדיף כשאין מידע
    }

    return (logical == alliance) ? Colors.green : Colors.grey;
  }
}

class ActiveWidget extends NTWidget {
  static const String widgetType = 'ActiveWidget';
  bool isReset = false;
  ActiveWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final ActiveWidgetModel model = cast(context.watch<NTWidgetModel>());
    
    final double timeLeftInCycle = model.getTimeLeftInCurrentCycle();
    final String currentCycle = model.getCurrentCycleName();
    final String? nextCycle = model.getNextCycleName();
      
    return Stack(
      children: [ 
        // רקע צבעוני
        Positioned.fill(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            color: model.getColor(),
          ),
        ),
        Positioned(
          bottom: 0, left: -10, 
          child: IconButton(
            onPressed: model.incrementCount,
            icon: Icon(
              model.localCount == 0
                ? Icons.refresh          // מצב רגיל
                : Icons.play_arrow,  // practice timer
              color: Colors.red,
              size: 50,
            )
          )
        ),
        // תוכן מעל הרקע
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // טיימר גדול - זמן שנשאר לסייקל
              Text(
                timeLeftInCycle > 0
                    ? '⏱ ${timeLeftInCycle.toStringAsFixed(1)}s'
                    : '⏱ 0.0s',
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      blurRadius: 10.0,
                      color: Colors.black,
                      offset: Offset(3, 3),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // שם הסייקל הנוכחי
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white70, width: 2),
                ),
                child: Text(
                  currentCycle.toUpperCase(),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: currentCycle == "Demacia" ? Colors.purple : Colors.white,
                    letterSpacing: 2,
                  ),
                ),
              ),

              // הסייקל הבא (אם יש)
              if (nextCycle != null) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.arrow_downward,
                      color: Colors.black,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Next: ${nextCycle.toUpperCase()}',
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}