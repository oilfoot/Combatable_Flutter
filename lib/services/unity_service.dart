import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:unity_kit/unity_kit.dart';

class UnityService {
  late final UnityBridge bridge;

  bool _isInitialized = false;
  bool _isUnityReady = false;

  final StreamController<String> _logController =
      StreamController<String>.broadcast();

  final StreamController<double> _timelineController =
      StreamController<double>.broadcast();

  StreamSubscription? _messageSub;
  StreamSubscription? _sceneSub;

  Stream<String> get logs => _logController.stream;
  Stream<double> get timelineValues => _timelineController.stream;

  bool get isInitialized => _isInitialized;
  bool get isUnityReady => _isUnityReady;

  Future<void> initialize() async {
    if (_isInitialized) return;

    bridge = UnityBridgeImpl(platform: UnityKitPlatform.instance);
    await bridge.initialize();

    _messageSub = bridge.messageStream.listen(handleUnityMessage);

    _sceneSub = bridge.sceneStream.listen((scene) {
      _log("Scene loaded => ${scene.name}");
    });

    _isInitialized = true;
    _log("UnityService initialized");
  }

  void handleUnityMessage(UnityMessage message) {
    developer.log(
      "🔥 UNITY MESSAGE IN FLUTTER: type=${message.type}, data=${message.data}",
      name: "UnityService",
    );

    _log(
      "🔥 UNITY MESSAGE IN FLUTTER: type=${message.type}, data=${message.data}",
    );

    if (message.type == 'timeline_position') {
      final value = _extractTimelineValue(message.data);

      developer.log("🔥 PARSED TIMELINE VALUE: $value", name: "UnityService");

      _log("🔥 PARSED TIMELINE VALUE: $value");

      if (value != null && !_timelineController.isClosed) {
        _timelineController.add(value);
      }
    }
  }

  double? _extractTimelineValue(dynamic data) {
    try {
      if (data is Map) {
        final value = data['value'];
        if (value is num) return value.toDouble().clamp(0.0, 1.0);
      }

      if (data is String) {
        final decoded = jsonDecode(data);

        if (decoded is Map) {
          final value = decoded['value'];
          if (value is num) return value.toDouble().clamp(0.0, 1.0);
        }
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  void markUnityReady() {
    _isUnityReady = true;
    _log("Unity marked as ready");
  }

  void markUnityNotReady() {
    _isUnityReady = false;
    _log("Unity marked as not ready");
  }

  Future<void> sendSequence({
    required String sequenceName,
    required List<String> animations,
  }) async {
    if (!_isInitialized) throw Exception("UnityService is not initialized.");

    final msg = UnityMessage.to(
      'FlutterSequenceReceiver',
      'SetSequence',
      <String, dynamic>{'sequenceName': sequenceName, 'animations': animations},
    );

    await bridge.send(msg);

    _log(
      "Sent sequence '$sequenceName' with ${animations.length} animation(s) to Unity.",
    );
  }

  Future<void> sendSequenceWhenReady({
    required String sequenceName,
    required List<String> animations,
  }) async {
    if (!_isInitialized) throw Exception("UnityService is not initialized.");

    final msg = UnityMessage.to(
      'FlutterSequenceReceiver',
      'SetSequence',
      <String, dynamic>{'sequenceName': sequenceName, 'animations': animations},
    );

    await bridge.sendWhenReady(msg);

    _log(
      "Queued sequence '$sequenceName' with ${animations.length} animation(s) for Unity.",
    );
  }

  Future<void> loadLocalAddressablesCatalog({
    required String catalogPath,
  }) async {
    if (!_isInitialized) throw Exception("UnityService is not initialized.");

    final msg = UnityMessage.to(
      'LocalAddressablesReceiver',
      'LoadLocalCatalog',
      <String, dynamic>{'catalogPath': catalogPath},
    );

    await bridge.sendWhenReady(msg);

    _log("Sent local catalog path to Unity: $catalogPath");
  }

  Future<void> registerDownloadedJson({required String jsonPath}) async {
    if (!_isInitialized) throw Exception("UnityService is not initialized.");

    final msg = UnityMessage.to(
      'DownloadedJsonReceiver',
      'RegisterDownloadedJson',
      <String, dynamic>{'jsonPath': jsonPath},
    );

    await bridge.sendWhenReady(msg);

    _log("Sent downloaded JSON path to Unity: $jsonPath");
  }

  Future<void> registerDownloadedJsonFiles({
    required List<String> jsonPaths,
  }) async {
    if (!_isInitialized) throw Exception("UnityService is not initialized.");

    for (final jsonPath in jsonPaths) {
      if (jsonPath.trim().isEmpty) continue;
      await registerDownloadedJson(jsonPath: jsonPath);
    }
  }

  Future<void> beginTimelineScrub() async {
    if (!_isInitialized) throw Exception("UnityService is not initialized.");

    final msg = UnityMessage.to(
      'FlutterUIBridge',
      'BeginTimelineScrub',
      <String, dynamic>{},
    );

    await bridge.sendWhenReady(msg);
    _log("Sent BeginTimelineScrub to Unity.");
  }

  Future<void> setTimelineValue(double value) async {
    if (!_isInitialized) throw Exception("UnityService is not initialized.");

    final clampedValue = value.clamp(0.0, 1.0);

    final msg = UnityMessage.to(
      'FlutterUIBridge',
      'SetTimelineValue',
      <String, dynamic>{'value': clampedValue},
    );

    await bridge.sendWhenReady(msg);
  }

  Future<void> endTimelineScrub() async {
    if (!_isInitialized) throw Exception("UnityService is not initialized.");

    final msg = UnityMessage.to(
      'FlutterUIBridge',
      'EndTimelineScrub',
      <String, dynamic>{},
    );

    await bridge.sendWhenReady(msg);
    _log("Sent EndTimelineScrub to Unity.");
  }

  Future<void> loadCurrentSequenceClips() async {
    if (!_isInitialized) throw Exception("UnityService is not initialized.");

    final msg = UnityMessage.to(
      'AddressableClipLoaderReceiver',
      'LoadCurrentSequenceClips',
      <String, dynamic>{},
    );

    await bridge.sendWhenReady(msg);

    _log("Sent LoadCurrentSequenceClips trigger to Unity.");
  }

  Future<void> resumeUnity() async {
    if (!_isInitialized) return;

    try {
      await bridge.resume();
      _isUnityReady = true;
      _log("Unity resumed");
    } catch (e) {
      _log("Unity resume skipped: $e");
    }
  }

  Future<void> pauseUnity() async {
    if (!_isInitialized) return;

    try {
      await bridge.pause();
      _isUnityReady = false;
      _log("Unity paused");
    } catch (e) {
      _log("Unity pause skipped: $e");
    }
  }

  Future<void> preparePreview({
    required String sequenceName,
    required List<String> animations,
  }) async {
    await resumeUnity();

    await sendSequenceWhenReady(
      sequenceName: sequenceName,
      animations: animations,
    );

    await loadCurrentSequenceClips();
  }

  void _log(String text) {
    if (!_logController.isClosed) {
      _logController.add(text);
    }
  }

  Future<void> dispose() async {
    await _messageSub?.cancel();
    await _sceneSub?.cancel();
    await _timelineController.close();
    await _logController.close();

    if (_isInitialized) {
      bridge.dispose();
    }

    _isInitialized = false;
    _isUnityReady = false;
  }
}
