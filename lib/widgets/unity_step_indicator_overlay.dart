import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/unity_step_indicator_state.dart';
import '../theme/app_theme.dart';

/// Paints timeline annotations over Unity's native slider.
///
/// Unity always sends positions in the coordinate system of the complete
/// sequence. Focusing a move only changes [viewportStart]/[viewportEnd].
/// Animating that viewport keeps every marker attached to its real position
/// and turns scope changes into one continuous camera-like zoom.
class UnityStepIndicatorOverlay extends StatefulWidget {
  const UnityStepIndicatorOverlay({super.key, required this.state});

  final UnityStepIndicatorState state;

  @override
  State<UnityStepIndicatorOverlay> createState() =>
      _UnityStepIndicatorOverlayState();
}

class _UnityStepIndicatorOverlayState extends State<UnityStepIndicatorOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final Map<String, _AnimatedMarker> _markers = {};
  final Map<String, _AnimatedRange> _ranges = {};
  Set<String> _targetMarkerKeys = {};
  Set<String> _targetRangeKeys = {};

  double _viewportFromStart = 0;
  double _viewportToStart = 0;
  double _viewportFromEnd = 1;
  double _viewportToEnd = 1;
  double _currentViewportStart = 0;
  double _currentViewportEnd = 1;
  String _contentKey = '';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this)
      ..addListener(() => setState(() {}))
      ..addStatusListener((status) {
        if (status != AnimationStatus.completed) return;
        _markers.removeWhere((key, _) => !_targetMarkerKeys.contains(key));
        _ranges.removeWhere((key, _) => !_targetRangeKeys.contains(key));
      });
    _applyState(widget.state, animate: widget.state.ready);
  }

  @override
  void didUpdateWidget(covariant UnityStepIndicatorOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.state, widget.state)) {
      _applyState(widget.state, animate: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _applyState(UnityStepIndicatorState state, {required bool animate}) {
    _captureCurrentValues();
    final isContentChange =
        animate && state.ready && state.contentKey != _contentKey;
    _contentKey = state.contentKey;

    _viewportFromStart = _currentViewportStart;
    _viewportFromEnd = _currentViewportEnd;
    _viewportToStart = state.viewportStart;
    _viewportToEnd = math.max(state.viewportStart + 0.0001, state.viewportEnd);

    _targetMarkerKeys = {
      for (final marker in state.markers)
        if (marker.key.isNotEmpty) marker.key,
    };
    _targetRangeKeys = {
      for (final range in state.ranges)
        if (range.key.isNotEmpty) range.key,
    };

    for (final marker in state.markers) {
      if (marker.key.isEmpty) continue;
      final existing = _markers[marker.key];
      if (existing == null) {
        _markers[marker.key] = _AnimatedMarker(
          fromPosition: marker.position,
          toPosition: marker.position,
          fromAlpha: animate ? 0 : 1,
          toAlpha: 1,
          fromScale: animate ? 0.35 : 1,
          toScale: 1,
          delay: isContentChange ? marker.position * 0.42 : 0,
        );
      } else {
        existing
          ..fromPosition = existing.currentPosition
          ..toPosition = marker.position
          ..fromAlpha = isContentChange ? 0 : existing.currentAlpha
          ..toAlpha = 1
          ..fromScale = isContentChange ? 0.35 : existing.currentScale
          ..toScale = 1
          ..delay = isContentChange ? marker.position * 0.42 : 0;
      }
    }

    for (final entry in _markers.entries) {
      if (_targetMarkerKeys.contains(entry.key)) continue;
      entry.value
        ..fromPosition = entry.value.currentPosition
        ..toPosition = entry.value.currentPosition
        ..fromAlpha = entry.value.currentAlpha
        ..toAlpha = 0
        ..fromScale = entry.value.currentScale
        ..toScale = 0.65
        ..delay = 0;
    }

    for (final range in state.ranges) {
      if (range.key.isEmpty) continue;
      final existing = _ranges[range.key];
      if (existing == null) {
        _ranges[range.key] = _AnimatedRange(
          fromStart: range.start,
          toStart: range.start,
          fromEnd: isContentChange ? range.start : range.end,
          toEnd: range.end,
          fromAlpha: animate ? 0 : 1,
          toAlpha: 1,
          delay: isContentChange ? range.start * 0.34 : 0,
        );
      } else {
        existing
          ..fromStart = isContentChange ? range.start : existing.currentStart
          ..toStart = range.start
          ..fromEnd = isContentChange ? range.start : existing.currentEnd
          ..toEnd = range.end
          ..fromAlpha = isContentChange ? 0 : existing.currentAlpha
          ..toAlpha = 1
          ..delay = isContentChange ? range.start * 0.34 : 0;
      }
    }

    for (final entry in _ranges.entries) {
      if (_targetRangeKeys.contains(entry.key)) continue;
      entry.value
        ..fromStart = entry.value.currentStart
        ..toStart = entry.value.currentStart
        ..fromEnd = entry.value.currentEnd
        ..toEnd = entry.value.currentEnd
        ..fromAlpha = entry.value.currentAlpha
        ..toAlpha = 0
        ..delay = 0;
    }

    if (!animate) {
      _setProgress(1);
      return;
    }

    final milliseconds = isContentChange
        ? 720
        : (state.transitionDuration * 1000).round();
    _controller
      ..duration = Duration(milliseconds: milliseconds)
      ..forward(from: 0);
  }

  void _captureCurrentValues() => _setProgress(_animationProgress);

  void _setProgress(double progress) {
    _currentViewportStart = lerpDouble(
      _viewportFromStart,
      _viewportToStart,
      progress,
    )!;
    _currentViewportEnd = lerpDouble(
      _viewportFromEnd,
      _viewportToEnd,
      progress,
    )!;
    for (final marker in _markers.values) {
      marker.setProgress(progress);
    }
    for (final range in _ranges.values) {
      range.setProgress(progress);
    }
  }

  double get _animationProgress {
    if (!_controller.isAnimating) return 1;
    return Curves.easeInOutCubic.transform(_controller.value);
  }

  @override
  Widget build(BuildContext context) {
    _setProgress(_animationProgress);

    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _StepIndicatorPainter(
            markers: List.unmodifiable(_markers.values),
            ranges: List.unmodifiable(_ranges.entries),
            viewportStart: _currentViewportStart,
            viewportEnd: _currentViewportEnd,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _AnimatedMarker {
  _AnimatedMarker({
    required this.fromPosition,
    required this.toPosition,
    required this.fromAlpha,
    required this.toAlpha,
    required this.fromScale,
    required this.toScale,
    required this.delay,
  }) : currentPosition = fromPosition,
       currentAlpha = fromAlpha,
       currentScale = fromScale;

  double fromPosition;
  double toPosition;
  double fromAlpha;
  double toAlpha;
  double fromScale;
  double toScale;
  double delay;
  double currentPosition;
  double currentAlpha;
  double currentScale;

  void setProgress(double progress) {
    final localProgress = _staggeredProgress(progress, delay);
    currentPosition = lerpDouble(fromPosition, toPosition, localProgress)!;
    currentAlpha = lerpDouble(fromAlpha, toAlpha, localProgress)!;
    currentScale = lerpDouble(
      fromScale,
      toScale,
      Curves.easeOutBack.transform(localProgress),
    )!;
  }
}

class _AnimatedRange {
  _AnimatedRange({
    required this.fromStart,
    required this.toStart,
    required this.fromEnd,
    required this.toEnd,
    required this.fromAlpha,
    required this.toAlpha,
    required this.delay,
  }) : currentStart = fromStart,
       currentEnd = fromEnd,
       currentAlpha = fromAlpha;

  double fromStart;
  double toStart;
  double fromEnd;
  double toEnd;
  double fromAlpha;
  double toAlpha;
  double delay;
  double currentStart;
  double currentEnd;
  double currentAlpha;

  void setProgress(double progress) {
    final localProgress = _staggeredProgress(progress, delay);
    currentStart = lerpDouble(fromStart, toStart, localProgress)!;
    currentEnd = lerpDouble(fromEnd, toEnd, localProgress)!;
    currentAlpha = lerpDouble(fromAlpha, toAlpha, localProgress)!;
  }
}

double _staggeredProgress(double progress, double delay) {
  if (delay <= 0) return progress;
  return ((progress - delay) / math.max(0.0001, 1 - delay)).clamp(0, 1);
}

class _StepIndicatorPainter extends CustomPainter {
  const _StepIndicatorPainter({
    required this.markers,
    required this.ranges,
    required this.viewportStart,
    required this.viewportEnd,
  });

  final List<_AnimatedMarker> markers;
  final List<MapEntry<String, _AnimatedRange>> ranges;
  final double viewportStart;
  final double viewportEnd;

  double _mapPosition(double position) {
    final span = math.max(0.0001, viewportEnd - viewportStart);
    return (position - viewportStart) / span;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    canvas.save();
    canvas.clipRect(Offset.zero & size);

    // Keep the annotations clear of the rounded ends of Unity's native track.
    final horizontalInset = math.min(6.0, size.width * 0.02);
    final usableWidth = math.max(1.0, size.width - horizontalInset * 2);
    double xFor(double position) =>
        horizontalInset + _mapPosition(position) * usableWidth;

    final rangeY = math.max(1.5, size.height - 2);
    for (final entry in ranges) {
      final range = entry.value;
      if (range.currentAlpha <= 0.001) continue;

      var start = xFor(range.currentStart);
      var end = xFor(range.currentEnd);
      if (end < 0 || start > size.width || end <= start) continue;
      start = math.max(horizontalInset, start + 4);
      end = math.min(size.width - horizontalInset, end - 4);
      if (end <= start) continue;

      final alpha = range.currentAlpha;
      canvas.drawLine(
        Offset(start, rangeY),
        Offset(end, rangeY),
        Paint()
          ..color = AppColors.previewSequenceRange.withValues(
            alpha: alpha * 0.18,
          )
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
      canvas.drawLine(
        Offset(start, rangeY),
        Offset(end, rangeY),
        Paint()
          ..color = AppColors.previewSequenceRange.withValues(
            alpha: alpha * 0.82,
          )
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );
    }

    final markerHeight = math.min(8.0, math.max(5.0, size.height * 0.56));
    for (final marker in markers) {
      if (marker.currentAlpha <= 0.001) continue;
      final x = xFor(marker.currentPosition);
      if (x < -5 || x > size.width + 5) continue;

      final markerRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x, markerHeight * 0.5),
          width: 3.2 * marker.currentScale,
          height: markerHeight * marker.currentScale,
        ),
        const Radius.circular(2),
      );
      canvas.drawRRect(
        markerRect,
        Paint()
          ..color = AppColors.previewStepMarker.withValues(
            alpha: marker.currentAlpha * 0.22,
          )
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.2),
      );
      canvas.drawRRect(
        markerRect,
        Paint()
          ..color = AppColors.previewStepMarker.withValues(
            alpha: marker.currentAlpha,
          ),
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _StepIndicatorPainter oldDelegate) => true;
}
