import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/library_controller.dart';
import '../controllers/sequence_controller.dart';
import '../models/animation_library_item.dart';
import '../widgets/animation/animation_info_sheet.dart';
import '../widgets/animation/animation_card_flight.dart';
import '../widgets/animation/animation_preview_frame.dart';
import '../widgets/sequence_builder_library.dart';

class SequenceBuilderScreen extends StatefulWidget {
  const SequenceBuilderScreen({
    super.key,
    required this.sequenceController,
    required this.libraryController,
    required this.onBuildUnitySequence,
  });

  final SequenceController sequenceController;
  final LibraryController libraryController;
  final Future<void> Function() onBuildUnitySequence;

  @override
  State<SequenceBuilderScreen> createState() => _SequenceBuilderScreenState();
}

class _SequenceBuilderScreenState extends State<SequenceBuilderScreen> {
  static const _previewPopHapticDelay = Duration(milliseconds: 90);
  static const _timelineInsertionScrollDelay = Duration(milliseconds: 200);

  /// A completed step adds a 96 px tile, two 6 px gaps and a 28 px
  /// position node. Reserve it before insertion so one scroll reveals both
  /// the landing tile and the next placeholder.
  static const double _incomingTimelineStepExtent = 136;

  late final TextEditingController _sequenceNameController;
  final ScrollController _timelineScrollController = ScrollController();
  final GlobalKey _timelineViewportKey = GlobalKey(
    debugLabel: 'sequence-timeline-viewport',
  );
  final GlobalKey _timelineTargetKey = GlobalKey(
    debugLabel: 'sequence-timeline-flight-target',
  );
  final GlobalKey _addStepTargetKey = GlobalKey(
    debugLabel: 'sequence-add-step-target',
  );
  final GlobalKey _addStepFlightTargetKey = GlobalKey(
    debugLabel: 'sequence-add-step-flight-target',
  );
  final GlobalKey _libraryPanelKey = GlobalKey(
    debugLabel: 'sequence-library-panel',
  );
  SequenceBuilderLibraryPanelState _libraryPanelState =
      SequenceBuilderLibraryPanelState.fullyCollapsed;

  bool get _isLibraryExpanded =>
      _libraryPanelState == SequenceBuilderLibraryPanelState.expanded;

