import 'package:flutter/material.dart';
import 'package:dot_cast/dot_cast.dart';
import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import 'package:mjpeg_stream/mjpeg_stream.dart';
import 'package:provider/provider.dart';

/// =============================
///          HELPERS
/// =============================
double _asDouble(Object? v, {double fallback = 0.0}) {
  if (v == null) return fallback;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  if (v is num) return v.toDouble();
  if (v is bool) return v ? 1.0 : 0.0;
  return fallback;
}

int _asInt(Object? v, {int fallback = 0}) {
  if (v == null) return fallback;
  if (v is int) return v;
  if (v is double) return v.round();
  if (v is num) return v.round();
  if (v is bool) return v ? 1 : 0;
  return fallback;
}

bool _asBool(Object? v, {bool fallback = false}) {
  if (v == null) return fallback;
  if (v is bool) return v;
  if (v is num) return v != 0;
  return fallback;
}

/// Clamp helper
double _clamp(double v, double min, double max) => v < min ? min : (v > max ? max : v);

/// Build a 4x5 color matrix (20 values) for brightness/contrast/saturation.
List<double> _colorMatrix({
  required double brightness, // -1..1
  required double contrast,   // 0..2
  required double saturation, // 0..2
}) {
  // Luma coefficients (Rec. 709-ish)
  const double rw = 0.2126;
  const double gw = 0.7152;
  const double bw = 0.0722;

  // Saturation matrix
  final double a = (1 - saturation) * rw + saturation;
  final double b = (1 - saturation) * rw;
  final double c = (1 - saturation) * rw;

  final double d = (1 - saturation) * gw;
  final double e = (1 - saturation) * gw + saturation;
  final double f = (1 - saturation) * gw;

  final double g = (1 - saturation) * bw;
  final double h = (1 - saturation) * bw;
  final double i = (1 - saturation) * bw + saturation;

  // Contrast + Brightness:
  // new = contrast * old + bias
  // bias in [0..255] terms would be 128*(1-contrast) + brightness*255
  // But matrix expects bias in 0..255 space, Flutter uses 0..255 bias too.
  final double bias = 128.0 * (1 - contrast) + (brightness * 255.0);

  return <double>[
    contrast * a, contrast * d, contrast * g, 0, bias,
    contrast * b, contrast * e, contrast * h, 0, bias,
    contrast * c, contrast * f, contrast * i, 0, bias,
    0,           0,           0,           1, 0,
  ];
}

/// =============================
///          MODEL
/// =============================
class LimelightModel extends MultiTopicNTWidgetModel {
  @override
  String type = LimelightWidget.widgetType;

  // Live data
  double tx = 0.0;
  double ty = 0.0;
  double ta = 0.0;
  bool hasTarget = false;

  // Readback values
  int pipeline = 0;

  // Controls (cache)
  int exposure = 3000;
  int blackLevel = 0;
  int gain = 0;

  int ledMode = 0;
  int camMode = 0;

  // ✅ Filters (display-only on Elastic, synced via NT)
  double filterBrightness = 0.0; // -1..1
  double filterContrast = 1.0;   // 0..2
  double filterSaturation = 1.0; // 0..2

  // Camera stream URL (MJPEG)
  String cameraUrl = '';

  // Topics - read from dashboard bridge table (matches widget topic in Elastic)
  String get txTopic => '$topic/tx';
  String get tyTopic => '$topic/ty';
  String get taTopic => '$topic/ta';
  String get tvTopic => '$topic/tv';

  String get pipelineTopic => '$topic/pipeline';

  // Camera settings topics (you can keep these, but they won't affect Limelight without REST/UI)
  String get exposureTopic => '$topic/exposure';
  String get blackLevelTopic => '$topic/blackLevel';
  String get gainTopic => '$topic/gain';

  String get ledModeTopic => '$topic/ledMode';
  String get camModeTopic => '$topic/camMode';

  // Control topics (outputs)
  String get pipelineControlTopic => '$topic/pipelineControl';

  // ✅ Filter topics
  String get filterBrightnessTopic => '$topic/filterBrightness';
  String get filterContrastTopic => '$topic/filterContrast';
  String get filterSaturationTopic => '$topic/filterSaturation';

  late NT4Subscription txSub;
  late NT4Subscription tySub;
  late NT4Subscription taSub;
  late NT4Subscription tvSub;

  late NT4Subscription pipelineSub;

  late NT4Subscription exposureSub;
  late NT4Subscription blackLevelSub;
  late NT4Subscription gainSub;
  late NT4Subscription ledModeSub;
  late NT4Subscription camModeSub;

  // ✅ Filter subs
  late NT4Subscription filterBrightnessSub;
  late NT4Subscription filterContrastSub;
  late NT4Subscription filterSaturationSub;

