part of '../../screens/sequence_builder_screen.dart';

class _TimelineSection extends StatefulWidget {
  const _TimelineSection({
    super.key,
    required this.steps,
    required this.pendingReservations,
    required this.openPlaceholderHandle,
    required this.requiredNextPosition,
    required this.onRemoveAt,
    required this.onItemTap,
    required this.onAddStep,
    required this.resolvePreviewPath,
    required this.resolveCachedPreviewPath,
  });

  final List<_TimelineVisualStep> steps;
  final List<_PendingTimelineReservation> pendingReservations;
  final _TimelinePlaceholderHandle openPlaceholderHandle;
  final String requiredNextPosition;
  final void Function(int index) onRemoveAt;
  final ValueChanged<AnimationLibraryItem> onItemTap;
  final VoidCallback onAddStep;
  final Future<String?> Function(String? previewPath) resolvePreviewPath;
  final String? Function(String? previewPath) resolveCachedPreviewPath;

  @override
  State<_TimelineSection> createState() => _TimelineSectionState();
}

class _TimelineSectionState extends State<_TimelineSection> {
  List<_TimelineRailSegmentData> _buildRailSegments() {
    final segments = <_TimelineRailSegmentData>[];
    var top = 0.0;

    for (final step in widget.steps) {
      segments.add(
        _TimelineRailSegmentData(
          id: 'connection-${step.id}',
          top: top,
          extent: _TimelineRail.positionToPositionExtent,
          animateOnMount: step.animateOnMount,
          delay: step.animateOnMount
              ? const Duration(milliseconds: 202)
              : Duration.zero,
        ),
      );
      top += _TimelineRail.positionToPositionExtent;
    }

    final pendingReservations = widget.pendingReservations;
    for (
      var index = 0;
      index < math.max(0, pendingReservations.length - 1);
      index++
    ) {
      segments.add(
        _TimelineRailSegmentData(
          id: 'connection-${pendingReservations[index].handle.id}',
          top: top,
          extent: _TimelineRail.positionToPositionExtent,
          animateOnMount: true,
          delay: Duration.zero,
        ),
      );
      top += _TimelineRail.positionToPositionExtent;
    }

    final terminalHandle = pendingReservations.isEmpty
        ? widget.openPlaceholderHandle
        : pendingReservations.last.handle;
    segments.add(
      _TimelineRailSegmentData(
        id: 'connection-${terminalHandle.id}',
        top: top,
        extent: _TimelineRail.positionToPlaceholderExtent,
        animateOnMount: terminalHandle.animateOnMount,
        delay: pendingReservations.isNotEmpty
            ? Duration.zero
            : terminalHandle.animateOnMount
            ? _timelinePlaceholderRevealDelay
            : Duration.zero,
      ),
    );

    return segments;
  }

  @override
  Widget build(BuildContext context) {
    final pendingReservations = widget.pendingReservations;
    final firstPosition = widget.steps.isNotEmpty
        ? widget.steps.first.item.startPosition
        : pendingReservations.isNotEmpty
        ? pendingReservations.first.item.startPosition
        : widget.requiredNextPosition;

    return Stack(
      children: [
        Positioned(
          left: 13.5,
          top: 14,
          child: _TimelineRail(segments: _buildRailSegments()),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TimelinePositionNode(value: firstPosition),
            const SizedBox(height: 6),
            for (var index = 0; index < widget.steps.length; index++)
              _AnimatedTimelineStepEntry(
                key: ValueKey('timeline-step-${widget.steps[index].id}'),
                index: index,
                step: widget.steps[index],
                onRemove: () => widget.onRemoveAt(index),
                onTap: () => widget.onItemTap(widget.steps[index].item),
                resolvePreviewPath: widget.resolvePreviewPath,
                resolveCachedPreviewPath: widget.resolveCachedPreviewPath,
              ),
            for (
              var index = 0;
              index < pendingReservations.length;
              index++
            ) ...[
              _RevealingAddTimelineStep(
                key: ValueKey(
                  'placeholder-${pendingReservations[index].handle.id}',
                ),
                handle: pendingReservations[index].handle,
                index: widget.steps.length + index,
                requiredPosition: pendingReservations[index].item.startPosition,
                isFirstStep: widget.steps.isEmpty && index == 0,
                revealDelay: Duration.zero,
                onTap: widget.onAddStep,
              ),
              if (index < pendingReservations.length - 1) ...[
                const SizedBox(height: 6),
                _RevealingTimelinePositionNode(
                  key: ValueKey(
                    'pending-position-${pendingReservations[index + 1].handle.id}',
                  ),
                  value: pendingReservations[index].item.endPosition,
                ),
                const SizedBox(height: 6),
              ],
            ],
            if (pendingReservations.isEmpty)
              _RevealingAddTimelineStep(
                key: ValueKey('placeholder-${widget.openPlaceholderHandle.id}'),
                handle: widget.openPlaceholderHandle,
                index: widget.steps.length,
                requiredPosition: widget.requiredNextPosition,
                isFirstStep: widget.steps.isEmpty,
                revealDelay: _timelinePlaceholderRevealDelay,
                onTap: widget.onAddStep,
              ),
          ],
        ),
      ],
    );
  }
}

