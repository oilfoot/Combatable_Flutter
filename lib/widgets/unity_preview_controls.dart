import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/unity_preview_state.dart';
import '../theme/app_theme.dart';

const _previewControlBorder = BorderSide(color: AppColors.borderStrong);

class UnityPreviewControls extends StatelessWidget {
  const UnityPreviewControls({
    super.key,
    required this.state,
    required this.onTogglePlayback,
    required this.onPreviousStep,
    required this.onNextStep,
    required this.onToggleLoop,
    required this.onSpeedChanged,
    required this.onResetCamera,
    required this.onToggleScope,
    required this.onToggleComments,
  });

  final UnityPreviewState state;
  final VoidCallback onTogglePlayback;
  final VoidCallback onPreviousStep;
  final VoidCallback onNextStep;
  final VoidCallback onToggleLoop;
  final ValueChanged<double> onSpeedChanged;
  final VoidCallback onResetCamera;
  final VoidCallback onToggleScope;
  final VoidCallback onToggleComments;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final screenHeight = screenSize.height;
    const actionHeight = 72.0;
    const actionGap = 24.0;
    final hasTimelineRect =
        state.timelineRectValid &&
        state.timelineWidth > 0 &&
        state.timelineHeight > 0;
    final timelineLeft = hasTimelineRect
        ? state.timelineLeft * screenSize.width
        : AppSpacing.xl;
    final timelineRight = hasTimelineRect
        ? (1 - state.timelineLeft - state.timelineWidth) * screenSize.width
        : AppSpacing.xl;
    final timelineBottom = hasTimelineRect
        ? state.timelineBottom * screenHeight
        : 190.0;
    final timelineTop = hasTimelineRect
        ? (state.timelineBottom + state.timelineHeight) * screenHeight
        : screenHeight * 0.235 + 24;
    final actionBottom = (timelineBottom - actionGap - actionHeight)
        .clamp(84.0, screenHeight * 0.42)
        .toDouble();

