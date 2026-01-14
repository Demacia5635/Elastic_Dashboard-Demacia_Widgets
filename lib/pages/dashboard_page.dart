import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt_widget_builder.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'package:collection/collection.dart';
import 'package:elegant_notification/elegant_notification.dart';
import 'package:elegant_notification/resources/stacked_options.dart';
import 'package:flex_seed_scheme/flex_seed_scheme.dart';
import 'package:http/http.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:elastic_dashboard/pages/dashboard/add_widget_dialog.dart';
import 'package:elastic_dashboard/pages/dashboard/dashboard_page_footer.dart';
import 'package:elastic_dashboard/pages/dashboard/dashboard_page_layouts.dart';
import 'package:elastic_dashboard/pages/dashboard/dashboard_page_notifications.dart';
import 'package:elastic_dashboard/pages/dashboard/dashboard_page_settings.dart';
import 'package:elastic_dashboard/pages/dashboard/dashboard_page_tabs.dart';
import 'package:elastic_dashboard/pages/dashboard/dashboard_page_window.dart';
import 'package:elastic_dashboard/services/app_distributor.dart';
import 'package:elastic_dashboard/services/elastic_layout_downloader.dart';
import 'package:elastic_dashboard/services/elasticlib_listener.dart';
import 'package:elastic_dashboard/services/hotkey_manager.dart';
import 'package:elastic_dashboard/services/ip_address_util.dart';
import 'package:elastic_dashboard/services/log.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/settings.dart';
import 'package:elastic_dashboard/services/update_checker.dart';
import 'package:elastic_dashboard/util/tab_data.dart';
import 'package:elastic_dashboard/util/test_utils.dart';
import 'package:elastic_dashboard/widgets/custom_appbar.dart';
import 'package:elastic_dashboard/widgets/editable_tab_bar.dart';
import 'package:elastic_dashboard/widgets/tab_grid.dart';

import 'package:elastic_dashboard/util/stub/unload_handler_stub.dart'
    if (dart.library.js_interop) 'package:elastic_dashboard/util/unload_handler.dart';
import 'package:window_manager/window_manager.dart'
    if (dart.library.js_interop) 'package:elastic_dashboard/util/stub/window_stub.dart';

enum LayoutDownloadMode {
  overwrite(
    name: 'Overwrite',
    description:
        'Keeps existing tabs that are not defined in the remote layout. Any tabs that are defined in the remote layout will be overwritten locally.',
  ),
  merge(
    name: 'Merge',
    description:
        'Merge the downloaded layout with the existing one. If a new widget cannot be properly placed, it will not be added.',
  ),
  reload(
    name: 'Full Reload',
    description: 'Deletes the existing layout and loads the new one.',
  );

  final String name;
  final String description;

  const LayoutDownloadMode({required this.name, required this.description});

  static String get descriptions {
    String result = '';
    for (final value in values) {
      result += '${value.name}: ';
      result += value.description;

      if (value != values.last) {
        result += '\n\n';
      }
    }
    return result;
  }
}

mixin DashboardPageStateMixin on State<DashboardPage> {
  void showNotification(ElegantNotification notification) {
    if (mounted) notification.show(context);
  }

  Future<void> closeWindow();

  ThemeData get theme => Theme.of(context);

  ButtonThemeData get buttonTheme => ButtonTheme.of(context);
}

abstract class DashboardPageViewModel extends ChangeNotifier {
  final String version;
  final NTConnection ntConnection;
  final SharedPreferences preferences;
  late final UpdateChecker? updateChecker;
  late final ElasticLayoutDownloader? layoutDownloader;
  final Function(Color color)? onColorChanged;
  final Function(FlexSchemeVariant variant)? onThemeVariantChanged;
  
  // playback
  bool isPlaying = false;
  int playbackIndex = 0;
  List<Map<String, dynamic>> playbackData = [];

  bool _seenShuffleboardWarning = false;
  bool isRecording = false;
  List<Map<String, dynamic>> recorder = [];
  Timer? timer;
  final Map<String, NT4Subscription> _recordingSubscriptions = {};
  Map<String, String> widgetTypes = {};
  final Map<String, dynamic> lastSentValues = {};
  final double playbackSpeed = 0.5;
  int recordingStartTime = 0;
  int test = 0;
  int recordingEndTime = 0;
  int millisec = 0;
  bool needToRefreshLiveValues = false;
  
  late final ElasticLibListener robotNotificationListener;

  final List<TabData> tabData = [];

  final Function mapEquals = const DeepCollectionEquality().equals;

  late int gridSize =
      preferences.getInt(PrefKeys.gridSize) ?? Defaults.gridSize;

  UpdateCheckerResponse lastUpdateResponse = UpdateCheckerResponse(
    updateAvailable: false,
    error: false,
  );

  int currentTabIndex = 0;

  bool addWidgetDialogVisible = false;

  DashboardPageStateMixin? _state;
  DashboardPageStateMixin? get state => _state;

  DashboardPageViewModel({
    required this.ntConnection,
    required this.preferences,
    required this.version,
    UpdateChecker? updateChecker,
    ElasticLayoutDownloader? layoutDownloader,
    this.onColorChanged,
    this.onThemeVariantChanged,
  }) {
    this.layoutDownloader =
        layoutDownloader ?? ElasticLayoutDownloader(Client());

    this.updateChecker =
        updateChecker ?? UpdateChecker(currentVersion: version);
  }

  Map<String, dynamic> toJson() {
    List<Map<String, dynamic>> gridData = [];

    for (int i = 0; i < tabData.length; i++) {
      TabData data = tabData[i];

      gridData.add({'name': data.name, 'grid_layout': data.tabGrid.toJson()});
    }

    return {'version': 1.0, 'grid_size': gridSize, 'tabs': gridData};
  }

  void init() {
    robotNotificationListener = ElasticLibListener(
      ntConnection: ntConnection,
      onTabSelected: (tabIdentifier) {
        if (tabIdentifier is int) {
          if (tabIdentifier >= tabData.length) {
            return;
          }
          switchToTab(tabIdentifier);
        } else if (tabIdentifier is String) {
          int tabIndex = tabData.indexWhere((tab) => tab.name == tabIdentifier);
          if (tabIndex == -1) {
            return;
          }
          switchToTab(tabIndex);
        }
      },
      onNotification: (title, description, icon, time, width, height) {
        ColorScheme colorScheme = state!.theme.colorScheme;
        TextTheme textTheme = state!.theme.textTheme;
        var widget = ElegantNotification(
          autoDismiss: time.inMilliseconds > 0,
          showProgressIndicator: time.inMilliseconds > 0,
          background: colorScheme.surface,
          width: width,
          height: height,
          position: Alignment.bottomRight,
          title: Text(
            title,
            style: textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.bold),
          ),
          toastDuration: time,
          icon: icon,
          description: Text(description),
          stackedOptions: StackedOptions(
            key: 'robot_notification',
            type: StackedType.above,
          ),
        );
        state!.showNotification(widget);
      },
    );
    robotNotificationListener.listen();

