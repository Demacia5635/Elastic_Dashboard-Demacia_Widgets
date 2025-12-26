import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class LimelightModel extends MultiTopicNTWidgetModel {
  @override
  String type = LimelightWidget.widgetType;

  String limelightIP = 'limelight.local';
  String port = '5807';
  
  // Target data
  double tx = 0.0;
  double ty = 0.0;
  double ta = 0.0;
  int tv = 0;
  
  // Status data
  double fps = 0.0;
  double temp = 0.0;
  double cpu = 0.0;
  int pipelineIndex = 0;
  
  // Pipeline settings
  int exposure = 3300;
  double blackLevelOffset = 2.0;
  double sensorGain = 8.5;
  int ledPower = 100;
  int redBalance = 1232;
  int blueBalance = 1656;
  String ledMode = 'On';
  String flickerCorrection = '60hz';
  
  bool connected = false;
  Timer? _updateTimer;
  
  // NT4 Topics for Limelight data
  NT4Topic? _txTopic;
  NT4Topic? _tyTopic;
  NT4Topic? _taTopic;
  NT4Topic? _tvTopic;
  NT4Topic? _pipelineTopic;
  
  get txTopicName => '$topic/tx';
  get tyTopicName => '$topic/ty';
  get taTopicName => '$topic/ta';
  get tvTopicName => '$topic/tv';
  get pipelineTopicName => '$topic/pipeline';
  
  late NT4Subscription txSubscription;
  late NT4Subscription tySubscription;
  late NT4Subscription taSubscription;
  late NT4Subscription tvSubscription;
  late NT4Subscription pipelineSubscription;
  
  @override
  List<NT4Subscription> get subscriptions => [
    txSubscription,
    tySubscription,
    taSubscription,
    tvSubscription,
    pipelineSubscription,
  ];

  LimelightModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    super.period,
    super.dataType,
  }) : super() {
    _startHTTPPolling();
  }

  LimelightModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required Map<String, dynamic> jsonData,
  }) : super.fromJson(jsonData: jsonData) {
    limelightIP = jsonData['limelight_ip'] ?? 'limelight.local';
    _startHTTPPolling();
  }
  
  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'limelight_ip': limelightIP,
    };
  }

  @override
  void initializeSubscriptions() {
    txSubscription = ntConnection.subscribe(txTopicName, super.period);
    tySubscription = ntConnection.subscribe(tyTopicName, super.period);
    taSubscription = ntConnection.subscribe(taTopicName, super.period);
    tvSubscription = ntConnection.subscribe(tvTopicName, super.period);
    pipelineSubscription = ntConnection.subscribe(pipelineTopicName, super.period);
  }

  @override
  void resetSubscription() {
    _txTopic = null;
    _tyTopic = null;
    _taTopic = null;
    _tvTopic = null;
    _pipelineTopic = null;

    for (NT4Subscription subscription in subscriptions) {
      ntConnection.unSubscribe(subscription);
    }

    initializeSubscriptions();
    super.resetSubscription();
  }
  
  void _startHTTPPolling() {
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      _fetchLimelightData();
    });
  }
  
  Future<void> _fetchLimelightData() async {
    try {
      // Fetch results
      final resultsResponse = await http.get(
        Uri.parse('http://$limelightIP:$port/results'),
      ).timeout(const Duration(seconds: 1));
      
      if (resultsResponse.statusCode == 200) {
        final data = json.decode(resultsResponse.body);
        
        if (data['Retro'] != null && data['Retro'].isNotEmpty) {
          tx = tryCast(data['Retro'][0]['tx']) ?? 0.0;
          ty = tryCast(data['Retro'][0]['ty']) ?? 0.0;
          ta = tryCast(data['Retro'][0]['ta']) ?? 0.0;
          tv = tryCast(data['Retro'][0]['tv']) ?? 0;
        }
        
        pipelineIndex = tryCast(data['pipelineIndex']) ?? 0;
        connected = true;
      }
      
      // Fetch status
      final statusResponse = await http.get(
        Uri.parse('http://$limelightIP:$port/status'),
      ).timeout(const Duration(seconds: 1));
      
      if (statusResponse.statusCode == 200) {
        final statusData = json.decode(statusResponse.body);
        fps = tryCast(statusData['fps']) ?? 0.0;
        temp = tryCast(statusData['temp']) ?? 0.0;
        cpu = tryCast(statusData['cpu']) ?? 0.0;
      }
      
      notifyListeners();
    } catch (e) {
      connected = false;
      notifyListeners();
    }
  }
  
  Future<void> updatePipelineSetting(String key, dynamic value) async {
    try {
      final response = await http.post(
        Uri.parse('http://$limelightIP:$port/update-pipeline?flush=1'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({key: value}),
      );
      
      if (response.statusCode == 200) {
        switch (key) {
          case 'camExposure':
            exposure = value;
            break;
          case 'camGain':
            sensorGain = value;
            break;
          case 'camBlackLevel':
            blackLevelOffset = value;
            break;
          case 'ledBrightness':
            ledPower = value;
            break;
          case 'camRedBalance':
            redBalance = value;
            break;
          case 'camBlueBalance':
            blueBalance = value;
            break;
          case 'ledMode':
            ledMode = value;
            break;
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error updating pipeline setting: $e');
    }
  }
  
  Future<void> switchPipeline(int index) async {
    try {
      await http.post(
        Uri.parse('http://$limelightIP:$port/pipeline-switch?index=$index'),
      );
      pipelineIndex = index;
      notifyListeners();
    } catch (e) {
      debugPrint('Error switching pipeline: $e');
    }
  }
  
  Future<void> captureSnapshot() async {
    try {
      final timestamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]+'), '-');
      await http.post(
        Uri.parse('http://$limelightIP:$port/capture-snapshot?snapname=snap_$timestamp'),
      );
    } catch (e) {
      debugPrint('Error capturing snapshot: $e');
    }
  }
  
  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }
}