class _TimelineRailSegmentData {
  const _TimelineRailSegmentData({
    required this.id,
    required this.top,
    required this.extent,
    required this.animateOnMount,
    required this.delay,
  });

  final String id;
  final double top;
  final double extent;
  final bool animateOnMount;
  final Duration delay;
}

class _DisplayedTimelineRailSegment {
  _DisplayedTimelineRailSegment({required this.data, required this.isPresent});

  _TimelineRailSegmentData data;
  bool isPresent;
}

class _TimelineRail extends StatefulWidget {
  const _TimelineRail({required this.segments});

  static const double positionToPositionExtent = 136;
  static const double positionToPlaceholderExtent = 68;

  final List<_TimelineRailSegmentData> segments;

  @override
  State<_TimelineRail> createState() => _TimelineRailState();
}

class _TimelineRailState extends State<_TimelineRail> {
  late final List<_DisplayedTimelineRailSegment> _displayedSegments;

  @override
  void initState() {
    super.initState();
    _displayedSegments = [
      for (var index = 0; index < widget.segments.length; index++)
        _DisplayedTimelineRailSegment(
          data: widget.segments[index],
          isPresent: true,
        ),
    ];
  }

  @override
  void didUpdateWidget(covariant _TimelineRail oldWidget) {
    super.didUpdateWidget(oldWidget);

    final nextById = {
      for (var index = 0; index < widget.segments.length; index++)
        widget.segments[index].id: widget.segments[index],
    };
    final displayedById = {
      for (final segment in _displayedSegments) segment.data.id: segment,
    };

    for (final displayed in _displayedSegments) {
      final next = nextById[displayed.data.id];
      if (next == null) {
        displayed.isPresent = false;
      } else {
        displayed
          ..data = next
          ..isPresent = true;
      }
    }

    for (final next in nextById.values) {
      if (displayedById.containsKey(next.id)) continue;
      _displayedSegments.add(
        _DisplayedTimelineRailSegment(data: next, isPresent: true),
      );
    }
  }

  void _removeDismissedSegment(String id) {
    if (!mounted || widget.segments.any((segment) => segment.id == id)) return;
    setState(() {
      _displayedSegments.removeWhere((segment) => segment.data.id == id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final railHeight = _displayedSegments.fold<double>(
      0,
      (height, segment) =>
          math.max(height, segment.data.top + segment.data.extent),
    );

    return SizedBox(
      width: 1,
      height: railHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final segment in _displayedSegments)
            Positioned(
              key: ValueKey('rail-segment-${segment.data.id}'),
              top: segment.data.top,
              child: _AnimatedTimelineRailSegment(
                data: segment.data,
                isPresent: segment.isPresent,
                onDismissed: () => _removeDismissedSegment(segment.data.id),
              ),
            ),
        ],
      ),
    );
  }
}

class _AnimatedTimelineRailSegment extends StatefulWidget {
  const _AnimatedTimelineRailSegment({
    required this.data,
    required this.isPresent,
    required this.onDismissed,
  });

  final _TimelineRailSegmentData data;
  final bool isPresent;
  final VoidCallback onDismissed;