    return Stack(
      children: [
        Positioned(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: MediaQuery.paddingOf(context).top + AppSpacing.sm,
          child: _CommentOverlay(
            text: state.commentText,
            visible:
                state.commentVisible && state.commentText.trim().isNotEmpty,
            maxWidth: screenSize.width * 0.78,
          ),
        ),
        Positioned(
          right: 0,
          top: MediaQuery.paddingOf(context).top + AppSpacing.sm,
          child: Opacity(
            opacity: 0.62,
            child: _MinimalIconButton(
              icon: state.commentsEnabled
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              tooltip: state.commentsEnabled
                  ? 'Hide comments'
                  : 'Show comments',
              onPressed: state.ready ? onToggleComments : null,
              size: 44,
              iconSize: 22,
              showBackground: false,
            ),
          ),
        ),
        Positioned(
          right: AppSpacing.lg,
          top: screenHeight * 0.5 - PlaybackSpeedWheel.selectedCenterOffset,
          child: Column(
            children: [
              PlaybackSpeedWheel(
                speed: state.playbackSpeed,
                enabled: state.ready,
                onChanged: onSpeedChanged,
              ),
              const SizedBox(height: AppSpacing.lg),
              _OutlinedCircleButton(
                icon: Icons.threesixty_rounded,
                tooltip: 'Reset camera',
                onPressed: state.ready ? onResetCamera : null,
                dimension: 46,
                iconSize: 28,
              ),
            ],
          ),
        ),
        Positioned(
          left: timelineLeft,
          right: timelineRight,
          bottom: timelineTop + AppSpacing.xs,
          child: IgnorePointer(
            child: Text(
              state.sequenceName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTypography.label.copyWith(
                color: AppColors.textPrimary,
                shadows: const [AppShadows.compactImageText],
              ),
            ),
          ),
        ),
        Positioned(
          left: math.max(AppSpacing.xl, timelineLeft),
          right: math.max(AppSpacing.xl, timelineRight),
          bottom: actionBottom,
          child: SizedBox(
            height: actionHeight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _PlaybackButton(
                  icon: state.scopeFocused
                      ? Icons.zoom_out_rounded
                      : Icons.zoom_in_rounded,
                  tooltip: state.scopeFocused
                      ? 'Show full sequence'
                      : 'Focus current move',
                  onPressed: state.ready && state.scopeAvailable
                      ? onToggleScope
                      : null,
                ),
                _PlaybackButton(
                  icon: Icons.skip_previous_rounded,
                  tooltip: 'Previous step',
                  onPressed: state.ready && state.canGoPrevious
                      ? onPreviousStep
                      : null,
                ),
                _CentralPlayButton(
                  isPlaying: state.isPlaying,
                  onPressed: state.ready ? onTogglePlayback : null,
                ),
                _PlaybackButton(
                  icon: Icons.skip_next_rounded,
                  tooltip: 'Next step',
                  onPressed: state.ready && state.canGoNext ? onNextStep : null,
                ),
                _PlaybackButton(
                  icon: Icons.loop_rounded,
                  muted: !state.loopEnabled,
                  tooltip: state.loopEnabled ? 'Disable loop' : 'Enable loop',
                  onPressed: state.ready ? onToggleLoop : null,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CommentOverlay extends StatelessWidget {
  const _CommentOverlay({
    required this.text,
    required this.visible,
    required this.maxWidth,
  });

  final String text;
  final bool visible;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final textStyle = AppTypography.body.copyWith(color: AppColors.textPrimary);
    final horizontalPadding = AppSpacing.lg * 2;
    final contentMaxWidth = math.max(0.0, maxWidth - horizontalPadding);
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: textStyle),
      maxLines: 1,
      textDirection: Directionality.of(context),
    )..layout();
    final usesMaximumWidth = textPainter.width >= contentMaxWidth;

    return AnimatedSwitcher(
      duration: AppMotion.quick,
      child: visible
          ? Align(
              key: ValueKey('comment-$text'),
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: IntrinsicWidth(
                  child: _MinimalSurface(
                    backgroundAlpha: 0.42,
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.md,
                      AppSpacing.lg,
                      AppSpacing.md,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: contentMaxWidth,
                        maxHeight: 82,
                      ),
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        child: Text(
                          text,
                          textAlign: usesMaximumWidth
                              ? TextAlign.left
                              : TextAlign.center,
                          textWidthBasis: TextWidthBasis.longestLine,
                          style: textStyle,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            )
          : const SizedBox.shrink(key: ValueKey('no-comment')),
    );
  }
}

class PlaybackSpeedWheel extends StatefulWidget {
  const PlaybackSpeedWheel({
    super.key,
    required this.speed,
    required this.enabled,
    required this.onChanged,
  });

  final double speed;
  final bool enabled;
  final ValueChanged<double> onChanged;

  static const selectedCenterOffset = 72.0;

  @override
  State<PlaybackSpeedWheel> createState() => _PlaybackSpeedWheelState();
}

class _PlaybackSpeedWheelState extends State<PlaybackSpeedWheel>
    with SingleTickerProviderStateMixin {
  static const _speeds = <double>[0.1, 0.25, 0.5, 1, 1.5, 2];
  static const _dragDistancePerStep = 44.0;
  static const _itemSpacing = 44.0;
  static const _snapThreshold = 0.1;
  static const _momentumVelocityThreshold = 240.0;
  static const _momentumProjectionSeconds = 0.065;

  late final AnimationController _snapController;
  late double _virtualIndex;
  double _dragStartIndex = 0;
  double _dragDelta = 0;
  double _snapStart = 0;
  double _snapTarget = 0;
  double? _lastSentSpeed;
  bool _dragging = false;
  bool _snapAfterMomentum = false;
  Curve _animationCurve = Curves.easeOutCubic;

  @override
  void initState() {
    super.initState();
    _virtualIndex = _closestIndex(widget.speed).toDouble();
    _snapController =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 120),
          )
          ..addListener(_tickSnap)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              _virtualIndex = _snapTarget;

              if (_snapAfterMomentum) {
                _snapAfterMomentum = false;
                final roundedTarget = _virtualIndex.roundToDouble();
                if ((roundedTarget - _virtualIndex).abs() > 0.001) {
                  _animateTo(
                    roundedTarget,
                    const Duration(milliseconds: 320),
                    curve: Curves.easeInOutCubic,
                  );
                  return;
                }
              }

              _emitSpeed(_evaluateSpeed(_virtualIndex), force: true);
            }
          });
  }

