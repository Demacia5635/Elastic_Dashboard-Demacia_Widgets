import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class RecordingModel extends MultiTopicNTWidgetModel {
  @override
  String type = RecordingWidget.widgetType;

  RECORDING_STATUS? status;
  bool isRunning = false;
  bool isPaused = false;

  TextEditingController? statusTextController;

  NT4Topic? _statusTopic;
  
  get statusTopic => '$topic/Status';
  
  late NT4Subscription statusSubscription;

  @override
  List<NT4Subscription> get subscriptions => [
    statusSubscription
  ];

  RecordingModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    super.period,
    super.dataType,
  }) : super();

  RecordingModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required super.jsonData,
  }) : super.fromJson();

  @override
  void initializeSubscriptions() {
    statusSubscription = ntConnection.subscribe(statusTopic, super.period);
  }

  @override
  void resetSubscription() {
    _statusTopic = null;

    for (NT4Subscription subscription in subscriptions) {
      ntConnection.unSubscribe(subscription);
    }

    initializeSubscriptions();

    super.resetSubscription();
  }

  void start() {
    bool publishTopic = _statusTopic == null;

    _statusTopic ??= ntConnection.getTopicFromName(statusTopic);

    if (_statusTopic == null) {
      return;
    }

    if (publishTopic) {
      ntConnection.publishTopic(_statusTopic!);
    }

    ntConnection.updateDataFromTopic(_statusTopic!, "START");

    status = RECORDING_STATUS.START;
    statusTextController?.text = status.toString();
    isRunning = true;
    isPaused = false;
  }

  void pause() {
    bool publishTopic = _statusTopic == null;

    _statusTopic ??= ntConnection.getTopicFromName(statusTopic);

    if (_statusTopic == null) {
      return;
    }

    if (publishTopic) {
      ntConnection.publishTopic(_statusTopic!);
    }

    ntConnection.updateDataFromTopic(_statusTopic!, "PAUSE");

    status = RECORDING_STATUS.PAUSE;
    statusTextController?.text = status.toString();
    isPaused = true;
  }

  void stop() {
    bool publishTopic = _statusTopic == null;

    _statusTopic ??= ntConnection.getTopicFromName(statusTopic);

    if (_statusTopic == null) {
      return;
    }

    if (publishTopic) {
      ntConnection.publishTopic(_statusTopic!);
    }

    ntConnection.updateDataFromTopic(_statusTopic!, "STOP");

    status = RECORDING_STATUS.STOP;
    statusTextController?.text = status.toString();
    isRunning = false;
    isPaused = false;
  }

  void flag() {
    bool publishTopic = _statusTopic == null;

    _statusTopic ??= ntConnection.getTopicFromName(statusTopic);

    if (_statusTopic == null) {
      return;
    }

    if (publishTopic) {
      ntConnection.publishTopic(_statusTopic!);
    }

    ntConnection.updateDataFromTopic(_statusTopic!, "FLAG");
    ntConnection.updateDataFromTopic(_statusTopic!, "START");

    status = RECORDING_STATUS.FLAG;
    status = RECORDING_STATUS.START;
  }
}

class RecordingWidget extends NTWidget {
  static const String widgetType = "Recording";

  const RecordingWidget({super.key});

  @override
  Widget build(BuildContext context) {
    RecordingModel model = cast(context.watch<NTWidgetModel>());

    return ListenableBuilder(
      listenable: Listenable.merge([
        ...model.subscriptions,
        model.statusTextController,
      ]),
      builder: (context, child) {

        bool wasNull = model.statusTextController == null;

        model.statusTextController ??= TextEditingController(text: model.status.toString());

        if (wasNull) {
          model.refresh();
        }

        return Row(
          children: [
            Expanded(
              child: GestureDetector(

                onDoubleTap: model.isRunning && !model.isPaused
                ? model.stop
                : model.start,

                child: Container(
                  decoration: BoxDecoration(
                    // color: Colors.white,
                    borderRadius: BorderRadius.circular(5.0),
                  ),
                  child: Icon(
                    color: Colors.red,
                    model.isRunning && !model.isPaused
                    ? Icons.stop_circle
                    : Icons.fiber_manual_record
                  ),
                ),
              )
            ),
            Expanded(
              child: GestureDetector(

                onDoubleTap: model.isPaused
                ? model.stop
                : model.pause,

                child: Container(
                  decoration: BoxDecoration(
                    // color: Colors.white,
                    borderRadius: BorderRadius.circular(5.0),
                  ),
                  child: Icon(
                    color: !model.isRunning
                    ? Colors.blueGrey
                    : Colors.blue,

                    model.isPaused
                    ? Icons.refresh_sharp
                    : Icons.pause
                  ),
                )
              ),
            ),
            Expanded(
              child: GestureDetector(

                onDoubleTap: model.flag,

                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5.0),
                  ),
                  child: Icon(
                    color: model.status == RECORDING_STATUS.FLAG 
                    ? Colors.amber
                    : Colors.grey,
                    Icons.flag_circle
                  ),
                )
              ),
            ),
          ],
        );
      },
    );
  }
}

enum RECORDING_STATUS {
  START,
  PAUSE,
  STOP,
  FLAG;
}

// class TimeWidget extends Widget {
//   static const String widgetType = 'Match Time';

//   TimeWidget({
//     super.key,
//     required this.timeController,
//   });
//   TextEditingController timeController;

//   Color _getTimeColor() {
//     return Colors.blue;
//   }

//   String _secondsToMinutes(num time) {
//     return '${(time / 60.0).floor()}:${(time % 60).toString().padLeft(2, '0')}';
//   }

//   @override
//   Widget build(BuildContext context) {
//     return ListenableBuilder(
//       listenable: timeController,
//       builder: (context, child) {
//         double time = tryCast(timeController.text) ?? -1.0;
//         time = time.floorToDouble();

//         String timeDisplayString;
//         timeDisplayString = time.toInt().toString();

//         return Stack(
//           fit: StackFit.expand,
//           children: [
//             ClipRRect(
//               child: FittedBox(
//                 fit: BoxFit.contain,
//                 child: Text(
//                   timeDisplayString,
//                   textAlign: TextAlign.center,
//                   style: TextStyle(
//                     height: 1.0,
//                     color: _getTimeColor(),
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         );
//       },
//     );
//   }
  
//   @override
//   Element createElement() {
//     throw UnimplementedError();
//   }
// }