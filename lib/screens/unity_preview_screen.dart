import 'package:flutter/material.dart';
import 'package:unity_kit/unity_kit.dart';

import '../controllers/sequence_controller.dart';
import '../services/unity_service.dart';

class UnityPreviewScreen extends StatefulWidget {
  const UnityPreviewScreen({
    super.key,
    required this.unityService,
    required this.sequenceController,
  });

  final UnityService unityService;
  final SequenceController sequenceController;

  @override
  State<UnityPreviewScreen> createState() => _UnityPreviewScreenState();
}

class _UnityPreviewScreenState extends State<UnityPreviewScreen> {
  bool _hasSentSequence = false;

  @override
  void initState() {
    super.initState();
    widget.unityService.markUnityNotReady();
  }

  Future<void> _sendSequenceOnce() async {
    if (_hasSentSequence) return;
    _hasSentSequence = true;

    await widget.sequenceController.sendToUnity();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.sequenceController;

    return Scaffold(
      appBar: AppBar(title: Text(controller.sequenceName)),
      body: Stack(
        children: [
          Positioned.fill(
            child: UnityView(
              bridge: widget.unityService.bridge,
              config: const UnityConfig(sceneName: 'MainScene'),
              placeholder: const Center(child: CircularProgressIndicator()),
              onReady: (bridge) async {
                widget.unityService.markUnityReady();
                setState(() {});
                await _sendSequenceOnce();
              },
              onMessage: (message) {
                if (mounted) {
                  setState(() {});
                }
              },
              onSceneLoaded: (scene) {
                if (mounted) {
                  setState(() {});
                }
              },
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.all(12),
                color: Colors.black54,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      controller.isUnityReady
                          ? 'Unity ready'
                          : 'Loading Unity...',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sequence: ${controller.sequenceName}',
                      style: const TextStyle(color: Colors.white),
                    ),
                    Text(
                      'Animations: ${controller.getAnimationNamesForUnity().join(", ")}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
