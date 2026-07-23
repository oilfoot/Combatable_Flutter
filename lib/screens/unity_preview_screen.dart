import 'dart:async';

import 'package:flutter/material.dart';
import 'package:unity_kit/unity_kit.dart';

import '../controllers/sequence_controller.dart';
import '../models/unity_preview_state.dart';
import '../services/unity_service.dart';
import '../theme/app_theme.dart';
import '../widgets/unity_preview_controls.dart';

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
  StreamSubscription<UnityPreviewState>? _stateSubscription;
  late UnityPreviewState _previewState;

  @override
  void initState() {
    super.initState();
    _previewState = widget.unityService.previewState;
    _stateSubscription = widget.unityService.previewStates.listen((state) {
      if (!mounted) return;
      setState(() => _previewState = state);
    });
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: UnityView(
              bridge: widget.unityService.bridge,
              config: const UnityConfig(
                sceneName: 'MainScene',
                fullscreen: true,
                unloadOnDispose: false,
              ),
              placeholder: const Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              ),
              onReady: (bridge) async {
                widget.unityService.markUnityReady();
              },
              onSceneLoaded: (scene) {
                unawaited(widget.unityService.requestPreviewState());
              },
            ),
          ),
          Positioned.fill(
            child: UnityPreviewControls(
              state: _previewState,
              onTogglePlayback: () {
                unawaited(widget.unityService.togglePreviewPlayback());
              },
              onPreviousStep: () {
                unawaited(widget.unityService.goToPreviousPreviewStep());
              },
              onNextStep: () {
                unawaited(widget.unityService.goToNextPreviewStep());
              },
              onToggleLoop: () {
                unawaited(
                  widget.unityService.setPreviewLoop(
                    !_previewState.loopEnabled,
                  ),
                );
              },
              onSpeedChanged: (speed) {
                unawaited(widget.unityService.setPreviewPlaybackSpeed(speed));
              },
              onResetCamera: () {
                unawaited(widget.unityService.resetPreviewCamera());
              },
              onToggleScope: () {
                unawaited(widget.unityService.togglePreviewTimelineScope());
              },
              onToggleComments: () {
                unawaited(
                  widget.unityService.setPreviewCommentsEnabled(
                    !_previewState.commentsEnabled,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