  @override
  State<_AnimatedTimelineRailSegment> createState() =>
      _AnimatedTimelineRailSegmentState();
}

class _AnimatedTimelineRailSegmentState
    extends State<_AnimatedTimelineRailSegment>
    with TickerProviderStateMixin {
  static const _drawDuration = Duration(milliseconds: 320);
  static const _eraseDuration = Duration(milliseconds: 220);

  late final AnimationController _controller;
  late final AnimationController _extentController;
  late Animation<double> _extentAnimation;
  Timer? _delayTimer;
  Timer? _extentDelayTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _drawDuration,
      reverseDuration: _eraseDuration,
      value: widget.data.animateOnMount ? 0 : 1,
    )..addStatusListener(_handleStatus);
    _extentController = AnimationController(
      vsync: this,
      duration: _drawDuration,
    );
    _extentAnimation = AlwaysStoppedAnimation(widget.data.extent);

    if (widget.data.animateOnMount) {
      _draw(widget.data.delay);
    }
  }

  @override
  void didUpdateWidget(covariant _AnimatedTimelineRailSegment oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.data.extent != widget.data.extent) {
      _extentDelayTimer?.cancel();
      final delay = widget.data.extent > oldWidget.data.extent
          ? widget.data.delay
          : Duration.zero;
      if (delay == Duration.zero) {
        _animateExtentTo(widget.data.extent);
      } else {
        _extentDelayTimer = Timer(delay, () {
          if (!mounted) return;
          _animateExtentTo(widget.data.extent);
        });
      }
    }

    if (oldWidget.isPresent && !widget.isPresent) {
      _delayTimer?.cancel();
      _controller.reverse();
    } else if (!oldWidget.isPresent && widget.isPresent) {
      _draw(Duration.zero);
    }
  }

  void _draw(Duration delay) {
    _delayTimer?.cancel();
    if (delay == Duration.zero) {
      _controller.forward();
      return;
    }
    _delayTimer = Timer(delay, () {
      if (mounted && widget.isPresent) _controller.forward();
    });
  }

  void _animateExtentTo(double extent) {
    _extentAnimation = Tween<double>(begin: _extentAnimation.value, end: extent)
        .animate(
          CurvedAnimation(
            parent: _extentController,
            curve: Curves.easeInOutCubic,
          ),
        );
    _extentController.forward(from: 0);
  }

  void _handleStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed && !widget.isPresent) {
      widget.onDismissed();
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _extentDelayTimer?.cancel();
    _controller
      ..removeStatusListener(_handleStatus)
      ..dispose();
    _extentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_controller, _extentController]),
      builder: (context, _) {
        final progress = Curves.easeInOutCubic.transform(_controller.value);
        final animatedExtent = _extentAnimation.value;
        return SizedBox(
          width: 1,
          height: math.max(widget.data.extent, animatedExtent),
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              width: 1,
              height: animatedExtent * progress,
              color: Colors.white.withValues(alpha: 0.14),
            ),
          ),
        );
      },
    );
  }
}

class _RevealingTimelinePositionNode extends StatelessWidget {
  const _RevealingTimelinePositionNode({super.key, required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 238),
      curve: Curves.easeOutCubic,
      builder: (context, progress, child) {
        return Opacity(
          opacity: progress,
          child: Transform.translate(
            offset: Offset(0, -6 * (1 - progress)),
            child: child,
          ),
        );
      },
      child: _TimelinePositionNode(value: value),
    );
  }
}

class _AnimatedTimelineStepEntry extends StatefulWidget {
  const _AnimatedTimelineStepEntry({
    super.key,
    required this.index,
    required this.step,
    required this.onRemove,
    required this.onTap,
    required this.resolvePreviewPath,
    required this.resolveCachedPreviewPath,
  });

  final int index;
  final _TimelineVisualStep step;
  final VoidCallback onRemove;
  final VoidCallback onTap;
  final Future<String?> Function(String? previewPath) resolvePreviewPath;
  final String? Function(String? previewPath) resolveCachedPreviewPath;

  @override
  State<_AnimatedTimelineStepEntry> createState() =>
      _AnimatedTimelineStepEntryState();
}