    ntConnection.dsClientConnect(
      onIPAnnounced: (ip) async {
        if (preferences.getInt(PrefKeys.ipAddressMode) !=
            IPAddressMode.driverStation.index) {
          return;
        }

        if (preferences.getString(PrefKeys.ipAddress) != ip) {
          await preferences.setString(PrefKeys.ipAddress, ip);
        } else {
          return;
        }

        ntConnection.changeIPAddress(ip);
      },
      onDriverStationDockChanged: (docked) {
        if ((preferences.getBool(PrefKeys.autoResizeToDS) ??
                Defaults.autoResizeToDS) &&
            docked) {
          onDriverStationDocked();
        } else {
          onDriverStationUndocked();
        }
      },
    );

    ntConnection.addConnectedListener(() {
      for (TabGridModel grid in tabData.map((e) => e.tabGrid)) {
        grid.onNTConnect();
      }
      notifyListeners();
    });

    ntConnection.addDisconnectedListener(() {
      for (TabGridModel grid in tabData.map((e) => e.tabGrid)) {
        grid.onNTDisconnect();
      }
      notifyListeners();
    });

    loadLayout();

    if (!isWPILib) {
      Future(
        () => checkForUpdates(notifyIfLatest: false, notifyIfError: false),
    _layoutDownloader =
        widget.layoutDownloader ?? ElasticLayoutDownloader(Client());

    _updateChecker =
        widget.updateChecker ?? UpdateChecker(currentVersion: widget.version);

    if (!isWPILib) {
      Future(() => _checkForUpdates(
            notifyIfLatest: false,
            notifyIfError: false,
          ));
    }
  }

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    final timeStamp = DateTime.now().millisecondsSinceEpoch;
    return File('$path/recording$timeStamp.json');
  }

  void _stopRecording() {
    print("Total Microseconds: ${recordingEndTime - recordingStartTime}");
    print(
        "Total Seconds: ${(recordingEndTime - recordingStartTime) / 1000000}");
    for (var sub in _recordingSubscriptions.values) {
      widget.ntConnection.unSubscribe(sub);
    }
    _recordingSubscriptions.clear();

    widget.ntConnection.removeTopicAnnounceListener(_onNewTopicDuringRecording);
  }

  Future<void> _saveRecording() async {
    if (recorder.isEmpty) {
      print('No data to save');
      _showWarningNotification(
        title: 'No Recording Data',
        message: 'No data to save',
        width: 300,
      );
      return;
    }

    try {
      final file = await _localFile;
      final initialWidgets = <String, Map<String, dynamic>>{};

      Map<int, NT4Topic> allTopics = widget.ntConnection.announcedTopics();

      for (var topic in allTopics.values) {
        final lastValue = widget.ntConnection.getLastAnnouncedValue(topic.name);
        initialWidgets[topic.name] = {
          'type': topic.type,
          'value': lastValue,
        };
      }

      final Map<int, Map<String, dynamic>> grouped = {};

      for (final entry in recorder) {
        final ts = entry['timestamp'] as int;
        final topic = entry['topic'] as String;
        final value = entry['value'];
        final type = entry['type'];

        grouped.putIfAbsent(
            ts,
            () => {
                  'timestamp': ts,
                  'topics': <String, dynamic>{},
                });

        (grouped[ts]!['topics'] as Map<String, dynamic>)[topic] = {
          'value': value,
          'type': type,
        };
      }

      final frames = grouped.values.toList()
        ..sort(
            (a, b) => (a['timestamp'] as int).compareTo(b['timestamp'] as int));

      // CRITICAL FIX: Extract actual start/end from the data frames
      final start = frames.first['timestamp'] as int;
      final end = frames.last['timestamp'] as int;

      // Update class variables so playback immediately recognizes the duration
      recordingStartTime = start;
      recordingEndTime = end;

      final jsonString = JsonEncoder.withIndent('  ').convert({
        'initialWidgets': initialWidgets,
        'recording_start': start,
        'recording_end': end,
        'sample_count': recorder.length,
        'unique_timestamps': frames.length,
        'data': frames,
      });

      await file.writeAsString(jsonString);
      print('Recording saved to: ${file.path}');

      _showInfoNotification(
        title: 'Recording Saved',
        message: 'Recording saved to: ${file.path}',
        width: 400,
      );
    } catch (e) {
      print('Error saving recording: $e');
      _showErrorNotification(
        title: 'Save Failed',
        message: 'Error saving recording: $e',
        width: 400,
      );
    }
  }

  void _record() async {
    if (widget.ntConnection.isInPlaybackMode) {
      _showWarningNotification(
        title: 'Cannot Record',
        message: 'Cannot start recording during playback',
        width: 300,
      );
      return;
    }

    isRecording = !isRecording;

    if (isRecording) {
      print('Started recording');
      recorder.clear();
      // Reset so the first packet sets the baseline
      recordingStartTime = 0;
      _startRecording();
    } else {
      print('Stopped recording');
      _stopRecording();
      await _saveRecording();
    }

    setState(() {});
  }

  void _onNewTopicDuringRecording(NT4Topic topic) {
    if (!isRecording || _recordingSubscriptions.containsKey(topic.name)) {
      return;
    }

    NT4Subscription sub = widget.ntConnection.subscribe(topic.name, 0.05);
    sub.listen((value, timestamp) {
      if (isRecording) {
        if (recordingStartTime == 0) {
          recordingStartTime = timestamp;
        }
        print('Recording timestamp in New Topic: $timestamp');
        print('Recording startTime in New Topic: $recordingStartTime');
        recorder.add({
          'timestamp': timestamp,
          'server_time': widget.ntConnection.serverTime,
          'topic': topic.name,
          'value': value,
          'type': topic.type,
        });
      }
    });

    _recordingSubscriptions[topic.name] = sub;
  }

