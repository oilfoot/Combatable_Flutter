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
  StreamSubscription<String>? _testWordSub;

  final ValueNotifier<double> _timelineValue = ValueNotifier<double>(0.0);
  bool _isScrubbing = false;

  String _unityTestWord = "No word received yet";

  @override
  void initState() {
    super.initState();

    _timelineSub = widget.unityService.timelineValues.listen((value) {
      if (!mounted || _isScrubbing) return;

      _timelineValue.value = value.clamp(0.0, 1.0);
    });

    _testWordSub = widget.unityService.testWords.listen((word) {
      if (!mounted) return;

      setState(() {
        _unityTestWord = word;
      });
    });
  }

  Future<void> _beginTimelineScrub(double value) async {
    _isScrubbing = true;
    _timelineValue.value = value.clamp(0.0, 1.0);

    await widget.unityService.beginTimelineScrub();
    await widget.unityService.setTimelineValue(value);
  }

  Future<void> _updateTimelineScrub(double value) async {
    _timelineValue.value = value.clamp(0.0, 1.0);

    await widget.unityService.setTimelineValue(value);
  }

  Future<void> _endTimelineScrub(double value) async {
    _isScrubbing = false;
    _timelineValue.value = value.clamp(0.0, 1.0);

    await widget.unityService.setTimelineValue(value);
    await widget.unityService.endTimelineScrub();
  }

  @override
  void dispose() {
    _timelineSub?.cancel();
    _testWordSub?.cancel();
    _timelineValue.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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

              await widget.unityService.requestTestWord();
            },
            onSceneLoaded: (scene) {},
          ),

          Positioned(
            left: 20,
            right: 20,
            bottom: 180,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                ),
                child: Text(
                  _unityTestWord,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
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
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
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
                  child: ValueListenableBuilder<double>(
                    valueListenable: _timelineValue,
                    builder: (context, sliderValue, child) => Slider(
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
          ),
        ],
      ),
    );
  }
}