class _AnimatedTimelineStepEntryState extends State<_AnimatedTimelineStepEntry>
    with SingleTickerProviderStateMixin {
  static const _insertionDuration = Duration(milliseconds: 720);

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _insertionDuration,
      value: widget.step.animateOnMount ? 0 : 1,
    );

    if (widget.step.animateOnMount) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _interval(double value, double start, double end) {
    return ((value - start) / (end - start)).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final insertionProgress = _controller.value;
        final positionReveal = widget.step.animatePositionOnMount
            ? Curves.easeOut.transform(_interval(insertionProgress, 0.34, 0.64))
            : 1.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TimelineAnimationTile(
              index: widget.index,
              item: widget.step.item,
              insertionProgress: insertionProgress,
              onRemove: widget.onRemove,
              onTap: widget.onTap,
              resolvePreviewPath: widget.resolvePreviewPath,
              resolveCachedPreviewPath: widget.resolveCachedPreviewPath,
            ),
            const SizedBox(height: 6),
            _AnimatedTimelinePositionNode(
              value: widget.step.item.endPosition,
              progress: positionReveal,
            ),
            const SizedBox(height: 6),
          ],
        );
      },
    );
  }
}

class _RevealingAddTimelineStep extends StatefulWidget {
  const _RevealingAddTimelineStep({
    super.key,
    required this.handle,
    required this.index,
    required this.requiredPosition,
    required this.isFirstStep,
    required this.revealDelay,
    required this.onTap,
  });

  final _TimelinePlaceholderHandle handle;
  final int index;
  final String requiredPosition;
  final bool isFirstStep;
  final Duration revealDelay;
  final VoidCallback onTap;

  @override
  State<_RevealingAddTimelineStep> createState() =>
      _RevealingAddTimelineStepState();
}

class _RevealingAddTimelineStepState extends State<_RevealingAddTimelineStep>
    with SingleTickerProviderStateMixin {
  static const _revealDuration = Duration(milliseconds: 238);

  late final AnimationController _controller;
  Timer? _revealTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _revealDuration,
      value: widget.handle.animateOnMount ? 0 : 1,
    );

    if (widget.handle.animateOnMount) {
      _startReveal(widget.revealDelay);
    }
  }

  @override
  void didUpdateWidget(covariant _RevealingAddTimelineStep oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.revealDelay > Duration.zero &&
        widget.revealDelay == Duration.zero &&
        !_controller.isCompleted) {
      _startReveal(Duration.zero);
    }
  }

  void _startReveal(Duration delay) {
    _revealTimer?.cancel();
    if (delay == Duration.zero) {
      _controller.forward();
      return;
    }

    _revealTimer = Timer(delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _revealTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return _AddTimelineStep(
          key: widget.handle.containerKey,
          flightTargetKey: widget.handle.flightTargetKey,
          index: widget.index,
          requiredPosition: widget.requiredPosition,
          isFirstStep: widget.isFirstStep,
          revealProgress: Curves.easeOutCubic.transform(_controller.value),
          onTap: widget.onTap,
        );
      },
    );
  }
}

class _AddTimelineStep extends StatelessWidget {
  const _AddTimelineStep({
    super.key,
    required this.flightTargetKey,
    required this.index,
    required this.requiredPosition,
    required this.isFirstStep,
    this.revealProgress = 1,
    required this.onTap,
  });

