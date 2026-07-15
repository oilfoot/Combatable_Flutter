import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

typedef AnimationFlightDestination = Offset Function(Rect sourceRect);
typedef AnimationFlightTargetProvider = Offset? Function();

enum AnimationFlightActionTiming { alongsideFlight, afterFlight }

/// Central tuning values for every card-flight animation.
///
/// Change these values to adjust the feel without touching the animation code.
abstract final class AnimationCardFlightTuning {
  static const Duration duration = Duration(milliseconds: 400);

  /// Use the larger centered flight only when the target is this many
  /// timeline steps below the visible area. Change this to 1, 5, etc.
  static const double sequenceBuilderLongScrollStepThreshold = 3;

  static const Duration sequenceBuilderDuration = Duration(milliseconds: 460);
  static const Duration sequenceBuilderLongScrollDuration = Duration(
    milliseconds: 600,
  );
  static const bool fadeOutAtEnd = true;
  static const double fadeStart = 0.85;
  static const double arcLift = 72;
  static const double sequenceBuilderArcLift = 150;
  static const double sequenceBuilderLongScrollArcLift = 400;
  static const double sequenceBuilderScaleStart = 0;
  static const double sequenceBuilderLongScrollScaleStart = 0.35;
  static const double maxRotation = 0.07;
  static const double minimumUpwardClearance = 12;

  /// Keeps bright and dark preview images readable while they are in flight.
  static const double ghostCornerRadius = 14;
  static const double ghostStrokeWidth = 1;
  static const Color ghostStrokeColor = Color(0x40FFFFFF);
  static const Color ghostShadowColor = Color(0x73000000);
  static const double ghostShadowBlur = 18;
  static const double ghostShadowSpread = 0;

  /// 0 is linear. Values closer to 1 make the start/end faster and the
  /// middle slower. Keep this below 1 so progress always moves forward.
  static const double fastSlowFastStrength = 0.1;

  static const double fullLibraryFinalScale = 0.18;
  static const double collapsedBuilderFinalScale = 0.30;
  static const double expandedBuilderFinalScale = 0.48;

  /// Expanded mode first exits fully, then dives back behind the panel.
  static const double behindExitProgress = 0.68;
  static const double behindExitClearance = 6;
  static const double behindDiveDepth = 48;
}

class AnimationCardFlight {
  const AnimationCardFlight._();

