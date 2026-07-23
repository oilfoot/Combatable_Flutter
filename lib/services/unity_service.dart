import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:unity_kit/unity_kit.dart';

class UnityService {
  late final UnityBridge bridge;

  bool _isInitialized = false;
  bool _isUnityReady = false;

  String? _lastSequenceName;
  List<String> _lastAnimations = const [];

  final StreamController<String> _logController =
      StreamController<String>.broadcast();

  final StreamController<String> _testWordController =
      StreamController<String>.broadcast();

  StreamSubscription? _messageSub;
  StreamSubscription? _sceneSub;

  Stream<String> get logs => _logController.stream;
  Stream<String> get testWords => _testWordController.stream;

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
    if (message.type == 'timeline_position') {
      // Compatibility guard for older Unity exports that still report the
      // timeline. Ignore these packets so they cannot trigger global logging
      // or unrelated Flutter rebuilds.
      return;
    }

    developer.log(
      "UNITY MESSAGE IN FLUTTER: type=${message.type}, data=${message.data}",
      name: "UnityService",
    );

    _log(
      "UNITY MESSAGE IN FLUTTER: type=${message.type}, data=${message.data}",
    );

    if (message.type == 'unity_test_word') {
      final word = _extractTestWord(message.data);

      developer.log("🧪 UNITY TEST WORD: $word", name: "UnityService");
      _log("🧪 UNITY TEST WORD: $word");

      if (word != null && !_testWordController.isClosed) {
        _testWordController.add(word);
      }
    }
  }

  String? _extractTestWord(dynamic data) {
    try {
      if (data is Map) {
        final word = data['word'];
        if (word is String) return word;
      }

      if (data is String) {
        final decoded = jsonDecode(data);

        if (decoded is Map) {
          final word = decoded['word'];
          if (word is String) return word;
        }
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  Future<void> requestTestWord() async {
    if (!_isInitialized) throw Exception("UnityService is not initialized.");

    final msg = UnityMessage.to(
      'UnityToFlutterTestBridge',
      'RequestTestWord',
      <String, dynamic>{},
    );

    await bridge.sendWhenReady(msg);
    _log("Requested test word from Unity.");
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
    final isSameSequence =
        _lastSequenceName == sequenceName &&
        _lastAnimations.length == animations.length &&
        _lastAnimations.join('|') == animations.join('|');

    await resumeUnity();

    if (isSameSequence) {
      _log('Preview already loaded. Skipping Unity reload.');
      return;
    }

    _lastSequenceName = sequenceName;
    _lastAnimations = List<String>.from(animations);

    await Future<void>.delayed(const Duration(milliseconds: 150));

    await sendSequenceWhenReady(
      sequenceName: sequenceName,
      animations: animations,
    );

    await Future<void>.delayed(const Duration(milliseconds: 350));

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

    await _testWordController.close();
    await _logController.close();

    if (_isInitialized) {
      bridge.dispose();
    }

    _lastSequenceName = null;
    _lastAnimations = const [];

    _isInitialized = false;
    _isUnityReady = false;
  }
}
