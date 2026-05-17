import 'dart:async';

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
  StreamSubscription<double>? _timelineSub;

  double _timelineValue = 0.0;
  bool _isScrubbing = false;

  @override
  void initState() {
    super.initState();

    _timelineSub = widget.unityService.timelineValues.listen((value) {
      if (!mounted || _isScrubbing) return;

      setState(() {
        _timelineValue = value.clamp(0.0, 1.0);
      });
    });

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

  Future<void> _beginTimelineScrub(double value) async {
    setState(() {
      _isScrubbing = true;
      _timelineValue = value.clamp(0.0, 1.0);
    });

    await widget.unityService.beginTimelineScrub();
    await widget.unityService.setTimelineValue(value);
  }

  Future<void> _updateTimelineScrub(double value) async {
    setState(() {
      _timelineValue = value.clamp(0.0, 1.0);
    });

    await widget.unityService.setTimelineValue(value);
  }

  Future<void> _endTimelineScrub(double value) async {
    setState(() {
      _isScrubbing = false;
      _timelineValue = value.clamp(0.0, 1.0);
    });

    await widget.unityService.setTimelineValue(value);
    await widget.unityService.endTimelineScrub();
  }

  @override
  void dispose() {
    _timelineSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sliderValue = _timelineValue.clamp(0.0, 1.0).toDouble();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          UnityView(
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
                animations: widget.sequenceController
                    .getAnimationNamesForUnity(),
              );

              if (mounted) {
                setState(() {});
              }
            },
            onMessage: (message) {
              widget.unityService.handleUnityMessage(message);

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

          Positioned(
            left: 20,
            right: 20,
            bottom: 105,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                ),
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 8,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 18,
                    ),
                  ),
                  child: Slider(
                    value: sliderValue,
                    min: 0.0,
                    max: 1.0,
                    onChangeStart: _beginTimelineScrub,
                    onChanged: _updateTimelineScrub,
                    onChangeEnd: _endTimelineScrub,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