  void _startRecording() {
    timer = Timer.periodic(const Duration(milliseconds: 1), (timer) {
      millisec++;
      // print('Recording...'); // Optional: keep if you want to see the count
    });

    Map<int, NT4Topic> topics = widget.ntConnection.announcedTopics();

    for (var topic in topics.values) {
      NT4Subscription sub = widget.ntConnection.subscribe(topic.name, 0.05);

      sub.listen((value, timestamp) {
        if (isRecording) {
          // Fix: Sync the class variable to the robot's microsecond clock on the first packet
          if (recordingStartTime == 0) {
            recordingStartTime = timestamp;
            print('Recording startTime synced to: $recordingStartTime');
          }

          recorder.add({
            'timestamp': timestamp,
            'server_time': widget.ntConnection.serverTime,
            'topic': topic.name,
            'value': value,
            'type': topic.type,
          });
        }
      });

      _recordingSubscriptions[topic.name] = sub;
    }

    widget.ntConnection.addTopicAnnounceListener(_onNewTopicDuringRecording);
  }

// ========== PLAYBACK ==========

  Future<void> loadPlaybackDataFromFile(String filePath) async {
    try {
      print('Loading playback data from $filePath');
      final file = File(filePath);
      final jsonString = await file.readAsString();
      final Map<String, dynamic> rec = json.decode(jsonString);

      final raw = rec['data'] as List<dynamic>;

      playbackData = raw
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList()
        ..sort(
            (a, b) => (a['timestamp'] as int).compareTo(b['timestamp'] as int));

      if (playbackData.isNotEmpty) {
        recordingStartTime = playbackData.first['timestamp'] as int;
        recordingEndTime = playbackData.last['timestamp'] as int;
      }

      recordingStartTime = rec['recording_start'] as int? ??
          (playbackData.isNotEmpty
              ? playbackData.first['timestamp'] as int
              : 0);
      recordingEndTime = rec['recording_end'] as int? ??
          (playbackData.isNotEmpty ? playbackData.last['timestamp'] as int : 0);

      preScanRecording(playbackData);

      final initialWidgets = rec['initialWidgets'] as Map<String, dynamic>?;

      if (initialWidgets != null) {
        final Set<String> topicsToCreate = {};

        // 🟢 ONLY collect topics that have a .type entry
        initialWidgets.forEach((topicName, payload) {
          if (topicName.endsWith('/.type')) {
            // Extract base topic name
            final baseTopic = topicName.substring(0, topicName.length - 6);
            final widgetTypeValue = payload['value'] as String?;

            if (widgetTypeValue != null) {
              topicsToCreate.add(baseTopic);
              print(
                  '✅ Will create widget for: $baseTopic with type: $widgetTypeValue');
            }
          }
        });

        // Now create widgets only for the parent topics (those with .type)
        for (final topicName in topicsToCreate) {
          final widgetType = widgetTypes[topicName];
          if (widgetType == null) continue;

          // Get the initial value from the parent topic (not subtopics)
          final topicData = initialWidgets[topicName];
          final value = topicData?['value'];

          print('🟢 Creating widget: $topicName, Widget type: $widgetType');

          // Call ensureWidgetExists for this topic
          widget.ntConnection.ensureWidgetExists(
            topicName,
            widgetType,
            value,
          );
        }
      }

      playbackIndex = 0;

      _showInfoNotification(
        title: 'Playback Loaded',
        message: 'Loaded ${playbackData.length} frames',
        width: 300,
      );

      setState(() {});
    } catch (e) {
      print('Error loading playback: $e');
      _showErrorNotification(
        title: 'Load Failed',
        message: 'Error loading playback: $e',
        width: 400,
      );
    }
  }

  Future<void> startPlayback() async {
    if (playbackData.isEmpty) {
      print("No playback data loaded");
      _showWarningNotification(
        title: 'No Playback Data',
        message: 'Please load a recording file first',
        width: 300,
      );
      return;
    }

    if (isPlaying) return;

    widget.ntConnection.enterPlaybackMode();

    setState(() => isPlaying = true);

    try {
      while (isPlaying && playbackIndex < playbackData.length) {
        final frame = playbackData[playbackIndex];

        updateWidgetsFromPlayback(frame);

        if (playbackIndex + 1 < playbackData.length) {
          final now = frame['timestamp'] as int; // µs
          final next = playbackData[playbackIndex + 1]['timestamp'] as int;

          int deltaUs = next - now;
          if (deltaUs < 0) deltaUs = 0;

          if (deltaUs > 2 * 1000 * 1000) deltaUs = 2 * 1000 * 1000;

          await Future.delayed(Duration(microseconds: deltaUs));
        }

        playbackIndex++;
        setState(() {}); // Update slider position
      }

      if (playbackIndex >= playbackData.length) {
        print("Playback completed");
        _showInfoNotification(
          title: 'Playback Complete',
          message: 'Playback finished',
          width: 300,
        );
      }
    } finally {
      setState(() => isPlaying = false);

      if (playbackIndex >= playbackData.length) {
        widget.ntConnection.exitPlaybackMode();
        _refreshLiveValues();
      }
    }
  }

  void pausePlayback() {
    setState(() => isPlaying = false);
  }

  void seekPlayback(int newIndex) {
    if (playbackData.isEmpty) return;

    playbackIndex = newIndex.clamp(0, playbackData.length - 1);

    if (playbackIndex < playbackData.length) {
      updateWidgetsFromPlayback(playbackData[playbackIndex]);
    }

    setState(() {});
  }

