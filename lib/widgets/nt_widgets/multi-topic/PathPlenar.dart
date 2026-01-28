import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import 'package:flutter/material.dart';



class PathPlenarModole extends NTWidgetModel {
  late NT4Subscription valueSubscription;

  final String topic;

  PathPlenarModole({required this.ntConnection, required this.topic});

  @override
  void initializeSubscriptions() {
    valueSubscription = ntConnection.subscribe('$topic/Value', 100);
  }

  final NT4Client ntConnection;
}

class PathplenarMain extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Column(

      ),
    );
  }
}

class PathPlenar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Image(image: )),
    )
  }
} 
