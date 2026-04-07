import 'dart:async';

import 'package:unity_kit/unity_kit.dart';

class UnityService {
  late final UnityBridge bridge;

  bool _isInitialized = false;
  bool _isUnityReady = false;

  final StreamController<String> _logController =
      StreamController<String>.broadcast();

  StreamSubscription? _messageSub;
  StreamSubscription? _sceneSub;

  Stream<String> get logs => _logController.stream;

  bool get isInitialized => _isInitialized;
  bool get isUnityReady => _isUnityReady;

  Future<void> initialize() async {
    if (_isInitialized) return;

    bridge = UnityBridgeImpl(platform: UnityKitPlatform.instance);
    await bridge.initialize();

    _messageSub = bridge.messageStream.listen((message) {
      _log(
        "Flutter received from Unity => type=${message.type}, data=${message.data}",
      );
    });

    _sceneSub = bridge.sceneStream.listen((scene) {
      _log("Scene loaded => ${scene.name}");
    });

    _isInitialized = true;
    _log("UnityService initialized");
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
    if (!_isInitialized) {
      throw Exception("UnityService is not initialized.");
    }

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

  void _log(String text) {
    if (!_logController.isClosed) {
      _logController.add(text);
    }
  }

  Future<void> dispose() async {
    await _messageSub?.cancel();
    await _sceneSub?.cancel();
    await _logController.close();

    if (_isInitialized) {
      bridge.dispose();
    }

    _isInitialized = false;
    _isUnityReady = false;
  }
}
