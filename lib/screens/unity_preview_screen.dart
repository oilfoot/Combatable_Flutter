import 'package:flutter/material.dart';
import 'package:unity_kit/unity_kit.dart';

import '../controllers/sequence_controller.dart';
import '../services/unity_service.dart';

class UnityPreviewScreen extends StatefulWidget {
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
  State<UnityPreviewScreen> createState() => _UnityPreviewScreenState();
}

class _UnityPreviewScreenState extends State<UnityPreviewScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(_preparePreview);
  }

  Future<void> _preparePreview() async {
    await widget.unityService.preparePreview(
      sequenceName: widget.sequenceController.sequenceName,
      animations: widget.sequenceController.getAnimationNamesForUnity(),
    );

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: UnityView(
        bridge: widget.unityService.bridge,
        config: const UnityConfig(
          sceneName: 'MainScene',
          fullscreen: true,
          unloadOnDispose: false,
        ),
        placeholder: const Center(child: CircularProgressIndicator()),
        onReady: (bridge) async {
          widget.unityService.markUnityReady();

          await widget.unityService.sendSequenceWhenReady(
            sequenceName: widget.sequenceController.sequenceName,
            animations: widget.sequenceController.getAnimationNamesForUnity(),
          );

          if (mounted) {
            setState(() {});
          }
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
    );
  }
}