  @override
  void initState() {
    super.initState();

    _sequenceNameController = TextEditingController(
      text: widget.sequenceController.sequenceName,
    );

    widget.sequenceController.addListener(_onControllerChanged);
    widget.libraryController.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.sequenceController.removeListener(_onControllerChanged);
    widget.libraryController.removeListener(_onControllerChanged);
    _sequenceNameController.dispose();
    _timelineScrollController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (_sequenceNameController.text !=
        widget.sequenceController.sequenceName) {
      _sequenceNameController.text = widget.sequenceController.sequenceName;
      _sequenceNameController.selection = TextSelection.fromPosition(
        TextPosition(offset: _sequenceNameController.text.length),
      );
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _showAnimationInfo(LibraryDisplayItem entry) async {
    await AnimationInfoSheet.show(
      context,
      item: entry.item,
      isDownloaded: entry.isInstalled,
      isDownloading: entry.isDownloading,
      buttonText: widget.libraryController.getPrimaryActionLabel(entry),
      resolvePreviewPath: widget.libraryController.getOrDownloadPreview,
      resolveCachedPreviewPath: widget.libraryController.getCachedPreviewPath,
      onAnimatedPrimaryAction: widget.libraryController.requiresDownload(entry)
          ? null
          : (sourceKey) => _animateAndAdd(
              sourceKey,
              entry,
              flightSize: const Size.square(
                SequenceBuilderLibrary.animationCardExtent,
              ),
            ),
      onPrimaryAction: () async {
        await _handlePrimaryAction(entry);
      },
    );
  }

  Future<void> _showTimelineAnimationInfo(AnimationLibraryItem item) async {
    await AnimationInfoSheet.show(
      context,
      item: item,
      isDownloaded: true,
      isDownloading: false,
      buttonText: 'Add',
      showPrimaryAction: false,
      resolvePreviewPath: widget.libraryController.getOrDownloadPreview,
      resolveCachedPreviewPath: widget.libraryController.getCachedPreviewPath,
      onPrimaryAction: () async {},
    );
  }

  Future<void> _handlePrimaryAction(LibraryDisplayItem entry) async {
    try {
      await widget.libraryController.performPrimaryAction(entry);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add ${entry.item.title}: $e')),
      );
    }
  }

  List<LibraryDisplayItem> get _libraryItems {
    final recommended = widget.libraryController.recommendedNextItems;

    if (recommended.isNotEmpty) {
      return recommended;
    }

    return widget.libraryController.allItems;
  }

  String get _requiredNextPosition {
    final requiredStart = widget.sequenceController.requiredNextStartPosition;

    if (requiredStart == null || requiredStart.trim().isEmpty) {
      return 'Any';
    }

    return requiredStart.trim();
  }

  @override
  Widget build(BuildContext context) {
    final sequence = widget.sequenceController;
    final timelineBottomPadding =
        _libraryPanelState == SequenceBuilderLibraryPanelState.fullyCollapsed
        ? SequenceBuilderLibrary.fullyCollapsedHeight +
              16 +
              _incomingTimelineStepExtent
        : SequenceBuilderLibrary.collapsedHeight +
              16 +
              _incomingTimelineStepExtent;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned.fill(
              child: Column(
                children: [
                  _SequenceHeader(
                    sequenceNameController: _sequenceNameController,
                    onNameChanged: sequence.setSequenceName,
                    onBuildUnitySequence: widget.onBuildUnitySequence,
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () => _setLibraryPanelState(
                        SequenceBuilderLibraryPanelState.fullyCollapsed,
                      ),
                      child: SingleChildScrollView(
                        key: _timelineViewportKey,
                        controller: _timelineScrollController,
                        padding: EdgeInsets.fromLTRB(
                          16,
                          14,
                          16,
                          timelineBottomPadding,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              height: 40,
                              child: Row(
                                children: [
                                  const Text(
                                    'Timeline',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const Spacer(),
                                  Visibility(
                                    visible:
                                        sequence.selectedAnimations.isNotEmpty,
                                    maintainAnimation: true,
                                    maintainSize: true,
                                    maintainState: true,
                                    child: TextButton.icon(
                                      onPressed: sequence.clearAnimations,
                                      icon: const Icon(Icons.refresh, size: 18),
                                      label: const Text('Clear All'),
                                      style: TextButton.styleFrom(
                                        minimumSize: const Size(0, 36),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            _TimelineSection(
                              key: _timelineTargetKey,
                              items: sequence.selectedAnimations,
                              requiredNextPosition: _requiredNextPosition,
                              onRemoveAt: sequence.removeAnimationAt,
                              onItemTap: _showTimelineAnimationInfo,
                              onAddStep: _expandLibrary,
                              addStepKey: _addStepTargetKey,
                              addStepFlightTargetKey: _addStepFlightTargetKey,
                              resolvePreviewPath:
                                  widget.libraryController.getOrDownloadPreview,
                              resolveCachedPreviewPath:
                                  widget.libraryController.getCachedPreviewPath,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                ignoring: !_isLibraryExpanded,
                child: AnimatedOpacity(
                  opacity: _isLibraryExpanded ? 1 : 0,
                  duration: const Duration(milliseconds: 220),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _setLibraryPanelState(
                      SequenceBuilderLibraryPanelState.collapsed,
                    ),
                    child: const ColoredBox(color: Color(0x66000000)),
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: SequenceBuilderLibrary(
                key: _libraryPanelKey,
                panelState: _libraryPanelState,
                onStateChanged: _setLibraryPanelState,
                items: _libraryItems,
                libraryController: widget.libraryController,
                onItemTap: _showAnimationInfo,
                onPrimaryAction: _animateAndAdd,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _setLibraryPanelState(SequenceBuilderLibraryPanelState state) {
    if (_libraryPanelState == state) return;

    setState(() {
      _libraryPanelState = state;
    });
  }

  void _expandLibrary() {
    if (_isLibraryExpanded) return;

    _setLibraryPanelState(SequenceBuilderLibraryPanelState.expanded);
  }

  ({Future<void> scrolling, Offset? flightTarget, bool preScrolled})
  _prepareAddStepFlight() {
    final flightTargetBox =
        _addStepFlightTargetKey.currentContext?.findRenderObject()
            as RenderBox?;
    final currentFlightTarget = flightTargetBox?.localToGlobal(
      Offset(flightTargetBox.size.width / 2, flightTargetBox.size.height / 2),
    );

    if (!_timelineScrollController.hasClients) {
      return (
        scrolling: Future<void>.value(),
        flightTarget: currentFlightTarget,
        preScrolled: false,
      );
    }

    final addStepBox =
        _addStepTargetKey.currentContext?.findRenderObject() as RenderBox?;
    final viewportBox =
        _timelineViewportKey.currentContext?.findRenderObject() as RenderBox?;
    final panelBox =
        _libraryPanelKey.currentContext?.findRenderObject() as RenderBox?;

    if (addStepBox == null || viewportBox == null || panelBox == null) {
      return (
        scrolling: Future<void>.value(),
        flightTarget: currentFlightTarget,
        preScrolled: false,
      );
    }

    final addStepTop = addStepBox.localToGlobal(Offset.zero).dy;
    final addStepBottom = addStepBox
        .localToGlobal(Offset(0, addStepBox.size.height))
        .dy;
    final incomingPlaceholderBottom =
        addStepBottom + _incomingTimelineStepExtent;
    final viewportTop = viewportBox.localToGlobal(Offset.zero).dy;
    final viewportBottom = viewportBox
        .localToGlobal(Offset(0, viewportBox.size.height))
        .dy;
    final panelTop = panelBox.localToGlobal(Offset.zero).dy;
    final visibleTop = viewportTop + 12;
    final visibleBottom = panelTop > visibleTop
        ? panelTop - 12
        : viewportBottom - 12;

    double scrollDelta;
    if (addStepTop < visibleTop) {
      scrollDelta = addStepTop - visibleTop;
    } else if (addStepBottom > visibleBottom) {
      scrollDelta = incomingPlaceholderBottom - visibleBottom;
    } else {
      return (
        scrolling: Future<void>.value(),
        flightTarget: currentFlightTarget,
        preScrolled: false,
      );
    }

    final position = _timelineScrollController.position;
    final targetOffset = (_timelineScrollController.offset + scrollDelta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );

    final actualScrollDelta = targetOffset - _timelineScrollController.offset;
    final projectedFlightTarget = currentFlightTarget == null
        ? null
        : currentFlightTarget - Offset(0, actualScrollDelta);
    final scrolling = _timelineScrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );

    return (
      scrolling: scrolling,
      flightTarget: projectedFlightTarget,
      preScrolled: actualScrollDelta.abs() > 0.5,
    );
  }

  Future<void> _scrollWithRevealingPlaceholder() async {
    await Future<void>.delayed(_timelineInsertionScrollDelay);
    if (!mounted || !_timelineScrollController.hasClients) return;

    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || !_timelineScrollController.hasClients) return;

    final addStepBox =
        _addStepTargetKey.currentContext?.findRenderObject() as RenderBox?;
    final viewportBox =
        _timelineViewportKey.currentContext?.findRenderObject() as RenderBox?;
    final panelBox =
        _libraryPanelKey.currentContext?.findRenderObject() as RenderBox?;

    if (addStepBox == null || viewportBox == null || panelBox == null) return;

    final addStepBottom = addStepBox
        .localToGlobal(Offset(0, addStepBox.size.height))
        .dy;
    final viewportTop = viewportBox.localToGlobal(Offset.zero).dy;
    final viewportBottom = viewportBox
        .localToGlobal(Offset(0, viewportBox.size.height))
        .dy;
    final panelTop = panelBox.localToGlobal(Offset.zero).dy;
    final visibleBottom = panelTop > viewportTop + 12
        ? panelTop - 12
        : viewportBottom - 12;

    if (addStepBottom <= visibleBottom) return;

    final position = _timelineScrollController.position;
    final targetOffset =
        (_timelineScrollController.offset + addStepBottom - visibleBottom)
            .clamp(position.minScrollExtent, position.maxScrollExtent);

    await _timelineScrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeInOutCubic,
    );
  }

  Future<void> _animateAndAdd(
    GlobalKey sourceKey,
    LibraryDisplayItem entry, {
    Size? flightSize,
  }) async {
    if (widget.libraryController.requiresDownload(entry)) {
      await _handlePrimaryAction(entry);
      return;
    }

    unawaited(HapticFeedback.lightImpact());

    final addStepFlight = _prepareAddStepFlight();
    final flightTarget = addStepFlight.flightTarget;
    final cachedPreviewPath = widget.libraryController.getCachedPreviewPath(
      entry.item.previewPath,
    );
    final flight = AnimationCardFlight.run(
      sourceKey: sourceKey,
      targetKey: flightTarget == null && !_isLibraryExpanded
          ? _timelineTargetKey
          : null,
      behindPanelKey: _isLibraryExpanded ? _libraryPanelKey : null,
      destination: flightTarget != null
          ? (_) => flightTarget
          : _isLibraryExpanded
          ? _expandedPanelDestination
          : null,
      finalScale: _isLibraryExpanded
          ? AnimationCardFlightTuning.expandedBuilderFinalScale
          : AnimationCardFlightTuning.collapsedBuilderFinalScale,
      flightSize: flightSize,
      fadeOut: false,
      flightChild: AnimationPreviewFrame(
        previewPath: cachedPreviewPath ?? entry.item.previewPath,
        resolvePreviewPath: widget.libraryController.getOrDownloadPreview,
        resolveCachedPreviewPath: widget.libraryController.getCachedPreviewPath,
      ),
      actionTiming: AnimationFlightActionTiming.afterFlight,
      action: () async {
        final itemCountBefore =
            widget.sequenceController.selectedAnimations.length;
        await _handlePrimaryAction(entry);

        if (widget.sequenceController.selectedAnimations.length >
            itemCountBefore) {
          if (!addStepFlight.preScrolled) {
            unawaited(_scrollWithRevealingPlaceholder());
          }
          await Future<void>.delayed(_previewPopHapticDelay);
          await HapticFeedback.heavyImpact();
        }
      },
    );

    await Future.wait<void>([addStepFlight.scrolling, flight]);
  }

  Offset _expandedPanelDestination(Rect sourceRect) {
    final panelBox = _libraryPanelKey.currentContext?.findRenderObject();

    if (panelBox is RenderBox) {
      final panelTop = panelBox.localToGlobal(Offset.zero).dy;
      return Offset(
        sourceRect.center.dx,
        panelTop + AnimationCardFlightTuning.behindDiveDepth,
      );
    }

    final fallbackY = sourceRect.top > 160 ? sourceRect.top - 120 : 40.0;
    return Offset(sourceRect.center.dx, fallbackY);
  }
}

class _SequenceHeader extends StatelessWidget {
  const _SequenceHeader({
    required this.sequenceNameController,
    required this.onNameChanged,
    required this.onBuildUnitySequence,
  });

  final TextEditingController sequenceNameController;
  final ValueChanged<String> onNameChanged;
  final Future<void> Function() onBuildUnitySequence;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        children: [
          const Text(
            'Sequence Builder',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.045),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.09)),
                  ),
                  child: TextField(
                    controller: sequenceNameController,
                    onChanged: onNameChanged,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Sequence name',
                      hintStyle: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                      suffixIcon: const Icon(Icons.edit_outlined, size: 17),
                      contentPadding: const EdgeInsets.fromLTRB(14, 12, 8, 10),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                  label: const Text('Save'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFC8A7FF),
                    side: BorderSide(
                      color: const Color(0xFFC8A7FF).withOpacity(0.48),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: onBuildUnitySequence,
              icon: const Icon(Icons.play_circle_outline),
              label: const Text(
                'Build Unity Sequence',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8F55FF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineSection extends StatefulWidget {
  const _TimelineSection({
    super.key,
    required this.items,
    required this.requiredNextPosition,
    required this.onRemoveAt,
    required this.onItemTap,
    required this.onAddStep,
    required this.addStepKey,
    required this.addStepFlightTargetKey,
    required this.resolvePreviewPath,
    required this.resolveCachedPreviewPath,
  });

  final List<AnimationLibraryItem> items;
  final String requiredNextPosition;
  final void Function(int index) onRemoveAt;
  final ValueChanged<AnimationLibraryItem> onItemTap;
  final VoidCallback onAddStep;
  final Key addStepKey;
  final Key addStepFlightTargetKey;
  final Future<String?> Function(String? previewPath) resolvePreviewPath;
  final String? Function(String? previewPath) resolveCachedPreviewPath;

  @override
  State<_TimelineSection> createState() => _TimelineSectionState();
}

class _TimelineSectionState extends State<_TimelineSection>
    with SingleTickerProviderStateMixin {
  static const _insertionDuration = Duration(milliseconds: 720);
  static const double _baseRailHeight = 68;
  static const double _stepRailHeight = 136;

  late final AnimationController _insertionController;
  int? _insertingIndex;

  @override
  void initState() {
    super.initState();
    _insertionController = AnimationController(
      vsync: this,
      duration: _insertionDuration,
      value: 1,
    )..addStatusListener(_handleInsertionStatus);
  }

  @override
  void didUpdateWidget(covariant _TimelineSection oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.items.length == oldWidget.items.length + 1) {
      _insertingIndex = widget.items.length - 1;
      _insertionController.forward(from: 0);
    } else if (widget.items.length < oldWidget.items.length) {
      _insertingIndex = null;
      _insertionController.value = 1;
    }
  }

  void _handleInsertionStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || _insertingIndex == null) return;

    setState(() {
      _insertingIndex = null;
    });
  }

  @override
  void dispose() {
    _insertionController
      ..removeStatusListener(_handleInsertionStatus)
      ..dispose();
    super.dispose();
  }

  double _interval(double value, double start, double end) {
    return ((value - start) / (end - start)).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _insertionController,
      builder: (context, _) {
        final items = widget.items;
        final insertionProgress = _insertionController.value;
        final hasInsertion = _insertingIndex != null;
        final railProgress = hasInsertion
            ? Curves.easeInOutCubic.transform(
                _interval(insertionProgress, 0.28, 0.72),
              )
            : 1.0;
        final completedSteps = items.length - (hasInsertion ? 1 : 0);
        final visibleRailSteps = hasInsertion
            ? completedSteps + railProgress
            : items.length.toDouble();
        final railHeight = _baseRailHeight + _stepRailHeight * visibleRailSteps;
        final positionReveal = hasInsertion
            ? Curves.easeOut.transform(_interval(insertionProgress, 0.34, 0.64))
            : 1.0;
        final placeholderReveal = hasInsertion
            ? Curves.easeOutCubic.transform(
                _interval(insertionProgress, 0.45, 0.78),
              )
            : 1.0;
        final firstPosition = items.isEmpty
            ? widget.requiredNextPosition
            : items.first.startPosition;

        return Stack(
          children: [
            Positioned(
              left: 13.5,
              top: 14,
              child: Container(
                width: 1,
                height: railHeight,
                color: Colors.white.withOpacity(0.14),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TimelinePositionNode(value: firstPosition),
                const SizedBox(height: 6),
                for (var index = 0; index < items.length; index++) ...[
                  _TimelineAnimationTile(
                    index: index,
                    item: items[index],
                    insertionProgress: index == _insertingIndex
                        ? insertionProgress
                        : 1,
                    onRemove: () => widget.onRemoveAt(index),
                    onTap: () => widget.onItemTap(items[index]),
                    resolvePreviewPath: widget.resolvePreviewPath,
                    resolveCachedPreviewPath: widget.resolveCachedPreviewPath,
                  ),
                  const SizedBox(height: 6),
                  _AnimatedTimelinePositionNode(
                    value: items[index].endPosition,
                    progress: index == _insertingIndex ? positionReveal : 1,
                  ),
                  const SizedBox(height: 6),
                ],
                _AddTimelineStep(
                  key: widget.addStepKey,
                  flightTargetKey: widget.addStepFlightTargetKey,
                  index: items.length,
                  requiredPosition: widget.requiredNextPosition,
                  isFirstStep: items.isEmpty,
                  revealProgress: placeholderReveal,
                  onTap: widget.onAddStep,
                ),
              ],
            ),
          ],
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
