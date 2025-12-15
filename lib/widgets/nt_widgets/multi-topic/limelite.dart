import 'package:flutter/material.dart';
import 'package:elastic_dashboard/services/nt4_client.dart'
import 'package:elastic_dashboard/widgets/nt_widget.dart';

class limelite extends NTWidget {

  NT4Topic exsemple = nt4Client.subscribePeriodic("exsmple", 0.1);
  double exsemple = exsemple.getValue() ?? 0.0;

  private Color backGroubdndColor;
  private Color textColor;
  private String text;

  limelite({
    super.key,
    required super.topic,
    super.dataType,
    super.period,
    required this.backGroubdndColor = Colors.Perple,
    required this.textColor = Colors.blue,
    required this.text,
  })  

}