  @override
  List<NT4Subscription> get subscriptions => [
        txSub,
        tySub,
        taSub,
        tvSub,
        pipelineSub,
        exposureSub,
        blackLevelSub,
        gainSub,
        ledModeSub,
        camModeSub,
        filterBrightnessSub,
        filterContrastSub,
        filterSaturationSub,
      ];

  LimelightModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    super.period,
    super.dataType,
    String cameraUrl = '',
  }) : cameraUrl = cameraUrl;

  LimelightModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required Map<String, dynamic> jsonData,
  }) : super.fromJson(jsonData: jsonData) {
    exposure = tryCast<int>(jsonData['exposure']) ?? 3000;
    blackLevel = tryCast<int>(jsonData['black_level']) ?? 0;
    gain = tryCast<int>(jsonData['gain']) ?? 0;

    pipeline = tryCast<int>(jsonData['pipeline']) ?? 0;
    cameraUrl = tryCast<String>(jsonData['camera_url']) ?? '';

    // ✅ filters persisted in widget json
    filterBrightness = (tryCast<num>(jsonData['filter_brightness']) ?? 0).toDouble();
    filterContrast = (tryCast<num>(jsonData['filter_contrast']) ?? 1).toDouble();
    filterSaturation = (tryCast<num>(jsonData['filter_saturation']) ?? 1).toDouble();
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'exposure': exposure,
      'black_level': blackLevel,
      'gain': gain,
      'pipeline': pipeline,
      'camera_url': cameraUrl,
      'filter_brightness': filterBrightness,
      'filter_contrast': filterContrast,
      'filter_saturation': filterSaturation,
    };
  }

  @override
  void initializeSubscriptions() {
    txSub = ntConnection.subscribe(txTopic, period);
    tySub = ntConnection.subscribe(tyTopic, period);
    taSub = ntConnection.subscribe(taTopic, period);
    tvSub = ntConnection.subscribe(tvTopic, period);

    pipelineSub = ntConnection.subscribe(pipelineTopic, period);

    exposureSub = ntConnection.subscribe(exposureTopic, period);
    blackLevelSub = ntConnection.subscribe(blackLevelTopic, period);
    gainSub = ntConnection.subscribe(gainTopic, period);
    ledModeSub = ntConnection.subscribe(ledModeTopic, period);
    camModeSub = ntConnection.subscribe(camModeTopic, period);

    // ✅ Filters
    filterBrightnessSub = ntConnection.subscribe(filterBrightnessTopic, period);
    filterContrastSub = ntConnection.subscribe(filterContrastTopic, period);
    filterSaturationSub = ntConnection.subscribe(filterSaturationTopic, period);
  }

  void setPipeline(int value) {
    final v = value.clamp(0, 9);
    pipeline = v;

    ntConnection.updateDataFromTopic(
      ntConnection.getTopicFromName(pipelineControlTopic) ??
          ntConnection.publishNewTopic(pipelineControlTopic, NT4TypeStr.kInt),
      v,
    );
  }

  void setExposure(int value) {
    final v = value.clamp(0, 10000);
    exposure = v;
    ntConnection.updateDataFromTopic(
      ntConnection.getTopicFromName(exposureTopic) ??
          ntConnection.publishNewTopic(exposureTopic, NT4TypeStr.kInt),
      v,
    );
  }

  void setBlackLevel(int value) {
    final v = value.clamp(0, 100);
    blackLevel = v;
    ntConnection.updateDataFromTopic(
      ntConnection.getTopicFromName(blackLevelTopic) ??
          ntConnection.publishNewTopic(blackLevelTopic, NT4TypeStr.kInt),
      v,
    );
  }

  void setGain(int value) {
    final v = value.clamp(0, 100);
    gain = v;
    ntConnection.updateDataFromTopic(
      ntConnection.getTopicFromName(gainTopic) ??
          ntConnection.publishNewTopic(gainTopic, NT4TypeStr.kInt),
      v,
    );
  }

  void setLED(int mode) {
    ledMode = mode;
    ntConnection.updateDataFromTopic(
      ntConnection.getTopicFromName(ledModeTopic) ??
          ntConnection.publishNewTopic(ledModeTopic, NT4TypeStr.kInt),
      mode,
    );
  }

  void setCamMode(int mode) {
    camMode = mode;
    ntConnection.updateDataFromTopic(
      ntConnection.getTopicFromName(camModeTopic) ??
          ntConnection.publishNewTopic(camModeTopic, NT4TypeStr.kInt),
      mode,
    );
  }

  // ✅ Filter setters (NT synced)
  void setFilterBrightness(double v) {
    final vv = _clamp(v, -1.0, 1.0);
    filterBrightness = vv;
    ntConnection.updateDataFromTopic(
      ntConnection.getTopicFromName(filterBrightnessTopic) ??
          ntConnection.publishNewTopic(filterBrightnessTopic, NT4TypeStr.kFloat64),
      vv,
    );
    refresh();
  }

  void setFilterContrast(double v) {
    final vv = _clamp(v, 0.0, 2.0);
    filterContrast = vv;
    ntConnection.updateDataFromTopic(
      ntConnection.getTopicFromName(filterContrastTopic) ??
          ntConnection.publishNewTopic(filterContrastTopic, NT4TypeStr.kFloat64),
      vv,
    );
    refresh();
  }

  void setFilterSaturation(double v) {
    final vv = _clamp(v, 0.0, 2.0);
    filterSaturation = vv;
    ntConnection.updateDataFromTopic(
      ntConnection.getTopicFromName(filterSaturationTopic) ??
          ntConnection.publishNewTopic(filterSaturationTopic, NT4TypeStr.kFloat64),
      vv,
    );
    refresh();
  }

  void resetFilters() {
    setFilterBrightness(0.0);
    setFilterContrast(1.0);
    setFilterSaturation(1.0);
  }

  void setCameraUrl(String url) {
    cameraUrl = url.trim();
    refresh();
  }
}