  static Future<void> run({
    required GlobalKey sourceKey,
    required Future<void> Function() action,
    GlobalKey? targetKey,
    GlobalKey? behindPanelKey,
    AnimationFlightDestination? destination,
    double finalScale = 0.22,
    bool useSnapshot = false,
    bool? fadeOut,
    bool preventDownwardFlight = false,
    Duration duration = AnimationCardFlightTuning.duration,
    double arcLift = AnimationCardFlightTuning.arcLift,
    double scaleStart = 0,
    Size? flightSize,
    Widget? flightChild,
    AnimationFlightActionTiming actionTiming =
        AnimationFlightActionTiming.alongsideFlight,
  }) async {
    final sourceContext = sourceKey.currentContext;
    final sourceBox = sourceContext?.findRenderObject();

    if (sourceContext == null || sourceBox is! RenderBox) {
      developer.log(
        'Card flight skipped: source card has no render box.',
        name: 'AnimationCardFlight',
      );
      await action();
      return;
    }

    final overlay = Overlay.of(sourceContext, rootOverlay: true);
    final overlayBox = overlay.context.findRenderObject();

    if (overlayBox is! RenderBox) {
      developer.log(
        'Card flight skipped: root overlay has no render box.',
        name: 'AnimationCardFlight',
      );
      await action();
      return;
    }

    final sourceTopLeft = sourceBox.localToGlobal(Offset.zero);
    final sourceBottomRight = sourceBox.localToGlobal(
      sourceBox.size.bottomRight(Offset.zero),
    );
    var sourceRect = Rect.fromPoints(sourceTopLeft, sourceBottomRight);

    if (flightSize != null) {
      sourceRect = Rect.fromCenter(
        center: sourceRect.center,
        width: flightSize.width,
        height: flightSize.height,
      );
    }
    ui.Image? cardImage;

    if (useSnapshot && sourceBox is RenderRepaintBoundary) {
      try {
        final devicePixelRatio = MediaQuery.devicePixelRatioOf(sourceContext);
        cardImage = await sourceBox.toImage(
          pixelRatio: devicePixelRatio.clamp(1.0, 2.0).toDouble(),
        );
      } catch (error, stackTrace) {
        developer.log(
          'Card snapshot failed; using the visual fallback.',
          name: 'AnimationCardFlight',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    try {
      final targetCenter =
          _targetCenter(targetKey) ??
          destination?.call(sourceRect) ??
          Offset(sourceRect.center.dx, sourceRect.top - 140);

      final localSourceRect = Rect.fromPoints(
        overlayBox.globalToLocal(sourceRect.topLeft),
        overlayBox.globalToLocal(sourceRect.bottomRight),
      );
      final localTargetCenter = overlayBox.globalToLocal(targetCenter);
      final targetCenterProvider = targetKey == null
          ? null
          : () {
              final globalCenter = _targetCenter(targetKey);
              return globalCenter == null
                  ? null
                  : overlayBox.globalToLocal(globalCenter);
            };
      final behindPanelRect = _globalRect(behindPanelKey);
      final localBehindTop = behindPanelRect == null
          ? null
          : overlayBox.globalToLocal(behindPanelRect.topLeft).dy;
      final completer = Completer<void>();
      late final OverlayEntry entry;

      entry = OverlayEntry(
        builder: (_) => _AnimationCardFlightOverlay(
          image: cardImage,
          flightChild: flightChild,
          sourceRect: localSourceRect,
          targetCenter: localTargetCenter,
          targetCenterProvider: targetCenterProvider,
          finalScale: finalScale,
          behindTop: localBehindTop,
          fadeOut: fadeOut ?? AnimationCardFlightTuning.fadeOutAtEnd,
          preventDownwardFlight: preventDownwardFlight,
          duration: duration,
          arcLift: arcLift,
          scaleStart: scaleStart,
          onCompleted: () {
            entry.remove();
            cardImage?.dispose();
            cardImage = null;
            if (!completer.isCompleted) completer.complete();
          },
        ),
      );

      overlay.insert(entry);

      if (actionTiming == AnimationFlightActionTiming.afterFlight) {
        await completer.future;
        await action();
      } else {
        await Future.wait<void>([completer.future, action()]);
      }
    } catch (_) {
      cardImage?.dispose();
      rethrow;
    }
  }

  static Offset? _targetCenter(GlobalKey? targetKey) {
    return _globalRect(targetKey)?.center;
  }

  static Rect? _globalRect(GlobalKey? key) {
    final targetBox = key?.currentContext?.findRenderObject();
    if (targetBox is! RenderBox) return null;

    final topLeft = targetBox.localToGlobal(Offset.zero);
    return topLeft & targetBox.size;
  }
}

class _AnimationCardFlightOverlay extends StatefulWidget {
  const _AnimationCardFlightOverlay({
    required this.image,
    required this.flightChild,
    required this.sourceRect,
    required this.targetCenter,
    required this.targetCenterProvider,
    required this.finalScale,
    required this.behindTop,
    required this.fadeOut,
    required this.preventDownwardFlight,
    required this.duration,
    required this.arcLift,
    required this.scaleStart,
    required this.onCompleted,
  });

  final ui.Image? image;
  final Widget? flightChild;
  final Rect sourceRect;
  final Offset targetCenter;
  final AnimationFlightTargetProvider? targetCenterProvider;
  final double finalScale;
  final double? behindTop;
  final bool fadeOut;
  final bool preventDownwardFlight;
  final Duration duration;
  final double arcLift;
  final double scaleStart;
  final VoidCallback onCompleted;

  @override
  State<_AnimationCardFlightOverlay> createState() =>
      _AnimationCardFlightOverlayState();
}

class _AnimationCardFlightOverlayState
    extends State<_AnimationCardFlightOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _progress = CurvedAnimation(
      parent: _controller,
      curve: const _FastSlowFastCurve(
        AnimationCardFlightTuning.fastSlowFastStrength,
      ),
    );
    unawaited(_controller.forward().whenComplete(widget.onCompleted));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _progress,
          builder: (context, _) {
            final t = _progress.value;
            final scale = _scaleAt(t);
            final center = widget.behindTop == null
                ? _standardCenter(t)
                : _behindPanelCenter(t);
            final fadeStart = AnimationCardFlightTuning.fadeStart;
            final fadeProgress = ((t - fadeStart) / (1 - fadeStart)).clamp(
              0.0,
              1.0,
            );
            final opacity = widget.fadeOut ? 1 - fadeProgress : 1.0;
            final rotation =
                -AnimationCardFlightTuning.maxRotation * math.sin(math.pi * t);

            Widget flight = Stack(
              children: [
                Positioned(
                  left: center.dx - widget.sourceRect.width / 2,
                  top: center.dy - widget.sourceRect.height / 2,
                  width: widget.sourceRect.width,
                  height: widget.sourceRect.height,
                  child: Opacity(
                    opacity: opacity,
                    child: Transform.scale(
                      scale: scale,
                      child: Transform.rotate(
                        angle: rotation,
                        child: _FlightGhostFrame(
                          child: widget.image == null
                              ? widget.flightChild ??
                                    const _FallbackFlightCard()
                              : RawImage(
                                  image: widget.image,
                                  fit: BoxFit.fill,
                                  filterQuality: FilterQuality.high,
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );

            if (widget.behindTop != null &&
                t >= AnimationCardFlightTuning.behindExitProgress) {
              flight = ClipRect(
                clipper: _FlightBehindPanelClipper(widget.behindTop!),
                child: flight,
              );
            }

            return flight;
          },
        ),
      ),
    );
  }

  Offset _standardCenter(double t) {
    final start = widget.sourceRect.center;
    final liveEnd = widget.targetCenterProvider?.call() ?? widget.targetCenter;
    final end = widget.preventDownwardFlight
        ? Offset(
            liveEnd.dx,
            math.min(
              liveEnd.dy,
              widget.sourceRect.top -
                  AnimationCardFlightTuning.minimumUpwardClearance,
            ),
          )
        : liveEnd;
    return _quadraticBezier(start, _controlPoint(start, end), end, t);
  }

  Offset _behindPanelCenter(double t) {
    final targetCenter =
        widget.targetCenterProvider?.call() ?? widget.targetCenter;
    final exitProgress = AnimationCardFlightTuning.behindExitProgress;
    final exitScale = _scaleAt(exitProgress);
    final exitCenter = Offset(
      targetCenter.dx,
      widget.behindTop! -
          widget.sourceRect.height * exitScale / 2 -
          AnimationCardFlightTuning.behindExitClearance,
    );

    if (t <= exitProgress) {
      final exitT = Curves.easeOutCubic.transform(t / exitProgress);
      final start = widget.sourceRect.center;
      return _quadraticBezier(
        start,
        _controlPoint(start, exitCenter),
        exitCenter,
        exitT,
      );
    }

    final diveT = Curves.easeInCubic.transform(
      (t - exitProgress) / (1 - exitProgress),
    );
    return Offset.lerp(exitCenter, targetCenter, diveT) ?? exitCenter;
  }

  double _scaleAt(double t) {
    final scaleProgress = ((t - widget.scaleStart) / (1 - widget.scaleStart))
        .clamp(0.0, 1.0);
    return ui.lerpDouble(1, widget.finalScale, scaleProgress) ?? 1;
  }

  Offset _controlPoint(Offset start, Offset end) {
    return Offset(
      (start.dx + end.dx) / 2,
      math.min(start.dy, end.dy) - widget.arcLift,
    );
  }

  Offset _quadraticBezier(Offset start, Offset control, Offset end, double t) {
    final inverse = 1 - t;
    return Offset(
      inverse * inverse * start.dx +
          2 * inverse * t * control.dx +
          t * t * end.dx,
      inverse * inverse * start.dy +
          2 * inverse * t * control.dy +
          t * t * end.dy,
    );
  }
}

class _FlightGhostFrame extends StatelessWidget {
  const _FlightGhostFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    const radius = AnimationCardFlightTuning.ghostCornerRadius;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const [
          BoxShadow(
            color: AnimationCardFlightTuning.ghostShadowColor,
            blurRadius: AnimationCardFlightTuning.ghostShadowBlur,
            spreadRadius: AnimationCardFlightTuning.ghostShadowSpread,
          ),
        ],
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: AnimationCardFlightTuning.ghostStrokeColor,
          width: AnimationCardFlightTuning.ghostStrokeWidth,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          radius - AnimationCardFlightTuning.ghostStrokeWidth,
        ),
        child: child,
      ),
    );
  }
}

class _FastSlowFastCurve extends Curve {
  const _FastSlowFastCurve(this.strength);

  final double strength;

  @override
  double transformInternal(double t) {
    return t + strength / (2 * math.pi) * math.sin(2 * math.pi * t);
  }
}

class _FlightBehindPanelClipper extends CustomClipper<Rect> {
  const _FlightBehindPanelClipper(this.panelTop);

  final double panelTop;

  @override
  Rect getClip(Size size) => Rect.fromLTRB(0, 0, size.width, panelTop);

  @override
  bool shouldReclip(covariant _FlightBehindPanelClipper oldClipper) {
    return oldClipper.panelTop != panelTop;
  }
}

class _FallbackFlightCard extends StatelessWidget {
  const _FallbackFlightCard();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFC8A7FF).withValues(alpha: 0.72),
          width: 2,
        ),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF302447), Color(0xFF151219)],
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 18, spreadRadius: 2),
        ],
      ),
      child: const Center(
        child: Icon(
          Icons.play_arrow_rounded,
          color: Color(0xFFC8A7FF),
          size: 38,
        ),
      ),
    );
  }
}