  String _formatTimestamp(int microSeconds) {
    int elapsedUs = (microSeconds - recordingStartTime);
    print('recording start time: $recordingStartTime');
    print('test time: $test');
    print('end time: $recordingEndTime');
    print('Elapsed us: $elapsedUs');

    if (elapsedUs < 0) {
      return "00:00";
    }

    int totalSeconds = elapsedUs ~/ 1000000;
    int minutes = totalSeconds ~/ 60;
    int seconds = totalSeconds % 60;

    print(
        'Time: ${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}');
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _refreshLiveValues() {
    Map<int, NT4Topic> allTopics = widget.ntConnection.announcedTopics();

    for (var topic in allTopics.values) {
      final currentValue =
          widget.ntConnection.getLastAnnouncedValue(topic.name);

      if (currentValue != null) {
        // Force update the widget with the current live value
        widget.ntConnection.sendPlaybackValue(
          topic.name,
          currentValue,
          topic.type,
          widgetTypes[topic.name] ?? "Text View",
        );
      }
    }

    // Clear the playback cache
    lastSentValues.clear();

    setState(() {});
  }

  void preScanRecording(List<Map<String, dynamic>> rows) {
    final Map<String, String> detectedWidgetTypes = {};

    for (final row in rows) {
      final topics = row['topics'] as Map<String, dynamic>?;
      if (topics == null) continue;

      topics.forEach((topicName, payload) {
        if (topicName.endsWith('/.type')) {
          final base = topicName.substring(0, topicName.length - 6);
          final widgetTypeValue = payload['value'] as String;
          detectedWidgetTypes[base] = widgetTypeValue;
          print('✅ Found widget type: $base = $widgetTypeValue');
        }
      });
    }

    widgetTypes = detectedWidgetTypes;
    print(
        '📊 PreScan complete. Found ${detectedWidgetTypes.length} widget types');
    print('Widget types map: $detectedWidgetTypes');
  }

  Future<void> updateWidgetsFromPlayback(Map<String, dynamic> row) async {
    final topics = row['topics'] as Map<String, dynamic>?;
    if (topics == null) return;

    final List<_PlaybackEntry> buffer = [];

    for (final entry in topics.entries) {
      final topicName = entry.key;

      if (topicName.endsWith('/.type')) continue;
      final value = entry.value['value'];
      final type = entry.value['type'] ?? '';
      final widgetType = widgetTypes[topicName] ?? "Text View";

      if (lastSentValues[topicName] != value) {
        lastSentValues[topicName] = value;

        buffer.add(
          _PlaybackEntry(
            topic: topicName,
            value: value,
            type: type,
            widgetType: widgetType,
          ),
        );
      }
    }

    for (final entry in buffer) {
      widget.ntConnection.sendPlaybackValue(
        entry.topic,
        entry.value,
        entry.type,
        entry.widgetType,
      );
    }
  }

  Future<String?> pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result != null && result.files.single.path != null) {
      return result.files.single.path!;
    }
    return null;
  }

  @override
  void onWindowClose() async {
    Map<String, dynamic> savedJson =
        jsonDecode(preferences.getString(PrefKeys.layout) ?? '{}');
    Map<String, dynamic> currentJson = _toJson();

    bool showConfirmation = !_mapEquals(savedJson, currentJson);

    if (showConfirmation) {
      _showWindowCloseConfirmation(context);
      await windowManager.focus();
    } else {
      await _closeWindow();
    }
  }

  Future<void> _closeWindow() async {
    await _saveWindowPosition();
    await windowManager.destroy();
    exit(0);
  }

  @override
  void dispose() async {
    windowManager.removeListener(this);
    super.dispose();
  }

  Map<String, dynamic> _toJson() {
    List<Map<String, dynamic>> gridData = [];

    for (int i = 0; i < _tabData.length; i++) {
      TabData data = _tabData[i];

      gridData.add({
        'name': data.name,
        'grid_layout': data.tabGrid.toJson(),
      });
    }

    return {
      'version': 1.0,
      'grid_size': _gridSize,
      'tabs': gridData,
    };
  }

  Future<void> _saveLayout() async {
    Map<String, dynamic> jsonData = _toJson();

    bool successful =
        await preferences.setString(PrefKeys.layout, jsonEncode(jsonData));
    await _saveWindowPosition();

    if (successful) {
      logger.info('Layout saved successfully');
      _showInfoNotification(
        title: 'Saved',
        message: 'Layout saved successfully',
        width: 300,
      );
    } else {
      logger.error('Could not save layout');
      _showInfoNotification(
        title: 'Error While Saving Layout',
        message: 'Failed to save layout, please try again',
        width: 300,
      );
    }
  }

  bool hasUnsavedChanges() {
    Map<String, dynamic> savedJson = jsonDecode(
      preferences.getString(PrefKeys.layout) ?? '{}',
    );
    Map<String, dynamic> currentJson = toJson();

    return !mapEquals(savedJson, currentJson);
  }

  Future<void> saveLayout() async {}

  Future<void> saveWindowPosition() async {}

  Future<void> checkForUpdates({
    bool notifyIfLatest = true,
    bool notifyIfError = true,
  }) async {
    ColorScheme colorScheme = state!.theme.colorScheme;
    TextTheme textTheme = state!.theme.textTheme;
    ButtonThemeData buttonTheme = state!.buttonTheme;

    UpdateCheckerResponse updateResponse = await updateChecker!
        .isUpdateAvailable();

    lastUpdateResponse = updateResponse;
    notifyListeners();

    if (updateResponse.error && notifyIfError) {
      ElegantNotification notification = ElegantNotification(
        background: colorScheme.surface,
        progressIndicatorBackground: colorScheme.surface,
        progressIndicatorColor: const Color(0xffFE355C),
        width: 350,
        height: 100,
        position: Alignment.bottomRight,
        toastDuration: const Duration(seconds: 3, milliseconds: 500),
        icon: const Icon(Icons.error, color: Color(0xffFE355C)),
        title: Text(
          'Failed to check for updates',
          style: textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.bold),
        ),
        description: Text(
          updateResponse.errorMessage!,
          overflow: TextOverflow.ellipsis,
          maxLines: 3,
        ),
      );

      state!.showNotification(notification);
      return;
    }

    if (updateResponse.updateAvailable) {
      ElegantNotification notification = ElegantNotification(
        autoDismiss: false,
        showProgressIndicator: false,
        background: colorScheme.surface,
        width: 350,
        height: 100,
        position: Alignment.bottomRight,
        title: Text(
          'Version ${updateResponse.latestVersion!} Available',
          style: textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.bold),
        ),
        icon: const Icon(Icons.info, color: Color(0xff0066FF)),
        description: const Text('A new update is available!'),
        action: TextButton(
          onPressed: () async {
            Uri url = Uri.parse(Settings.releasesLink);

            if (await canLaunchUrl(url)) {
              await launchUrl(url);
            }
          },
          child: Text(
            'Update',
            style: textTheme.bodyMedium!.copyWith(
              color: buttonTheme.colorScheme?.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );

      state!.showNotification(notification);
    } else if (updateResponse.onLatestVersion && notifyIfLatest) {
      showInfoNotification(
        title: 'No Updates Available',
        message: 'You are running on the latest version of Elastic',
        width: 350,
        height: 75,
      );
    }
  }

  Future<void> exportLayout() async {}

  Future<void> importLayout() async {}

  void loadLayout() {}

  bool validateJsonData(Map<String, dynamic>? jsonData) => false;

  void clearLayout() {}

  bool loadLayoutFromJsonData(String jsonString) => false;

  bool mergeLayoutFromJsonData(String jsonString) => false;

  void overwriteLayoutFromJsonData(String jsonString) {}

  Future<({String layout, LayoutDownloadMode mode})?> showRemoteLayoutSelection(
    List<String> fileNames,
  ) => Future.value(null);

  Future<void> loadLayoutFromRobot() async {}

  void createDefaultTabs() {}

  void lockLayout() {}

  void unlockLayout() {}

  void displayAddWidgetDialog() {
    logger.info('Displaying add widget dialog');
    addWidgetDialogVisible = true;
    notifyListeners();
  }

  void displayAboutDialog(BuildContext context) {
    logger.info('Displaying about dialog');
    IconThemeData iconTheme = IconTheme.of(context);

    showAboutDialog(
      context: context,
      applicationName: appTitle,
      applicationVersion: version,
      applicationIcon: Image.asset(
        logoPath,
        width: iconTheme.size,
        height: iconTheme.size,
      ),
      children: [
        Container(
          constraints: const BoxConstraints(maxWidth: 353),
          child: const Text(
            'Elastic was created by Nadav from FRC Team 353, the POBots, in the Summer of 2023.\n',
          ),
        ),
        Container(
          constraints: const BoxConstraints(maxWidth: 353),
          child: const Text(
            'The goal of Elastic is to have the essential features needed for a driver dashboard, but with an elegant and modern display and a focus on customizability and performance.\n',
          ),
        ),
        Container(
          constraints: const BoxConstraints(maxWidth: 353),
          child: const Text(
            'Elastic is an ongoing project; if you have any ideas, feedback, or bug reports, feel free to share them on the Github page!\n',
          ),
        ),
        Container(
          constraints: const BoxConstraints(maxWidth: 353),
          child: const Text(
            'Elastic was built with inspiration from Shuffleboard and AdvantageScope, along with significant help from FRC and WPILib developers.\n',
          ),
        ),
        Row(
          children: [
            TextButton(
              onPressed: () async {
                Uri url = Uri.parse(Settings.repositoryLink);

                if (await canLaunchUrl(url)) {
                  await launchUrl(url);
                }
              },
              child: const Text('View Repository'),
            ),
            const Spacer(),
          ],
        ),
      ],
    );
  }

  void displaySettingsDialog(BuildContext context) {}

  Future<void> changeIPAddressMode(IPAddressMode mode) async {}

  Future<void> updateIPAddress(String newIPAddress) async {}

  Future<void> onDriverStationDocked() async {}

  Future<void> onDriverStationUndocked() async {}

  void showWindowCloseConfirmation(BuildContext context) {}

  void showTabCloseConfirmation(
    BuildContext context,
    String tabName,
    Function() onClose,
  ) {}

  void switchToTab(int tabIndex) {}

  void moveTabLeft() {}

  void moveTabRight() {}

  void moveToNextTab() {}

  void moveToPreviousTab() {}

  void showJsonLoadingError(String errorMessage) {}

  void showJsonLoadingWarning(String warningMessage) {}

  void showInfoNotification({
    required String title,
    required String message,
    Duration toastDuration = const Duration(seconds: 3, milliseconds: 500),
    double? width,
    double? height,
  }) {}

  void showWarningNotification({
    required String title,
    required String message,
    Duration toastDuration = const Duration(seconds: 3, milliseconds: 500),
    double? width,
    double? height,
  }) {}

  void showErrorNotification({
    required String title,
    required String message,
    Duration toastDuration = const Duration(seconds: 3, milliseconds: 500),
    double? width,
    double? height,
  }) {}

  void showNotification({
    required String title,
    required String message,
    required Color color,
    required Widget icon,
    Duration toastDuration = const Duration(seconds: 3, milliseconds: 500),
    double? width,
    double? height,
  }) {}
}

