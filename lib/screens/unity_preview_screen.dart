import 'package:flutter/material.dart';
import 'package:unity_kit/unity_kit.dart';

import '../controllers/sequence_controller.dart';
import '../services/unity_service.dart';

class UnityPreviewScreen extends StatelessWidget {
  const UnityPreviewScreen({
    super.key,
    required this.unityService,
    required this.sequenceController,
    this.embeddedInTab = false,
  });

  final UnityService unityService;
  final SequenceController sequenceController;
  final bool embeddedInTab;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: UnityView(
        bridge: unityService.bridge,
        config: const UnityConfig(
          sceneName: 'MainScene',
          fullscreen: true,
          unloadOnDispose: false,
        ),
        placeholder: const Center(child: CircularProgressIndicator()),
        onReady: (bridge) async {
          unityService.markUnityReady();
        },
        onSceneLoaded: (scene) {},
      ),
    );
  }
}
