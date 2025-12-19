import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_toggle_switch.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class LimelightModel extends MultiTopicNTWidgetModel {
  @override
  String type = LimelightWiget.widgetType;

  String get txTopicName => '$topic/tx';
  String get tyTopicName => '$topic/ty';
  String get pipelineTopicName => '$topic/pipeline';
  String get sensor_grainTopicName => '$topic/sensor_grain';
  String get black_level_offsetTopicName => '$topic/black_level_offset';
  String get exposureTopicName => '$topic/expusure';

  late NT4Subscription txSubscription;
  late NT4Subscription tySubscription;
  late NT4Subscription pipelineSubscription;
  late NT4Subscription sensor_grainSubscription;
  late NT4Subscription black_level_offsetSubscription;
  late NT4Subscription expusureSubscription;

  @override
    List<NT4Subscription> get subscriptions => [
        txSubscription,
        tySubscription,
        pipelineSubscription,
        sensor_grainSubscription,
        black_level_offsetSubscription,
        expusureSubscription,
      ];
      LimelightModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    super.dataType,
    super.period,
  });
}


class LimelightWiget extends NTWidget{
  static const String widgetType = "Limelight";
  
  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    throw UnimplementedError();
  }


}