  final Key flightTargetKey;
  final int index;
  final String requiredPosition;
  final bool isFirstStep;
  final double revealProgress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Opacity(
          opacity: revealProgress,
          child: Transform.scale(
            scale: 0.7 + 0.3 * revealProgress,
            child: _StepNumber(index: index, isPending: true),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: IgnorePointer(
            ignoring: revealProgress < 0.95,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final fullWidth = constraints.maxWidth;

                return Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: fullWidth * revealProgress,
                    height: 96,
                    child: Material(
                      color: Colors.white.withOpacity(0.035),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: BorderSide(color: Colors.white.withOpacity(0.10)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: OverflowBox(
                        alignment: Alignment.centerLeft,
                        minWidth: fullWidth,
                        maxWidth: fullWidth,
                        minHeight: 96,
                        maxHeight: 96,
                        child: InkWell(
                          onTap: onTap,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Container(
                                  key: flightTargetKey,
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF8F55FF,
                                    ).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(
                                        0xFFC8A7FF,
                                      ).withOpacity(0.38),
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.add_rounded,
                                    size: 34,
                                    color: Color(0xFFC8A7FF),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        isFirstStep
                                            ? 'Add first animation'
                                            : 'Add next animation',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        requiredPosition == 'Any'
                                            ? 'Any start position'
                                            : 'Required start: $requiredPosition',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.60),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _TimelineAnimationTile extends StatelessWidget {
  const _TimelineAnimationTile({
    required this.index,
    required this.item,
    this.insertionProgress = 1,
    required this.onRemove,
    required this.onTap,
    required this.resolvePreviewPath,
    required this.resolveCachedPreviewPath,
  });

  final int index;
  final AnimationLibraryItem item;
  final double insertionProgress;
  final VoidCallback onRemove;
  final VoidCallback onTap;
  final Future<String?> Function(String? previewPath) resolvePreviewPath;
  final String? Function(String? previewPath) resolveCachedPreviewPath;

  @override
  Widget build(BuildContext context) {
    final previewProgress = Curves.easeOut.transform(
      ((insertionProgress - 0.02) / 0.46).clamp(0.0, 1.0),
    );
    final previewScale = switch (previewProgress) {
      < 0.38 => 0.45 + (1.12 - 0.45) * (previewProgress / 0.38),
      < 0.68 => 1.12 - 0.16 * ((previewProgress - 0.38) / 0.30),
      _ => 0.96 + 0.04 * ((previewProgress - 0.68) / 0.32),
    };
    final previewRotation =
        math.sin(previewProgress * math.pi * 3) * (1 - previewProgress) * 0.055;
    final textProgress = Curves.easeOutCubic.transform(
      ((insertionProgress - 0.14) / 0.38).clamp(0.0, 1.0),
    );

    return Row(
      children: [
        _StepNumber(index: index),
        const SizedBox(width: 10),
        Expanded(
          child: Material(
            color: Colors.white.withOpacity(0.06),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: Colors.white.withOpacity(0.09)),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Transform.rotate(
                      angle: previewRotation,
                      child: Transform.scale(
                        scale: previewScale,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: 72,
                            height: 72,
                            child: AnimationPreviewFrame(
                              previewPath: item.previewPath,
                              resolvePreviewPath: resolvePreviewPath,
                              resolveCachedPreviewPath:
                                  resolveCachedPreviewPath,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ClipRect(
                        child: Opacity(
                          opacity: textProgress,
                          child: Transform.translate(
                            offset: Offset(-36 * (1 - textProgress), 0),
                            child: Padding(
                              padding: const EdgeInsets.only(left: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item.animationName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.56),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Opacity(
                      opacity: textProgress,
                      child: IconButton(
                        onPressed: onRemove,
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StepNumber extends StatelessWidget {
  const _StepNumber({required this.index, this.isPending = false});

  final int index;
  final bool isPending;

  @override
  Widget build(BuildContext context) {
    final background = Theme.of(context).scaffoldBackgroundColor;
    final foreground = isPending
        ? const Color(0xFFC8A7FF)
        : Colors.white.withOpacity(0.78);

    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: background,
        border: Border.all(
          color: isPending
              ? const Color(0xFFC8A7FF).withOpacity(0.38)
              : Colors.white.withOpacity(0.12),
        ),
      ),
      child: Text(
        '${index + 1}',
        style: TextStyle(
          color: foreground,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _AnimatedTimelinePositionNode extends StatelessWidget {
  const _AnimatedTimelinePositionNode({
    required this.value,
    required this.progress,
  });

  final String value;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: progress,
      child: Transform.translate(
        offset: Offset(0, -8 * (1 - progress)),
        child: _TimelinePositionNode(value: value),
      ),
    );
  }
}

class _TimelinePositionNode extends StatelessWidget {
  const _TimelinePositionNode({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Center(
              child: Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: Color(0xFFAA8BDD),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFFB9A2DE),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