class LimelightWidget extends NTWidget {
  static const String widgetType = 'Limelight';

  const LimelightWidget({super.key});

  @override
  Widget build(BuildContext context) {
    LimelightModel model = cast(context.watch<NTWidgetModel>());

    return ListenableBuilder(
      listenable: Listenable.merge(model.subscriptions),
      builder: (context, child) {
        return Column(
          children: [
            // Status Bar
            Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatusItem(
                    'FPS',
                    model.fps.toStringAsFixed(1),
                    Colors.blue,
                  ),
                  _buildStatusItem(
                    'TEMP',
                    '${model.temp.toStringAsFixed(1)}°C',
                    Colors.orange,
                  ),
                  _buildStatusItem(
                    'CPU',
                    '${model.cpu.toStringAsFixed(1)}%',
                    Colors.purple,
                  ),
                  _buildStatusItem(
                    'TARGET',
                    model.tv == 1 ? 'YES' : 'NO',
                    model.tv == 1 ? Colors.green : Colors.red,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Camera Stream
            Expanded(
              flex: 2,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(
                    color: model.connected ? Colors.green : Colors.red,
                    width: 2,
                  ),
                ),
                child: model.connected
                    ? Image.network(
                        'http://${model.limelightIP}:5800/stream.mjpg',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                            child: Text(
                              'Stream not available',
                              style: TextStyle(color: Colors.grey),
                            ),
                          );
                        },
                      )
                    : const Center(
                        child: Text(
                          'Not connected',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Target Data
            Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildTargetData('tx', model.tx, Colors.cyan),
                  _buildTargetData('ty', model.ty, Colors.cyan),
                  _buildTargetData('ta', model.ta, Colors.yellow),
                  _buildTargetData('Pipeline', model.pipelineIndex.toDouble(), Colors.green),
                ],
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Controls
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      _buildSlider(
                        'Exposure',
                        model.exposure.toDouble(),
                        0,
                        10000,
                        (value) => model.updatePipelineSetting('camExposure', value.toInt()),
                        Colors.yellow,
                      ),
                      _buildSlider(
                        'Black Level',
                        model.blackLevelOffset,
                        0,
                        10,
                        (value) => model.updatePipelineSetting('camBlackLevel', value),
                        Colors.grey,
                      ),
                      _buildSlider(
                        'Sensor Gain',
                        model.sensorGain,
                        0,
                        48,
                        (value) => model.updatePipelineSetting('camGain', value),
                        Colors.purple,
                      ),
                      _buildSlider(
                        'LED Power',
                        model.ledPower.toDouble(),
                        0,
                        100,
                        (value) => model.updatePipelineSetting('ledBrightness', value.toInt()),
                        Colors.green,
                      ),
                      _buildSlider(
                        'Red Balance',
                        model.redBalance.toDouble(),
                        0,
                        4095,
                        (value) => model.updatePipelineSetting('camRedBalance', value.toInt()),
                        Colors.red,
                      ),
                      _buildSlider(
                        'Blue Balance',
                        model.blueBalance.toDouble(),
                        0,
                        4095,
                        (value) => model.updatePipelineSetting('camBlueBalance', value.toInt()),
                        Colors.blue,
                      ),
                      
                      // Pipeline Switcher
                      const SizedBox(height: 16),
                      const Text(
                        'Switch Pipeline',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(10, (index) {
                          return ElevatedButton(
                            onPressed: () => model.switchPipeline(index),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: model.pipelineIndex == index
                                  ? Colors.green
                                  : Colors.grey[800],
                              foregroundColor: Colors.white,
                            ),
                            child: Text('$index'),
                          );
                        }),
                      ),
                      
                      // Snapshot button
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: model.captureSnapshot,
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Capture Snapshot'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
  
  Widget _buildStatusItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 10,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
  
  Widget _buildTargetData(String label, double value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 10,
          ),
        ),
        Text(
          value.toStringAsFixed(2),
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
  
  Widget _buildSlider(
    String label,
    double value,
    double min,
    double max,
    Function(double) onChanged,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ${value.toStringAsFixed(label.contains('Balance') ? 0 : 1)}',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            activeColor: color,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}