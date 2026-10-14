import 'dart:math';
import 'package:flutter/material.dart';
/// gets angle in dagrees and moves the arm accordingly
class ArmAngleWidget extends StatelessWidget {
  final double angleDegrees;
  final Duration animationDuration;

  const ArmAngleWidget({
    super.key,
    required this.angleDegrees,
    this.animationDuration = const Duration(milliseconds: 250),
  });

}