  @override
  void didUpdateWidget(covariant PlaybackSpeedWheel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_dragging && !_snapController.isAnimating) {
      final nextIndex = _closestIndex(widget.speed).toDouble();
      if ((nextIndex - _virtualIndex).abs() > 0.001) {
        setState(() => _virtualIndex = nextIndex);
      }
    }
  }

  @override
  void dispose() {
    _snapController.dispose();
    super.dispose();
  }

  void _onDragStart(DragStartDetails details) {
    if (!widget.enabled) return;
    _snapController.stop();
    _dragging = true;
    _dragStartIndex = _virtualIndex;
    _dragDelta = 0;
    _lastSentSpeed = null;
    _snapAfterMomentum = false;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_dragging) return;
    _dragDelta += details.primaryDelta ?? 0;
    final nextIndex = (_dragStartIndex + _dragDelta / _dragDistancePerStep)
        .clamp(0.0, (_speeds.length - 1).toDouble());
    setState(() => _virtualIndex = nextIndex);
    _emitSpeed(_evaluateSpeed(nextIndex));
  }

  void _onDragEnd(DragEndDetails details) {
    if (!_dragging) return;
    _dragging = false;

    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() >= _momentumVelocityThreshold) {
      final projectedIndex =
          (_virtualIndex +
                  (velocity / _dragDistancePerStep) *
                      _momentumProjectionSeconds)
              .clamp(0.0, (_speeds.length - 1).toDouble());
      if ((projectedIndex - _virtualIndex).abs() > 0.05) {
        final momentumDuration = Duration(
          milliseconds: (420 + velocity.abs() * 0.15).clamp(480, 850).round(),
        );
        _snapAfterMomentum = true;
        _animateTo(
          projectedIndex,
          momentumDuration,
          curve: Curves.easeOutCubic,
        );
        return;
      }
    }

    final delta = _virtualIndex - _dragStartIndex;
    final target = delta.abs() > _snapThreshold
        ? _virtualIndex.round()
        : _dragStartIndex.round();
    _animateTo(
      target.toDouble(),
      const Duration(milliseconds: 240),
      curve: Curves.easeInOutCubic,
    );
  }

  void _resetToNormalSpeed() {
    if (!widget.enabled) return;
    _dragging = false;
    _snapAfterMomentum = false;
    _snapController.stop();
    _animateTo(
      _speeds.indexOf(1).toDouble(),
      const Duration(milliseconds: 280),
      curve: Curves.easeInOutCubic,
    );
  }

  void _selectIndex(int index) {
    if (!widget.enabled) return;
    _dragging = false;
    _snapAfterMomentum = false;
    _snapController.stop();
    _animateTo(
      index.toDouble(),
      const Duration(milliseconds: 220),
      curve: Curves.easeInOutCubic,
    );
  }

  void _animateTo(
    double target,
    Duration duration, {
    Curve curve = Curves.easeOutCubic,
  }) {
    _snapStart = _virtualIndex;
    _snapTarget = target.clamp(0, (_speeds.length - 1).toDouble());
    _animationCurve = curve;
    _snapController
      ..duration = duration
      ..forward(from: 0);
  }

  void _tickSnap() {
    final eased = _animationCurve.transform(_snapController.value);
    final next = _snapStart + (_snapTarget - _snapStart) * eased;
    setState(() => _virtualIndex = next);
    _emitSpeed(_evaluateSpeed(next));
  }

  void _emitSpeed(double value, {bool force = false}) {
    if (!force &&
        _lastSentSpeed != null &&
        (value - _lastSentSpeed!).abs() < 0.0005) {
      return;
    }
    _lastSentSpeed = value;
    widget.onChanged(value);
  }

  double _evaluateSpeed(double index) {
    final lower = index.floor().clamp(0, _speeds.length - 1);
    final upper = index.ceil().clamp(0, _speeds.length - 1);
    if (lower == upper) return _speeds[lower];
    final t = index - lower;
    return _speeds[lower] + (_speeds[upper] - _speeds[lower]) * t;
  }

  int _closestIndex(double speed) {
    var bestIndex = 0;
    var bestDistance = double.infinity;
    for (var index = 0; index < _speeds.length; index++) {
      final distance = (_speeds[index] - speed).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        bestIndex = index;
      }
    }
    return bestIndex;
  }

  String _label(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value == 0.25 ? '0.25' : value.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTap: _resetToNormalSpeed,
      onVerticalDragStart: _onDragStart,
      onVerticalDragUpdate: _onDragUpdate,
      onVerticalDragEnd: _onDragEnd,
      child: _MinimalSurface(
        backgroundAlpha: 0.26,
        borderRadius: AppRadii.pill,
        child: SizedBox(
          width: 50,
          height: 144,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  top: 51,
                  bottom: 51,
                  left: AppSpacing.xs,
                  right: AppSpacing.xs,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.black.withValues(
                        alpha: AppOpacity.muted,
                      ),
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                  ),
                ),
                for (var index = 0; index < _speeds.length; index++)
                  _buildSpeedLabel(index),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpeedLabel(int index) {
    final distance = index - _virtualIndex;
    final absoluteDistance = distance.abs();
    final alpha = absoluteDistance <= 1
        ? 1 - (1 - 0.5) * absoluteDistance
        : math.max(0, 0.5 * (1 - (absoluteDistance - 1) / 0.5));
    final scale = 1 - 0.1 * math.min(absoluteDistance, 1);

    return Positioned(
      top:
          PlaybackSpeedWheel.selectedCenterOffset -
          22 -
          distance * _itemSpacing,
      left: 0,
      right: 0,
      height: 44,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: widget.enabled ? () => _selectIndex(index) : null,
        child: Center(
          child: Opacity(
            opacity: (widget.enabled ? alpha.clamp(0, 1) : alpha * 0.3)
                .toDouble(),
            child: Transform.scale(
              scale: scale,
              child: Text(
                _label(_speeds[index]),
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(
                  fontSize: absoluteDistance < 0.5 ? 15 : 14,
                  fontWeight: absoluteDistance < 0.5
                      ? FontWeight.w700
                      : FontWeight.w400,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MinimalSurface extends StatelessWidget {
  const _MinimalSurface({
    required this.child,
    this.padding = EdgeInsets.zero,
    this.backgroundAlpha = 0.48,
    this.borderRadius = AppRadii.medium,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double backgroundAlpha;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(borderRadius),
    );
    return _PreviewControlBorder(
      borderRadius: borderRadius,
      child: Material(
        color: AppColors.black.withValues(alpha: backgroundAlpha),
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class _MinimalIconButton extends StatelessWidget {
  const _MinimalIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = 52,
    this.iconSize = 32,
    this.showBackground = true,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;
  final bool showBackground;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      constraints: BoxConstraints.tightFor(width: size, height: size),
      tooltip: tooltip,
      onPressed: onPressed,
      iconSize: iconSize,
      style: IconButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        disabledForegroundColor: AppColors.textDisabled,
        backgroundColor: showBackground
            ? AppColors.black.withValues(alpha: AppOpacity.muted)
            : AppColors.transparent,
      ),
      icon: Icon(icon),
    );
  }
}

class _PlaybackButton extends StatelessWidget {
  const _PlaybackButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.muted = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      iconSize: 32,
      color: AppColors.textPrimary,
      disabledColor: AppColors.textDisabled,
      icon: Icon(icon, size: 32, color: muted ? AppColors.textDisabled : null),
    );
  }
}

class _CentralPlayButton extends StatelessWidget {
  const _CentralPlayButton({required this.isPlaying, required this.onPressed});

  final bool isPlaying;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return _OutlinedCircleButton(
      icon: isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
      tooltip: isPlaying ? 'Pause' : 'Play',
      onPressed: onPressed,
      iconSize: 38,
    );
  }
}

class _OutlinedCircleButton extends StatelessWidget {
  const _OutlinedCircleButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.iconSize,
    this.dimension = 62,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double iconSize;
  final double dimension;

  @override
  Widget build(BuildContext context) {
    const shape = CircleBorder();
    return Tooltip(
      message: tooltip,
      child: _PreviewControlBorder(
        borderRadius: dimension / 2,
        child: Material(
          color: AppColors.black.withValues(alpha: AppOpacity.subtle),
          shape: shape,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            customBorder: shape,
            onTap: onPressed,
            child: SizedBox.square(
              dimension: dimension,
              child: Icon(
                icon,
                size: iconSize,
                color: onPressed == null
                    ? AppColors.textDisabled
                    : AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewControlBorder extends StatelessWidget {
  const _PreviewControlBorder({
    required this.borderRadius,
    required this.child,
  });

  final double borderRadius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _PreviewControlBorderPainter(
        borderRadius: borderRadius,
      ),
      child: child,
    );
  }
}

class _PreviewControlBorderPainter extends CustomPainter {
  const _PreviewControlBorderPainter({required this.borderRadius});

  final double borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = _previewControlBorder.width;
    final rect = (Offset.zero & size).deflate(strokeWidth / 2);
    final effectiveRadius = math.min(
      borderRadius,
      math.min(rect.width, rect.height) / 2,
    );
    final border = RRect.fromRectAndRadius(
      rect,
      Radius.circular(effectiveRadius),
    );
    canvas.drawRRect(
      border,
      Paint()
        ..color = _previewControlBorder.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(covariant _PreviewControlBorderPainter oldDelegate) {
    return oldDelegate.borderRadius != borderRadius;
  }
}