/// =============================
///          WIDGET
/// =============================
class LimelightWidget extends NTWidget {
  static const String widgetType = 'Limelight';
  const LimelightWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final model = cast<LimelightModel>(context.watch<NTWidgetModel>());

    return ListenableBuilder(
      listenable: Listenable.merge(model.subscriptions),
      builder: (context, _) {
        model.tx = _asDouble(model.txSub.value);
        model.ty = _asDouble(model.tySub.value);
        model.ta = _asDouble(model.taSub.value);
        model.hasTarget = _asBool(model.tvSub.value);

        model.pipeline = _asInt(model.pipelineSub.value);

        final expRB = _asInt(model.exposureSub.value, fallback: model.exposure);
        final blkRB = _asInt(model.blackLevelSub.value, fallback: model.blackLevel);
        final gainRB = _asInt(model.gainSub.value, fallback: model.gain);
        final ledRB = _asInt(model.ledModeSub.value, fallback: model.ledMode);
        final camRB = _asInt(model.camModeSub.value, fallback: model.camMode);

        model.exposure = expRB.clamp(0, 10000);
        model.blackLevel = blkRB.clamp(0, 100);
        model.gain = gainRB.clamp(0, 100);
        model.ledMode = ledRB;
        model.camMode = camRB;

        // ✅ filters readback from NT
        model.filterBrightness = _asDouble(model.filterBrightnessSub.value, fallback: model.filterBrightness);
        model.filterContrast = _asDouble(model.filterContrastSub.value, fallback: model.filterContrast);
        model.filterSaturation = _asDouble(model.filterSaturationSub.value, fallback: model.filterSaturation);

        // clamp
        model.filterBrightness = _clamp(model.filterBrightness, -1.0, 1.0);
        model.filterContrast = _clamp(model.filterContrast, 0.0, 2.0);
        model.filterSaturation = _clamp(model.filterSaturation, 0.0, 2.0);

        return Padding(
          padding: const EdgeInsets.all(10),
          child: SingleChildScrollView(
            child: Column(
              children: [
                _headerCard(model.hasTarget),
                const SizedBox(height: 10),
                _cameraCard(context, model),
                const SizedBox(height: 10),
                _filtersCard(model), // ✅ NEW
                const SizedBox(height: 10),
                _valuesCard(model),
                const SizedBox(height: 10),
                _pipelineCard(model),
                const SizedBox(height: 10),
                _exposureCard(model),
                const SizedBox(height: 10),
                _blackLevelCard(model),
                const SizedBox(height: 10),
                _gainCard(model),
                const SizedBox(height: 10),
                _modesCard(model),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _headerCard(bool hasTarget) {
    final bg = hasTarget ? Colors.green.shade700 : Colors.red.shade700;

    return Card(
      color: bg,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(
              hasTarget ? Icons.track_changes : Icons.search_off,
              color: Colors.white,
              size: 28,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                hasTarget ? 'Target Locked' : 'No Target',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            _pill(
              label: 'TV',
              value: hasTarget ? '1' : '0',
              icon: hasTarget ? Icons.circle : Icons.circle_outlined,
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            '$label: $value',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _cameraCard(BuildContext context, LimelightModel model) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Camera', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  color: Colors.black.withOpacity(0.15),
                  child: _cameraPreview(model),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.link, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    model.cameraUrl.isEmpty ? 'No stream URL set' : model.cameraUrl,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Set camera URL',
                  icon: const Icon(Icons.edit),
                  onPressed: () => _editCameraUrl(context, model),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// ✅ Filtered MJPEG preview
  Widget _cameraPreview(LimelightModel model) {
    final raw = model.cameraUrl.trim();

    if (raw.isEmpty) {
      return _cameraPlaceholder(
        title: 'Camera stream not configured',
        subtitle: 'Click edit and enter: http://10.56.35.70:5800',
        icon: Icons.videocam_off,
      );
    }

    String cleaned = raw.replaceFirst(
      RegExp(r'^\s*(mjpg|mjpeg)\s*:\s*', caseSensitive: false),
      '',
    );

    if (!cleaned.contains('/stream.mjpg') &&
        !cleaned.contains('/stream.mjpeg') &&
        !cleaned.endsWith('/')) {
      cleaned = '$cleaned/stream.mjpg';
    }

    final uri = Uri.tryParse(cleaned);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return _cameraPlaceholder(
        title: 'Invalid URL',
        subtitle: 'Enter a valid URL like: http://10.56.35.70:5800',
        icon: Icons.error_outline,
      );
    }

    final matrix = _colorMatrix(
      brightness: model.filterBrightness,
      contrast: model.filterContrast,
      saturation: model.filterSaturation,
    );

    return ColorFiltered(
      colorFilter: ColorFilter.matrix(matrix),
      child: MJPEGStreamScreen(
        streamUrl: cleaned,
        showLiveIcon: true,
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
      ),
    );
  }

  Widget _cameraPlaceholder({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: Colors.white.withOpacity(0.85)),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editCameraUrl(BuildContext context, LimelightModel model) async {
    final controller = TextEditingController(text: model.cameraUrl);

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Camera Stream URL'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Enter the Limelight stream URL (port 5800):', style: TextStyle(fontSize: 13)),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'http://10.56.35.70:5800',
                  helperText: 'Auto-appends /stream.mjpg if needed',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Save')),
          ],
        );
      },
    );

    if (result != null) model.setCameraUrl(result);
  }

  /// ✅ NEW: Filters card
  Widget _filtersCard(LimelightModel model) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Image Filters (Elastic only)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),

            _doubleSlider(
              title: 'Brightness',
              value: model.filterBrightness,
              min: -1.0,
              max: 1.0,
              divisions: 100,
              label: model.filterBrightness.toStringAsFixed(2),
              onChanged: (v) => model.setFilterBrightness(v),
            ),

            _doubleSlider(
              title: 'Contrast',
              value: model.filterContrast,
              min: 0.0,
              max: 2.0,
              divisions: 100,
              label: model.filterContrast.toStringAsFixed(2),
              onChanged: (v) => model.setFilterContrast(v),
            ),

            _doubleSlider(
              title: 'Saturation',
              value: model.filterSaturation,
              min: 0.0,
              max: 2.0,
              divisions: 100,
              label: model.filterSaturation.toStringAsFixed(2),
              onChanged: (v) => model.setFilterSaturation(v),
            ),

            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: model.resetFilters,
                icon: const Icon(Icons.refresh),
                label: const Text('Reset'),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _doubleSlider({
    required String title,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String label,
    required ValueChanged<double> onChanged,
  }) {
    final v = _clamp(value, min, max);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.w600)),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: v,
                  min: min,
                  max: max,
                  divisions: divisions,
                  label: label,
                  onChanged: onChanged,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 58,
                child: Text(label, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==== your existing cards below (unchanged) ====
  Widget _valuesCard(LimelightModel model) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(child: _metricTile('TX', '${model.tx.toStringAsFixed(2)}°', Icons.swap_horiz)),
            const SizedBox(width: 8),
            Expanded(child: _metricTile('TY', '${model.ty.toStringAsFixed(2)}°', Icons.swap_vert)),
            const SizedBox(width: 8),
            Expanded(child: _metricTile('TA', '${model.ta.toStringAsFixed(2)}%', Icons.center_focus_strong)),
          ],
        ),
      ),
    );
  }

  Widget _metricTile(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: Colors.grey.shade700),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  // ==== keep your existing pipeline/exposure/gain/modes cards as-is ====
  // (I’m not re-pasting them to keep this message readable—your originals work.)
  // If you want, paste your remaining methods and I'll return a single complete file.
  Widget _pipelineCard(LimelightModel model) => const SizedBox.shrink();
  Widget _exposureCard(LimelightModel model) => const SizedBox.shrink();
  Widget _blackLevelCard(LimelightModel model) => const SizedBox.shrink();
  Widget _gainCard(LimelightModel model) => const SizedBox.shrink();
  Widget _modesCard(LimelightModel model) => const SizedBox.shrink();
}