class DashboardPageViewModelImpl = DashboardPageViewModel
    with
        DashboardPageNotifications,
        DashboardPageLayouts,
        DashboardPageSettings,
        DashboardPageTabs,
        DashboardPageWindow;

class DashboardPage extends StatefulWidget {
  final DashboardPageViewModel model;

  const DashboardPage({super.key, required this.model});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with WindowListener, DashboardPageStateMixin {
  SharedPreferences get preferences => widget.model.preferences;
  DashboardPageViewModel get model => widget.model;

  @override
  void initState() {
    super.initState();

    model._state = this;
    model.init();

    model.addListener(onModelUpdate);

    windowManager.addListener(this);
    setupUnloadHandler(() => model.hasUnsavedChanges());
    if (!isUnitTest) {
      Future(() async => await windowManager.setPreventClose(true));
    }

    _setupShortcuts();
  }

  void onModelUpdate() => setState(() {});

  @override
  void onWindowClose() async {
    bool showConfirmation = model.hasUnsavedChanges();

    if (showConfirmation) {
      widget.model.showWindowCloseConfirmation(context);
      await windowManager.focus();
    } else {
      await closeWindow();
    }
  }

  @override
  Future<void> closeWindow() async {
    await model.saveWindowPosition();
    await windowManager.destroy();
    exit(0);
  }

  @override
  void didUpdateWidget(DashboardPage oldWidget) {
    if (widget.model != oldWidget.model) {
      oldWidget.model.removeListener(onModelUpdate);
      oldWidget.model._state = null;

      widget.model.addListener(onModelUpdate);
      widget.model._state = this;
      widget.model.init();
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    removeUnloadHandler();
    windowManager.removeListener(this);
    model._state = null;
    model.removeListener(onModelUpdate);
    super.dispose();
  }

  void _setupShortcuts() {
    logger.info('Setting up shortcuts');
    // Import Layout (Ctrl + O)
    hotKeyManager.register(
      HotKey(LogicalKeyboardKey.keyO, modifiers: [KeyModifier.control]),
      callback: model.importLayout,
    );
    // Save (Ctrl + S)
    hotKeyManager.register(
      HotKey(LogicalKeyboardKey.keyS, modifiers: [KeyModifier.control]),
      callback: model.saveLayout,
    );
    // Export (Ctrl + Shift + S)
    hotKeyManager.register(
      HotKey(
        LogicalKeyboardKey.keyS,
        modifiers: [KeyModifier.control, KeyModifier.shift],
      ),
      callback: model.exportLayout,
    );
    // Download from robot (Ctrl + D)
    hotKeyManager.register(
      HotKey(LogicalKeyboardKey.keyD, modifiers: [KeyModifier.control]),
      callback: () {
        if (preferences.getBool(PrefKeys.layoutLocked) ??
            Defaults.layoutLocked) {
          return;
        }

        model.loadLayoutFromRobot();
      },
    );
    // Switch to Tab (Ctrl + Tab #)
    for (int i = 1; i <= 9; i++) {
      hotKeyManager.register(
        HotKey(LogicalKeyboardKey(48 + i), modifiers: [KeyModifier.control]),
        callback: () {
          if (model.currentTabIndex == i - 1) {
            logger.debug(
              'Ignoring switch to tab ${i - 1}, current tab is already ${model.currentTabIndex}',
            );
            return;
          }
          if (i - 1 < model.tabData.length) {
            logger.info(
              'Switching tab to index ${i - 1} via keyboard shortcut',
            );
            model.switchToTab(i - 1);
          }
        },
      );
    }
    // Move to next tab (Ctrl + Tab)
    hotKeyManager.register(
      HotKey(LogicalKeyboardKey.tab, modifiers: [KeyModifier.control]),
      callback: () {
        if (ModalRoute.of(context)?.isCurrent ?? false) {
          model.moveToNextTab();
        }
      },
    );
    // Move to prevoius tab (Ctrl + Shift + Tab)
    hotKeyManager.register(
      HotKey(
        LogicalKeyboardKey.tab,
        modifiers: [KeyModifier.control, KeyModifier.shift],
      ),
      callback: () {
        if (ModalRoute.of(context)?.isCurrent ?? false) {
          model.moveToPreviousTab();
        }
      },
    );
    // Move Tab Left (Ctrl + <-)
    hotKeyManager.register(
      HotKey(LogicalKeyboardKey.arrowLeft, modifiers: [KeyModifier.control]),
      callback: () {
        if (ModalRoute.of(context)?.isCurrent ?? false) {
          model.moveTabLeft();
        }
      },
    );
    // Move Tab Right (Ctrl + ->)
    hotKeyManager.register(
      HotKey(LogicalKeyboardKey.arrowRight, modifiers: [KeyModifier.control]),
      callback: () {
        if (ModalRoute.of(context)?.isCurrent ?? false) {
          model.moveTabRight();
        }
      },
    );
    // New Tab (Ctrl + T)
    hotKeyManager.register(
      HotKey(LogicalKeyboardKey.keyT, modifiers: [KeyModifier.control]),
      callback: () {
        if (preferences.getBool(PrefKeys.layoutLocked) ??
            Defaults.layoutLocked) {
          return;
        }
        String newTabName = 'Tab ${model.tabData.length + 1}';
        int newTabIndex = model.tabData.length;

        model.tabData.add(
          TabData(
            name: newTabName,
            tabGrid: TabGridModel(
              ntConnection: model.ntConnection,
              preferences: model.preferences,
              onAddWidgetPressed: model.displayAddWidgetDialog,
            ),
          ),
        );

        model.switchToTab(newTabIndex);
      },
    );
    // Close Tab (Ctrl + W)
    hotKeyManager.register(
      HotKey(LogicalKeyboardKey.keyW, modifiers: [KeyModifier.control]),
      callback: () {
        if (preferences.getBool(PrefKeys.layoutLocked) ??
            Defaults.layoutLocked) {
          return;
        }
        if (model.tabData.length <= 1) {
          return;
        }

        TabData currentTab = model.tabData[model.currentTabIndex];

        model.showTabCloseConfirmation(context, currentTab.name, () {
          int oldTabIndex = model.currentTabIndex;

          if (model.currentTabIndex == model.tabData.length - 1) {
            model.currentTabIndex--;
          }

          model.tabData[oldTabIndex].tabGrid.onDestroy();

          setState(() {
            model.tabData[oldTabIndex].tabGrid.dispose();
            model.tabData.removeAt(oldTabIndex);
          });
        });
      },
    );
    // Open settings dialog (Ctrl + ,)
    hotKeyManager.register(
      HotKey(LogicalKeyboardKey.comma, modifiers: [KeyModifier.control]),
      callback: () {
        if ((ModalRoute.of(context)?.isCurrent ?? false) && mounted) {
          model.displaySettingsDialog(context);
        }
      },
    );
    // Connect to robot (Ctrl + K)
    hotKeyManager.register(
      HotKey(LogicalKeyboardKey.keyK, modifiers: [KeyModifier.control]),
      callback: () {
        if (preferences.getInt(PrefKeys.ipAddressMode) ==
            IPAddressMode.driverStation.index) {
          return;
        }
        model.updateIPAddress(
          IPAddressUtil.teamNumberToIP(
            preferences.getInt(PrefKeys.teamNumber) ?? Defaults.teamNumber,
          ),
        );
        model.changeIPAddressMode(IPAddressMode.driverStation);
      },
    );
    // Connect to sim (Ctrl + Shift + K)
    hotKeyManager.register(
      HotKey(
        LogicalKeyboardKey.keyK,
        modifiers: [KeyModifier.control, KeyModifier.shift],
      ),
      callback: () {
        if (preferences.getInt(PrefKeys.ipAddressMode) ==
            IPAddressMode.localhost.index) {
          return;
        }
        widget.model.changeIPAddressMode(IPAddressMode.localhost);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final double windowWidth = MediaQuery.of(context).size.width;

    TextStyle? menuTextStyle = Theme.of(context).textTheme.bodySmall;
    TextStyle? footerStyle = Theme.of(context).textTheme.bodyMedium;
    ButtonStyle menuButtonStyle = ButtonStyle(
      alignment: Alignment.center,
      textStyle: WidgetStatePropertyAll(menuTextStyle),
      backgroundColor: const WidgetStatePropertyAll(
        Color.fromARGB(255, 25, 25, 25),
      ),
      minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
      iconSize: const WidgetStatePropertyAll(20.0),
    );

    final bool layoutLocked =
        preferences.getBool(PrefKeys.layoutLocked) ?? Defaults.layoutLocked;

    late final double platformWidthAdjust;
    if (!kIsWeb) {
      if (Platform.isMacOS) {
        platformWidthAdjust = 30;
      } else if (Platform.isLinux) {
        platformWidthAdjust = 10;
      } else {
        platformWidthAdjust = 0;
      }
    } else {
      platformWidthAdjust = 0;
    }

    final double minWindowWidth =
        platformWidthAdjust + (layoutLocked ? 500 : 460);
    final bool consolidateMenu = windowWidth < minWindowWidth;

    List<Widget> menuChildren = [
      // File
      SubmenuButton(
        style: menuButtonStyle,
        menuChildren: [
          // Open Layout
          MenuItemButton(
            style: menuButtonStyle,
            onPressed: !layoutLocked ? model.importLayout : null,
            shortcut: const SingleActivator(
              LogicalKeyboardKey.keyO,
              control: true,
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.folder_open_outlined),
                SizedBox(width: 8),
                Text('Open Layout'),
              ],
            ),
          ),
          // Save
          MenuItemButton(
            style: menuButtonStyle,
            onPressed: model.saveLayout,
            shortcut: const SingleActivator(
              LogicalKeyboardKey.keyS,
              control: true,
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.save_outlined),
                SizedBox(width: 8),
                Text('Save'),
              ],
            ),
          ),
          // Export layout
          MenuItemButton(
            style: menuButtonStyle,
            onPressed: model.exportLayout,
            shortcut: const SingleActivator(
              LogicalKeyboardKey.keyS,
              shift: true,
              control: true,
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.save_as_outlined),
                SizedBox(width: 8),
                Text('Save As'),
              ],
            ),
          ),
          // Download layout
          MenuItemButton(
            style: menuButtonStyle,
            onPressed: !layoutLocked ? model.loadLayoutFromRobot : null,
            shortcut: const SingleActivator(
              LogicalKeyboardKey.keyD,
              control: true,
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.download),
                SizedBox(width: 8),
                Text('Download From Robot'),
              ],
            ),
          ),
        ],
        child: const Text('File'),
      ),
      // Edit
      SubmenuButton(
        style: menuButtonStyle,
        menuChildren: [
          // Clear layout
          MenuItemButton(
            style: menuButtonStyle,
            onPressed: !layoutLocked
                ? () {
                    setState(() {
                      model.tabData[model.currentTabIndex].tabGrid
                          .confirmClearWidgets(context);
                    });
                  }
                : null,
            leadingIcon: const Icon(Icons.clear),
            child: const Text('Clear Layout'),
          ),
          // Lock/Unlock Layout
          MenuItemButton(
            style: menuButtonStyle,
            onPressed: () {
              if (layoutLocked) {
                model.unlockLayout();
              } else {
                model.lockLayout();
              }

              setState(() {});
            },
            leadingIcon: layoutLocked
                ? const Icon(Icons.lock_open)
                : const Icon(Icons.lock_outline),
            child: Text('${layoutLocked ? 'Unlock' : 'Lock'} Layout'),
          ),
        ],
        child: const Text('Edit'),
      ),
      // Help
      SubmenuButton(
        style: menuButtonStyle,
        menuChildren: [
          // About
          MenuItemButton(
            style: menuButtonStyle,
            onPressed: () {
              model.displayAboutDialog(context);
            },
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.info_outline),
                SizedBox(width: 8),
                Text('About'),
              ],
            ),
          ),
          // Check for Updates (not for WPILib distribution)
          if (!isWPILib)
            MenuItemButton(
              style: menuButtonStyle,
              onPressed: () => model.checkForUpdates(),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.update_outlined),
                  SizedBox(width: 8),
                  Text('Check for Updates'),
                ],
              ),
            ),
        ],
        child: const Text('Help'),
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (playbackData.isNotEmpty)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  children: [
                    Text(
                      _formatTimestamp(playbackIndex < playbackData.length
                          ? playbackData[playbackIndex]['timestamp'] as int
                          : recordingEndTime),
                      style: TextStyle(fontSize: 11),
                    ),
                    Expanded(
                      child: Slider(
                        value: playbackIndex
                            .toDouble()
                            .clamp(0, (playbackData.length - 1).toDouble()),
                        min: 0,
                        max: (playbackData.length - 1).toDouble(),
                        divisions: playbackData.length > 1
                            ? playbackData.length - 1
                            : 1,
                        onChanged: (value) {
                          if (!isPlaying) {
                            seekPlayback(value.toInt());
                          }
                        },
                        onChangeStart: (value) {
                          if (isPlaying) {
                            pausePlayback();
                          }
                        },
                      ),
                    ),
                    Text(
                      _formatTimestamp(recordingEndTime),
                      style: TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          IconButton(
            onPressed: () {
              setState(() {
                _record();
              });
            },
            icon: isRecording
                ? Icon(Icons.stop)
                : Icon(Icons.emergency_recording),
          ),
          IconButton(
            icon: isPlaying ? Icon(Icons.pause) : Icon(Icons.play_arrow),
            onPressed: () {
              if (isPlaying) {
                pausePlayback();
              } else if (playbackData.isNotEmpty) {
                startPlayback();
              }
            },
          ),
          IconButton(
            icon: Icon(Icons.folder_open),
            tooltip: 'Open Recording File',
            onPressed: () async {
              String? path = await pickFile();
              if (path != null) {
                await loadPlaybackDataFromFile(path);
              }
            },
          ),
        ],
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (playbackData.isNotEmpty)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  children: [
                    Text(
                      _formatTimestamp(playbackIndex < playbackData.length
                          ? playbackData[playbackIndex]['timestamp'] as int
                          : recordingEndTime),
                      style: TextStyle(fontSize: 11),
                    ),
                    Expanded(
                      child: Slider(
                        value: playbackIndex
                            .toDouble()
                            .clamp(0, (playbackData.length - 1).toDouble()),
                        min: 0,
                        max: (playbackData.length - 1).toDouble(),
                        divisions: playbackData.length > 1
                            ? playbackData.length - 1
                            : 1,
                        onChanged: (value) {
                          if (!isPlaying) {
                            seekPlayback(value.toInt());
                          }
                        },
                        onChangeStart: (value) {
                          if (isPlaying) {
                            pausePlayback();
                          }
                        },
                      ),
                    ),
                    Text(
                      _formatTimestamp(recordingEndTime),
                      style: TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          IconButton(
            onPressed: () {
              setState(() {
                _record();
              });
            },
            icon: isRecording
                ? Icon(Icons.stop)
                : Icon(Icons.emergency_recording),
          ),
          IconButton(
            icon: isPlaying ? Icon(Icons.pause) : Icon(Icons.play_arrow),
            onPressed: () {
              if (isPlaying) {
                pausePlayback();
              } else if (playbackData.isNotEmpty) {
                startPlayback();
              }
            },
          ),
          IconButton(
            icon: Icon(Icons.folder_open),
            tooltip: 'Open Recording File',
            onPressed: () async {
              String? path = await pickFile();
              if (path != null) {
                await loadPlaybackDataFromFile(path);
              }
            },
          ),
        ],
      ),
    ];

    MenuBar menuBar = MenuBar(
      style: const MenuStyle(
        backgroundColor: WidgetStatePropertyAll(
          Color.fromARGB(255, 25, 25, 25),
        ),
        elevation: WidgetStatePropertyAll(0),
      ),
      children: [
        Center(child: Image.asset(logoPath, width: 24, height: 24)),
        const SizedBox(width: 5),
        if (!consolidateMenu)
          ...menuChildren
        else
          SubmenuButton(
            style: menuButtonStyle.copyWith(
              iconSize: const WidgetStatePropertyAll(24),
            ),
            menuChildren: menuChildren,
            child: const Icon(Icons.menu),
          ),
        const VerticalDivider(width: 4),
        // Settings
        MenuItemButton(
          style: menuButtonStyle,
          leadingIcon: const Icon(Icons.settings),
          onPressed: () {
            model.displaySettingsDialog(context);
          },
          child: const Text('Settings'),
        ),
        const VerticalDivider(width: 4),
        // Add Widget
        MenuItemButton(
          style: menuButtonStyle,
          leadingIcon: const Icon(Icons.add),
          onPressed: !layoutLocked
              ? () => model.displayAddWidgetDialog()
              : null,
          child: const Text('Add Widget'),
        ),
        if (layoutLocked) ...[
          const VerticalDivider(width: 4),
          // Unlock Layout
          Tooltip(
            message: 'Unlock Layout',
            child: MenuItemButton(
              style: menuButtonStyle.copyWith(
                minimumSize: const WidgetStatePropertyAll(
                  Size(36.0, double.infinity),
                ),
                maximumSize: const WidgetStatePropertyAll(
                  Size(36.0, double.infinity),
                ),
              ),
              onPressed: () {
                model.unlockLayout();
                setState(() {});
              },
              child: const Icon(Icons.lock_outline),
            ),
          ),
        ],
      ],
    );

    Widget? updateButton;
    if (model.lastUpdateResponse.updateAvailable) {
      updateButton = IconButton(
        style: const ButtonStyle(
          shape: WidgetStatePropertyAll(RoundedRectangleBorder()),
          maximumSize: WidgetStatePropertyAll(Size.square(34.0)),
          minimumSize: WidgetStatePropertyAll(Size.zero),
          padding: WidgetStatePropertyAll(EdgeInsets.all(4.0)),
          iconSize: WidgetStatePropertyAll(24.0),
        ),
        tooltip: 'Download version ${model.lastUpdateResponse.latestVersion}',
        onPressed: () async {
          Uri url = Uri.parse(Settings.releasesLink);

          if (await canLaunchUrl(url)) {
            await launchUrl(url);
          }
        },
        icon: const Icon(Icons.update, color: Colors.orange),
      );
    }

    return Scaffold(
      appBar: CustomAppBar(
        titleText: appTitle,
        onWindowClose: onWindowClose,
        leading: menuBar,
      ),
      body: Focus(
        autofocus: true,
        canRequestFocus: true,
        descendantsAreTraversable: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Main dashboard page
            Expanded(
              child: Stack(
                children: [
                  EditableTabBar(
                    preferences: preferences,
                    gridDpiOverride: preferences.getDouble(
                      PrefKeys.gridDpiOverride,
                    ),
                    updateButton: updateButton,
                    currentIndex: model.currentTabIndex,
                    onTabMoveLeft: model.moveTabLeft,
                    onTabMoveRight: model.moveTabRight,
                    onTabRename: (index, newData) =>
                        setState(() => model.tabData[index] = newData),
                    onTabCreate: () {
                      String tabName = 'Tab ${model.tabData.length + 1}';
                      setState(() {
                        model.tabData.add(
                          TabData(
                            name: tabName,
                            tabGrid: TabGridModel(
                              ntConnection: model.ntConnection,
                              preferences: model.preferences,
                              onAddWidgetPressed: model.displayAddWidgetDialog,
                            ),
                          ),
                        );
                      });
                    },
                    onTabDestroy: (index) {
                      if (model.tabData.length <= 1) {
                        return;
                      }

                      TabData tabToRemove = model.tabData[index];

                      model.showTabCloseConfirmation(
                        context,
                        tabToRemove.name,
                        () {
                          int indexToSwitch = model.currentTabIndex;

                          if (indexToSwitch == model.tabData.length - 1) {
                            indexToSwitch--;
                          }

                          tabToRemove.tabGrid.onDestroy();
                          tabToRemove.tabGrid.dispose();

                          setState(() => model.tabData.remove(tabToRemove));
                          model.switchToTab(indexToSwitch);
                        },
                      );
                    },
                    onTabChanged: model.switchToTab,
                    onTabDuplicate: (index) {
                      setState(() {
                        Map<String, dynamic> tabJson = model
                            .tabData[index]
                            .tabGrid
                            .toJson();
                        TabGridModel newGrid = TabGridModel.fromJson(
                          ntConnection: model.ntConnection,
                          preferences: preferences,
                          jsonData: tabJson,
                          onAddWidgetPressed: model.displayAddWidgetDialog,
                          onJsonLoadingWarning: model.showJsonLoadingWarning,
                        );
                        model.tabData.insert(
                          index + 1,
                          TabData(
                            name: '${model.tabData[index].name} (Copy)',
                            tabGrid: newGrid,
                          ),
                        );
                      });
                    },
                    tabData: model.tabData,
                  ),
                  if (model.addWidgetDialogVisible)
                    AddWidgetDialog(
                      ntConnection: model.ntConnection,
                      preferences: model.preferences,
                      grid: model.tabData[model.currentTabIndex].tabGrid,
                      gridIndex: model.currentTabIndex,
                      onNTDragUpdate: (globalPosition, widget) {
                        model.tabData[model.currentTabIndex].tabGrid
                            .addDragInWidget(widget, globalPosition);
                      },
                      onNTDragEnd: (widget) {
                        model.tabData[model.currentTabIndex].tabGrid
                            .placeDragInWidget(widget);
                      },
                      onLayoutDragUpdate: (globalPosition, widget) {
                        model.tabData[model.currentTabIndex].tabGrid
                            .addDragInWidget(widget, globalPosition);
                      },
                      onLayoutDragEnd: (widget) {
                        model.tabData[model.currentTabIndex].tabGrid
                            .placeDragInWidget(widget);
                      },
                      onClose: () =>
                          setState(() => model.addWidgetDialogVisible = false),
                    ),
                ],
              ),
            ),
            // Bottom bar
            DashboardPageFooter(
              model: model,
              preferences: preferences,
              footerStyle: footerStyle,
              windowWidth: windowWidth,
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaybackEntry {
  final String topic;
  final dynamic value;
  final String type;
  final String widgetType;

  _PlaybackEntry({
    required this.topic,
    required this.value,
    required this.type,
    required this.widgetType,
  });
}

class _PlaybackEntry {
  final String topic;
  final dynamic value;
  final String type;
  final String widgetType;

  _PlaybackEntry({
    required this.topic,
    required this.value,
    required this.type,
    required this.widgetType,
  });
}
