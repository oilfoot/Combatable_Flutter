import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/unity_preview_state.dart';
import '../theme/app_theme.dart';

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
    const actionGap = 8.0;
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
            commentsEnabled: state.commentsEnabled,
            enabled: state.ready,
            maxWidth: screenSize.width * 0.84,
            onToggleComments: onToggleComments,
          ),
        ),
        Positioned(
          right: AppSpacing.lg,
          top: screenHeight * 0.405,
          child: Column(
            children: [
              PlaybackSpeedWheel(
                speed: state.playbackSpeed,
                enabled: state.ready,
                onChanged: onSpeedChanged,
              ),
              const SizedBox(height: AppSpacing.lg),
              _MinimalIconButton(
                icon: Icons.threesixty_rounded,
                tooltip: 'Reset camera',
                onPressed: state.ready ? onResetCamera : null,
                size: 46,
                iconSize: 28,
                showBackground: false,
                showBorder: true,
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
                  icon: Icons.search_rounded,
                  tooltip: state.scopeFocused
                      ? 'Show full sequence'
                      : 'Focus current move',
                  active: state.scopeFocused,
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
                  tooltip: state.loopEnabled ? 'Disable loop' : 'Enable loop',
                  active: state.loopEnabled,
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
    required this.commentsEnabled,
    required this.enabled,
    required this.maxWidth,
    required this.onToggleComments,
  });

  final String text;
  final bool visible;
  final bool commentsEnabled;
  final bool enabled;
  final double maxWidth;
  final VoidCallback onToggleComments;

  @override
  Widget build(BuildContext context) {
    final icon = commentsEnabled
        ? Icons.visibility_outlined
        : Icons.visibility_off_outlined;
    final tooltip = commentsEnabled ? 'Hide comments' : 'Show comments';

    return AnimatedSwitcher(
      duration: AppMotion.quick,
      child: visible
          ? Align(
              key: ValueKey('comment-$text'),
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: maxWidth,
                child: _MinimalSurface(
                  backgroundAlpha: 0.42,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    52,
                    AppSpacing.md,
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 82),
                          child: SingleChildScrollView(
                            physics: const ClampingScrollPhysics(),
                            child: Text(
                              text,
                              textAlign: TextAlign.center,
                              style: AppTypography.body.copyWith(
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: -46,
                        top: -8,
                        child: Opacity(
                          opacity: 0.68,
                          child: _MinimalIconButton(
                            icon: icon,
                            tooltip: tooltip,
                            onPressed: enabled ? onToggleComments : null,
                            size: 40,
                            iconSize: 21,
                            showBackground: false,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : Align(
              key: const ValueKey('comment-toggle'),
              alignment: Alignment.topRight,
              child: Opacity(
                opacity: 0.62,
                child: _MinimalIconButton(
                  icon: icon,
                  tooltip: tooltip,
                  onPressed: enabled ? onToggleComments : null,
                  size: 44,
                  iconSize: 22,
                  showBackground: false,
                ),
              ),
            ),
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

  @override
  State<PlaybackSpeedWheel> createState() => _PlaybackSpeedWheelState();
}

class _PlaybackSpeedWheelState extends State<PlaybackSpeedWheel>
    with SingleTickerProviderStateMixin {
  static const _speeds = <double>[0.1, 0.25, 0.5, 1, 1.5, 2];
  static const _dragDistancePerStep = 48.0;
  static const _itemSpacing = 48.0;
  static const _snapThreshold = 0.1;

  late final AnimationController _snapController;
  late double _virtualIndex;
  double _dragStartIndex = 0;
  double _dragDelta = 0;
  double _snapStart = 0;
  double _snapTarget = 0;
  double? _lastSentSpeed;
  bool _dragging = false;

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
    _dragStartIndex = _closestIndex(widget.speed).toDouble();
    _virtualIndex = _dragStartIndex;
    _dragDelta = 0;
    _lastSentSpeed = null;
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

    final delta = _virtualIndex - _dragStartIndex;
    final target = delta.abs() > _snapThreshold
        ? _virtualIndex.round()
        : _dragStartIndex.round();
    _animateTo(target.toDouble(), const Duration(milliseconds: 120));
  }

  void _resetToNormalSpeed() {
    if (!widget.enabled) return;
    _dragging = false;
    _animateTo(
      _speeds.indexOf(1).toDouble(),
      const Duration(milliseconds: 200),
    );
  }

  void _animateTo(double target, Duration duration) {
    _snapStart = _virtualIndex;
    _snapTarget = target.clamp(0, (_speeds.length - 1).toDouble());
    _snapController
      ..duration = duration
      ..forward(from: 0);
  }

  void _tickSnap() {
    final eased = Curves.easeOutCubic.transform(_snapController.value);
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
        backgroundAlpha: 0.32,
        child: SizedBox(
          width: 68,
          height: 158,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.medium),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  top: 55,
                  bottom: 55,
                  left: AppSpacing.xs,
                  right: AppSpacing.xs,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.black.withValues(
                        alpha: AppOpacity.muted,
                      ),
                      borderRadius: BorderRadius.circular(AppRadii.small),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                  ),
                ),
                Positioned(
                  right: 3,
                  child: Container(
                    width: 3,
                    height: 20,
                    decoration: BoxDecoration(
                      color: AppColors.accentSoft.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(AppRadii.pill),
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
      top: 79 - 15 - distance * _itemSpacing,
      left: 0,
      right: 0,
      child: Opacity(
        opacity: (widget.enabled ? alpha.clamp(0, 1) : alpha * 0.3).toDouble(),
        child: Transform.scale(
          scale: scale,
          child: Text(
            _label(_speeds[index]),
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(
              fontSize: absoluteDistance < 0.5 ? 19 : 17,
              fontWeight: absoluteDistance < 0.5
                  ? FontWeight.w700
                  : FontWeight.w400,
              color: AppColors.textPrimary,
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
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double backgroundAlpha;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.black.withValues(alpha: backgroundAlpha),
        borderRadius: BorderRadius.circular(AppRadii.medium),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Padding(padding: padding, child: child),
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
    this.showBorder = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;
  final bool showBackground;
  final bool showBorder;

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
        side: showBorder
            ? const BorderSide(color: AppColors.borderStrong)
            : null,
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
    this.active = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      iconSize: 32,
      color: active ? AppColors.accentSoft : AppColors.textPrimary,
      disabledColor: AppColors.textDisabled,
      icon: Icon(icon),
    );
  }
}

class _CentralPlayButton extends StatelessWidget {
  const _CentralPlayButton({required this.isPlaying, required this.onPressed});

  final bool isPlaying;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.black.withValues(alpha: AppOpacity.subtle),
      shape: CircleBorder(
        side: BorderSide(
          color: onPressed == null
              ? AppColors.borderSubtle
              : AppColors.borderStrong,
        ),
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox.square(
          dimension: 62,
          child: Icon(
            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            size: 38,
            color: onPressed == null
                ? AppColors.textDisabled
                : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
