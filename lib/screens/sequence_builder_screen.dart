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

const _timelinePlaceholderRevealDelay = Duration(milliseconds: 324);
const double _timelinePostRevealBottomClearance = 32;
const double _timelinePostRevealOverflowThreshold = 4;

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

class _TimelineVisualStep {
  const _TimelineVisualStep({
    required this.id,
    required this.item,
    required this.animateOnMount,
    required this.animatePositionOnMount,
  });

  final int id;
  final AnimationLibraryItem item;
  final bool animateOnMount;
  final bool animatePositionOnMount;
}

class _TimelinePlaceholderHandle {
  _TimelinePlaceholderHandle({required this.id, required this.animateOnMount})
    : containerKey = GlobalKey(debugLabel: 'timeline-placeholder-$id'),
      flightTargetKey = GlobalKey(debugLabel: 'timeline-flight-target-$id');

  final int id;
  final bool animateOnMount;
  final GlobalKey containerKey;
  final GlobalKey flightTargetKey;
}

class _PendingTimelineReservation {
  _PendingTimelineReservation({required this.handle, required this.item});

  final _TimelinePlaceholderHandle handle;
  final AnimationLibraryItem item;
  bool hasArrived = false;
  bool isCancelled = false;
}

class _SequenceBuilderScreenState extends State<SequenceBuilderScreen> {
  static const _previewPopHapticDelay = Duration(milliseconds: 90);
  static const int _maxEditHistoryLength = 10;

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
  final GlobalKey _libraryPanelKey = GlobalKey(
    debugLabel: 'sequence-library-panel',
  );
  List<_PendingTimelineReservation>? _pendingTimelineReservationsState;
  List<_TimelineVisualStep>? _visualTimelineStepsState;
  _TimelinePlaceholderHandle? _openPlaceholderHandleState;
  _TimelinePlaceholderHandle? _lastClaimedPlaceholderHandle;
  int? _nextTimelineSlotIdState;
  int? _timelineScrollRequestVersionState;
  int _activeVisualAddFlights = 0;
  final List<List<AnimationLibraryItem>> _undoHistory = [];
  final List<List<AnimationLibraryItem>> _redoHistory = [];
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
    _nextTimelineSlotIdState = 0;
    _visualTimelineSteps = widget.sequenceController.selectedAnimations
        .map(
          (item) => _TimelineVisualStep(
            id: _takeTimelineSlotId(),
            item: item,
            animateOnMount: false,
            animatePositionOnMount: false,
          ),
        )
        .toList();
    _openPlaceholderHandle = _newPlaceholderHandle(animateOnMount: false);
    _lastClaimedPlaceholderHandle = null;

    widget.sequenceController.addListener(_onControllerChanged);
    widget.libraryController.addListener(_onControllerChanged);
  }

  List<_PendingTimelineReservation> get _pendingTimelineReservations =>
      _pendingTimelineReservationsState ??= [];

  List<_TimelineVisualStep> get _visualTimelineSteps =>
      _visualTimelineStepsState ??= widget.sequenceController.selectedAnimations
          .map(
            (item) => _TimelineVisualStep(
              id: _takeTimelineSlotId(),
              item: item,
              animateOnMount: false,
              animatePositionOnMount: false,
            ),
          )
          .toList();

  set _visualTimelineSteps(List<_TimelineVisualStep> value) {
    _visualTimelineStepsState = value;
  }

  _TimelinePlaceholderHandle get _openPlaceholderHandle =>
      _openPlaceholderHandleState ??= _newPlaceholderHandle(
        animateOnMount: false,
      );

  set _openPlaceholderHandle(_TimelinePlaceholderHandle value) {
    _openPlaceholderHandleState = value;
  }

  int _takeTimelineSlotId() {
    final id = _nextTimelineSlotIdState ?? 0;
    _nextTimelineSlotIdState = id + 1;
    return id;
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

    if (_activeVisualAddFlights == 0 && _pendingTimelineReservations.isEmpty) {
      _syncVisualTimelineWithController();
    }

    if (mounted) {
      setState(() {});
    }
  }

  _TimelinePlaceholderHandle _newPlaceholderHandle({
    required bool animateOnMount,
  }) {
    return _TimelinePlaceholderHandle(
      id: _takeTimelineSlotId(),
      animateOnMount: animateOnMount,
    );
  }

  void _syncVisualTimelineWithController() {
    final logicalAnimations = widget.sequenceController.selectedAnimations;
    final alreadySynchronized =
        logicalAnimations.length == _visualTimelineSteps.length &&
        List.generate(
          logicalAnimations.length,
          (index) => identical(
            logicalAnimations[index],
            _visualTimelineSteps[index].item,
          ),
        ).every((matches) => matches);

    if (alreadySynchronized) return;

    _visualTimelineSteps = logicalAnimations
        .map(
          (item) => _TimelineVisualStep(
            id: _takeTimelineSlotId(),
            item: item,
            animateOnMount: false,
            animatePositionOnMount: false,
          ),
        )
        .toList();
    _openPlaceholderHandle = _newPlaceholderHandle(animateOnMount: false);
    _lastClaimedPlaceholderHandle = null;
  }

  void _recordTimelineEdit(List<AnimationLibraryItem> previousState) {
    _undoHistory.add(List<AnimationLibraryItem>.from(previousState));
    if (_undoHistory.length > _maxEditHistoryLength) {
      _undoHistory.removeAt(0);
    }
    _redoHistory.clear();
  }

  void _cancelPendingTimelineReservations() {
    for (final reservation in _pendingTimelineReservations) {
      reservation.isCancelled = true;
    }
    _pendingTimelineReservations.clear();
  }

  void _restoreTimelineSnapshot(List<AnimationLibraryItem> snapshot) {
    setState(() {
      _cancelPendingTimelineReservations();
      _visualTimelineSteps = snapshot
          .map(
            (item) => _TimelineVisualStep(
              id: _takeTimelineSlotId(),
              item: item,
              animateOnMount: false,
              animatePositionOnMount: false,
            ),
          )
          .toList();
      _openPlaceholderHandle = _newPlaceholderHandle(animateOnMount: false);
      _lastClaimedPlaceholderHandle = null;
    });
    widget.sequenceController.replaceAnimations(snapshot);
  }

  void _undoTimelineEdit() {
    if (_undoHistory.isEmpty ||
        _activeVisualAddFlights > 0 ||
        _pendingTimelineReservations.isNotEmpty) {
      return;
    }

    final current = List<AnimationLibraryItem>.from(
      widget.sequenceController.selectedAnimations,
    );
    final previous = _undoHistory.removeLast();
    _redoHistory.add(current);
    _restoreTimelineSnapshot(previous);
    unawaited(HapticFeedback.selectionClick());
  }

  void _redoTimelineEdit() {
    if (_redoHistory.isEmpty ||
        _activeVisualAddFlights > 0 ||
        _pendingTimelineReservations.isNotEmpty) {
      return;
    }

    final current = List<AnimationLibraryItem>.from(
      widget.sequenceController.selectedAnimations,
    );
    final next = _redoHistory.removeLast();
    _undoHistory.add(current);
    if (_undoHistory.length > _maxEditHistoryLength) {
      _undoHistory.removeAt(0);
    }
    _restoreTimelineSnapshot(next);
    unawaited(HapticFeedback.mediumImpact());
  }

  Future<bool> _confirmDeletion({
    required String title,
    required String message,
    required String confirmLabel,
    required IconData icon,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.68),
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 340),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xFF26232C),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.34),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF718B).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(icon, color: const Color(0xFFFF8CA0), size: 21),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                message,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.68),
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white.withValues(alpha: 0.72),
                        minimumSize: const Size(0, 44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFF718B),
                        foregroundColor: const Color(0xFF26151B),
                        minimumSize: const Size(0, 44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(confirmLabel),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _removeTimelineAnimationAt(int index) async {
    if (index < 0 || index >= _visualTimelineSteps.length) return;

    final lastStep = _visualTimelineSteps.length;
    final removedCount = lastStep - index;
    if (removedCount > 1) {
      final confirmed = await _confirmDeletion(
        title: 'Delete steps ${index + 1}–$lastStep?',
        message:
            'Following steps must also be removed so the poses still match.',
        confirmLabel: 'Delete',
        icon: Icons.delete_outline_rounded,
      );
      if (!confirmed || !mounted) return;
    }

    setState(() {
      _recordTimelineEdit(widget.sequenceController.selectedAnimations);
      _cancelPendingTimelineReservations();
      _visualTimelineSteps.removeRange(index, _visualTimelineSteps.length);
      _openPlaceholderHandle = _newPlaceholderHandle(animateOnMount: false);
      _lastClaimedPlaceholderHandle = null;
    });
    widget.sequenceController.removeAnimationsFrom(index);
    unawaited(HapticFeedback.mediumImpact());
  }

  Future<void> _clearAllTimelineAnimations() async {
    final stepCount = widget.sequenceController.selectedAnimations.length;
    if (stepCount == 0) return;

    final confirmed = await _confirmDeletion(
      title: 'Reset sequence?',
      message:
          'All $stepCount animation ${stepCount == 1 ? 'step' : 'steps'} will be removed.',
      confirmLabel: 'Reset',
      icon: Icons.refresh_rounded,
    );
    if (!confirmed || !mounted) return;

    setState(() {
      _recordTimelineEdit(widget.sequenceController.selectedAnimations);
      _visualTimelineSteps.clear();
      _cancelPendingTimelineReservations();
      _openPlaceholderHandle = _newPlaceholderHandle(animateOnMount: false);
      _lastClaimedPlaceholderHandle = null;
    });
    widget.sequenceController.clearAnimations();
    unawaited(HapticFeedback.mediumImpact());
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
    final previousState = List<AnimationLibraryItem>.from(
      widget.sequenceController.selectedAnimations,
    );
    try {
      await widget.libraryController.performPrimaryAction(entry);

      final currentState = widget.sequenceController.selectedAnimations;
      final sequenceChanged =
          previousState.length != currentState.length ||
          List<bool>.generate(
            previousState.length,
            (index) => identical(previousState[index], currentState[index]),
          ).any((matches) => !matches);
      if (sequenceChanged && mounted) {
        setState(() {
          _recordTimelineEdit(previousState);
        });
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add ${entry.item.title}: $e')),
      );
    }
  }

  List<LibraryDisplayItem> get _libraryItems {
    return widget.libraryController.recommendedNextItems;
  }

  String _visibleRequiredNextPosition(
    List<AnimationLibraryItem> visibleAnimations,
  ) {
    final requiredStart = visibleAnimations.isEmpty
        ? null
        : visibleAnimations.last.endPosition;

    if (requiredStart == null || requiredStart.trim().isEmpty) {
      return 'Any';
    }

    return requiredStart.trim();
  }

  @override
  Widget build(BuildContext context) {
    final sequence = widget.sequenceController;
    final visibleAnimations = _visualTimelineSteps
        .map((step) => step.item)
        .toList(growable: false);
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
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  const Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'Timeline',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  _TimelineHistoryControls(
                                    canUndo:
                                        _undoHistory.isNotEmpty &&
                                        _activeVisualAddFlights == 0 &&
                                        _pendingTimelineReservations.isEmpty,
                                    canRedo:
                                        _redoHistory.isNotEmpty &&
                                        _activeVisualAddFlights == 0 &&
                                        _pendingTimelineReservations.isEmpty,
                                    onUndo: _undoTimelineEdit,
                                    onRedo: _redoTimelineEdit,
                                  ),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 160,
                                      ),
                                      switchInCurve: Curves.easeOutCubic,
                                      switchOutCurve: Curves.easeInCubic,
                                      transitionBuilder: (child, animation) {
                                        return FadeTransition(
                                          opacity: animation,
                                          child: ScaleTransition(
                                            scale: Tween<double>(
                                              begin: 0.96,
                                              end: 1,
                                            ).animate(animation),
                                            child: child,
                                          ),
                                        );
                                      },
                                      child: visibleAnimations.isEmpty
                                          ? const SizedBox(
                                              key: ValueKey(
                                                'clear-all-placeholder',
                                              ),
                                            )
                                          : OutlinedButton.icon(
                                              key: const ValueKey(
                                                'clear-all-button',
                                              ),
                                              onPressed:
                                                  _clearAllTimelineAnimations,
                                              icon: const Icon(
                                                Icons.refresh_rounded,
                                                size: 16,
                                              ),
                                              label: const Text('Clear All'),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: const Color(
                                                  0xFFC8A7FF,
                                                ),
                                                backgroundColor: const Color(
                                                  0xFF8F55FF,
                                                ).withValues(alpha: 0.07),
                                                side: BorderSide(
                                                  color: const Color(
                                                    0xFFC8A7FF,
                                                  ).withValues(alpha: 0.26),
                                                ),
                                                minimumSize: const Size(0, 34),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 11,
                                                    ),
                                                shape: const StadiumBorder(),
                                                tapTargetSize:
                                                    MaterialTapTargetSize
                                                        .shrinkWrap,
                                              ),
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            _TimelineSection(
                              key: _timelineTargetKey,
                              steps: _visualTimelineSteps,
                              pendingReservations: _pendingTimelineReservations,
                              openPlaceholderHandle: _openPlaceholderHandle,
                              requiredNextPosition:
                                  _visibleRequiredNextPosition(
                                    visibleAnimations,
                                  ),
                              onRemoveAt: _removeTimelineAnimationAt,
                              onItemTap: _showTimelineAnimationInfo,
                              onAddStep: _expandLibrary,
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
                panelState: _libraryPanelState,
                panelSurfaceKey: _libraryPanelKey,
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
      if (_libraryPanelState == SequenceBuilderLibraryPanelState.expanded &&
          state != SequenceBuilderLibraryPanelState.expanded) {
        _syncVisualTimelineWithController();
      }
      _libraryPanelState = state;
    });
  }

  void _expandLibrary() {
    if (_isLibraryExpanded) return;

    _setLibraryPanelState(SequenceBuilderLibraryPanelState.expanded);
  }

  Offset? _projectLandingTarget({
    required _TimelinePlaceholderHandle baseHandle,
    required double slotOffset,
  }) {
    final flightTargetBox =
        baseHandle.flightTargetKey.currentContext?.findRenderObject()
            as RenderBox?;
    return flightTargetBox
        ?.localToGlobal(
          Offset(
            flightTargetBox.size.width / 2,
            flightTargetBox.size.height / 2,
          ),
        )
        .translate(0, slotOffset);
  }

  double _landingOverflowSteps({
    required _TimelinePlaceholderHandle baseHandle,
    required double slotOffset,
  }) {
    final addStepBox =
        baseHandle.containerKey.currentContext?.findRenderObject()
            as RenderBox?;
    final viewportBox =
        _timelineViewportKey.currentContext?.findRenderObject() as RenderBox?;
    final panelBox =
        _libraryPanelKey.currentContext?.findRenderObject() as RenderBox?;

    if (addStepBox == null || viewportBox == null || panelBox == null) {
      return slotOffset / _incomingTimelineStepExtent;
    }

    final addStepBottom =
        addStepBox.localToGlobal(Offset(0, addStepBox.size.height)).dy +
        slotOffset;
    final viewportTop = viewportBox.localToGlobal(Offset.zero).dy;
    final viewportBottom = viewportBox
        .localToGlobal(Offset(0, viewportBox.size.height))
        .dy;
    final panelTop = panelBox.localToGlobal(Offset.zero).dy;
    final visibleBottom = panelTop > viewportTop + 12
        ? panelTop - 12
        : viewportBottom - 12;
    final overflow = math.max(0.0, addStepBottom - visibleBottom);

    return overflow / _incomingTimelineStepExtent;
  }

  void _requestTimelineScroll(
    _TimelinePlaceholderHandle handle, {
    Duration delay = Duration.zero,
    bool reserveNextSlot = false,
    bool isPostRevealScroll = false,
  }) {
    final requestVersion = (_timelineScrollRequestVersionState ?? 0) + 1;
    _timelineScrollRequestVersionState = requestVersion;
    unawaited(
      _scrollTimelineToPlaceholder(
        handle,
        requestVersion: requestVersion,
        delay: delay,
        reserveNextSlot: reserveNextSlot,
        isPostRevealScroll: isPostRevealScroll,
      ),
    );
  }

  Future<void> _scrollTimelineToPlaceholder(
    _TimelinePlaceholderHandle handle, {
    required int requestVersion,
    required Duration delay,
    required bool reserveNextSlot,
    required bool isPostRevealScroll,
  }) async {
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    if (!mounted ||
        requestVersion != _timelineScrollRequestVersionState ||
        !_timelineScrollController.hasClients) {
      return;
    }

    await WidgetsBinding.instance.endOfFrame;
    if (!mounted ||
        requestVersion != _timelineScrollRequestVersionState ||
        !_timelineScrollController.hasClients) {
      return;
    }

    final addStepBox =
        handle.containerKey.currentContext?.findRenderObject() as RenderBox?;
    final viewportBox =
        _timelineViewportKey.currentContext?.findRenderObject() as RenderBox?;
    final panelBox =
        _libraryPanelKey.currentContext?.findRenderObject() as RenderBox?;

    if (addStepBox == null || viewportBox == null || panelBox == null) return;

    final addStepTop = addStepBox.localToGlobal(Offset.zero).dy;
    final addStepBottom = addStepBox
        .localToGlobal(Offset(0, addStepBox.size.height))
        .dy;
    final requiredBottom =
        addStepBottom + (reserveNextSlot ? _incomingTimelineStepExtent : 0);
    final viewportTop = viewportBox.localToGlobal(Offset.zero).dy;
    final viewportBottom = viewportBox
        .localToGlobal(Offset(0, viewportBox.size.height))
        .dy;
    final panelTop = panelBox.localToGlobal(Offset.zero).dy;
    final visibleTop = viewportTop + 12;
    final occlusionBoundary = panelTop > visibleTop ? panelTop : viewportBottom;
    if (isPostRevealScroll &&
        requiredBottom <=
            occlusionBoundary + _timelinePostRevealOverflowThreshold) {
      return;
    }
    final bottomClearance = isPostRevealScroll
        ? _timelinePostRevealBottomClearance
        : 12.0;
    final visibleBottom = panelTop > visibleTop
        ? panelTop - bottomClearance
        : viewportBottom - bottomClearance;

    var scrollDelta = 0.0;
    if (addStepTop < visibleTop) {
      scrollDelta = addStepTop - visibleTop;
    } else if (requiredBottom > visibleBottom) {
      scrollDelta = requiredBottom - visibleBottom;
    }
    if (scrollDelta.abs() < 0.5) return;

    final position = _timelineScrollController.position;
    final targetOffset = (_timelineScrollController.offset + scrollDelta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );

    final distance = (targetOffset - _timelineScrollController.offset).abs();
    final duration = Duration(
      milliseconds: isPostRevealScroll
          ? (150 + distance * 0.22).clamp(180, 260).round()
          : (260 + distance * 0.38).clamp(300, 420).round(),
    );

    try {
      await _timelineScrollController.animateTo(
        targetOffset,
        duration: duration,
        curve: isPostRevealScroll
            ? Curves.easeInOutCubic
            : Curves.easeInOutSine,
      );
    } catch (_) {
      // A newer landing target intentionally interrupts the current scroll.
    }
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

    if (_isLibraryExpanded) {
      await _animateAndAddFromExpandedLibrary(
        sourceKey,
        entry,
        flightSize: flightSize,
      );
      return;
    }

    final landingHandle = _openPlaceholderHandle;
    final openPlaceholderIsRendered =
        landingHandle.containerKey.currentContext != null;
    final needsProjectedLandingSlot =
        _pendingTimelineReservations.isNotEmpty ||
        (!openPlaceholderIsRendered && _lastClaimedPlaceholderHandle != null);
    final baseHandle = _pendingTimelineReservations.isNotEmpty
        ? _pendingTimelineReservations.last.handle
        : openPlaceholderIsRendered
        ? landingHandle
        : _lastClaimedPlaceholderHandle ?? landingHandle;
    final slotOffset = needsProjectedLandingSlot
        ? _incomingTimelineStepExtent
        : 0.0;
    final reservation = _PendingTimelineReservation(
      handle: landingHandle,
      item: entry.item,
    );
    final flightTarget = _projectLandingTarget(
      baseHandle: baseHandle,
      slotOffset: slotOffset,
    );
    final landingOverflowSteps = _landingOverflowSteps(
      baseHandle: baseHandle,
      slotOffset: slotOffset,
    );
    final landingNeedsPreScroll = landingOverflowSteps > 0;
    final usesLongScrollFlight =
        landingOverflowSteps >=
        AnimationCardFlightTuning.sequenceBuilderLongScrollStepThreshold;
    var animationWasAdded = false;
    _activeVisualAddFlights++;
    final cachedPreviewPath = widget.libraryController.getCachedPreviewPath(
      entry.item.previewPath,
    );
    try {
      final flight = AnimationCardFlight.run(
        sourceKey: sourceKey,
        targetKey: landingHandle.flightTargetKey,
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
        preventDownwardFlight: !_isLibraryExpanded,
        duration: usesLongScrollFlight
            ? AnimationCardFlightTuning.sequenceBuilderLongScrollDuration
            : AnimationCardFlightTuning.sequenceBuilderDuration,
        arcLift: usesLongScrollFlight
            ? AnimationCardFlightTuning.sequenceBuilderLongScrollArcLift
            : AnimationCardFlightTuning.sequenceBuilderArcLift,
        scaleStart: usesLongScrollFlight
            ? AnimationCardFlightTuning.sequenceBuilderLongScrollScaleStart
            : AnimationCardFlightTuning.sequenceBuilderScaleStart,
        flightChild: AnimationPreviewFrame(
          previewPath: cachedPreviewPath ?? entry.item.previewPath,
          resolvePreviewPath: widget.libraryController.getOrDownloadPreview,
          resolveCachedPreviewPath:
              widget.libraryController.getCachedPreviewPath,
        ),
        actionTiming: AnimationFlightActionTiming.alongsideFlight,
        action: () async {
          final itemCountBefore =
              widget.sequenceController.selectedAnimations.length;
          await _handlePrimaryAction(entry);
          animationWasAdded =
              widget.sequenceController.selectedAnimations.length >
              itemCountBefore;

          if (animationWasAdded && mounted) {
            setState(() {
              _pendingTimelineReservations.add(reservation);
              _lastClaimedPlaceholderHandle = reservation.handle;
              _openPlaceholderHandle = _newPlaceholderHandle(
                animateOnMount: true,
              );
            });
            if (landingNeedsPreScroll) {
              _requestTimelineScroll(landingHandle, reserveNextSlot: true);
            }
          }
        },
      );

      await flight;

      if (animationWasAdded && mounted && !reservation.isCancelled) {
        late final _TimelinePlaceholderHandle scrollTarget;
        late final bool revealsFinalPlaceholder;
        setState(() {
          reservation.hasArrived = true;

          while (_pendingTimelineReservations.isNotEmpty &&
              _pendingTimelineReservations.first.hasArrived) {
            final arrivedReservation = _pendingTimelineReservations.removeAt(0);
            _visualTimelineSteps.add(
              _TimelineVisualStep(
                id: arrivedReservation.handle.id,
                item: arrivedReservation.item,
                animateOnMount: true,
                animatePositionOnMount: _pendingTimelineReservations.isEmpty,
              ),
            );
          }

          scrollTarget = _pendingTimelineReservations.isEmpty
              ? _openPlaceholderHandle
              : _pendingTimelineReservations.last.handle;
          revealsFinalPlaceholder = _pendingTimelineReservations.isEmpty;
        });

        if (!landingNeedsPreScroll && revealsFinalPlaceholder) {
          _requestTimelineScroll(
            scrollTarget,
            delay: _timelinePlaceholderRevealDelay,
            isPostRevealScroll: true,
          );
        }
        await Future<void>.delayed(_previewPopHapticDelay);
        await HapticFeedback.heavyImpact();
      }
    } finally {
      _activeVisualAddFlights--;
      if (mounted) setState(() {});
    }
  }

  Future<void> _animateAndAddFromExpandedLibrary(
    GlobalKey sourceKey,
    LibraryDisplayItem entry, {
    Size? flightSize,
  }) async {
    _activeVisualAddFlights++;
    final cachedPreviewPath = widget.libraryController.getCachedPreviewPath(
      entry.item.previewPath,
    );

    try {
      await AnimationCardFlight.run(
        sourceKey: sourceKey,
        behindPanelKey: _libraryPanelKey,
        destination: _expandedPanelDestination,
        finalScale: AnimationCardFlightTuning.expandedBuilderFinalScale,
        flightSize: flightSize,
        fadeOut: false,
        flightChild: AnimationPreviewFrame(
          previewPath: cachedPreviewPath ?? entry.item.previewPath,
          resolvePreviewPath: widget.libraryController.getOrDownloadPreview,
          resolveCachedPreviewPath:
              widget.libraryController.getCachedPreviewPath,
        ),
        actionTiming: AnimationFlightActionTiming.alongsideFlight,
        action: () => _handlePrimaryAction(entry),
      );
    } finally {
      _activeVisualAddFlights--;
      if (mounted) setState(() {});
    }
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

class _TimelineHistoryControls extends StatelessWidget {
  const _TimelineHistoryControls({
    required this.canUndo,
    required this.canRedo,
    required this.onUndo,
    required this.onRedo,
  });

  final bool canUndo;
  final bool canRedo;
  final VoidCallback onUndo;
  final VoidCallback onRedo;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _HistoryIconButton(
            tooltip: 'Undo',
            icon: Icons.undo_rounded,
            enabled: canUndo,
            onPressed: onUndo,
          ),
          Container(
            width: 1,
            height: 16,
            color: Colors.white.withValues(alpha: 0.07),
          ),
          _HistoryIconButton(
            tooltip: 'Redo',
            icon: Icons.redo_rounded,
            enabled: canRedo,
            onPressed: onRedo,
          ),
        ],
      ),
    );
  }
}

class _HistoryIconButton extends StatelessWidget {
  const _HistoryIconButton({
    required this.tooltip,
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: enabled ? onPressed : null,
      icon: Icon(icon, size: 17),
      color: const Color(0xFFC8A7FF),
      disabledColor: Colors.white.withValues(alpha: 0.18),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 34, height: 32),
      splashRadius: 17,
    );
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
  static const double _baseRailHeight = 68;
  static const double _stepRailHeight = 136;
  static const _arrivalRailDelay = Duration(milliseconds: 202);

  double? _railHeight;
  double? _requestedRailHeight;
  int? _lastPendingReservationCount;
  Timer? _railDelayTimer;

  double _targetRailHeight(_TimelineSection timeline) {
    final railSteps =
        timeline.steps.length +
        math.max(0, timeline.pendingReservations.length - 1);
    return _baseRailHeight + _stepRailHeight * railSteps;
  }

  @override
  void initState() {
    super.initState();
    _railHeight = _targetRailHeight(widget);
    _requestedRailHeight = _railHeight;
    _lastPendingReservationCount = widget.pendingReservations.length;
  }

  @override
  void didUpdateWidget(covariant _TimelineSection oldWidget) {
    super.didUpdateWidget(oldWidget);

    final newTarget = _targetRailHeight(widget);
    final oldTarget = _requestedRailHeight ?? _railHeight ?? newTarget;
    final newPendingCount = widget.pendingReservations.length;
    final oldPendingCount = _lastPendingReservationCount ?? newPendingCount;

    _requestedRailHeight = newTarget;
    _lastPendingReservationCount = newPendingCount;
    if (newTarget == oldTarget) return;

    _railDelayTimer?.cancel();
    if (newTarget < oldTarget || newPendingCount > oldPendingCount) {
      _railHeight = newTarget;
      return;
    }

    _railDelayTimer = Timer(_arrivalRailDelay, () {
      if (!mounted) return;
      setState(() {
        _railHeight = newTarget;
      });
    });
  }

  @override
  void dispose() {
    _railDelayTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pendingReservations = widget.pendingReservations;
    _requestedRailHeight ??= _targetRailHeight(widget);
    _lastPendingReservationCount ??= pendingReservations.length;
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
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeInOutCubic,
            width: 1,
            height: _railHeight ??= _targetRailHeight(widget),
            color: Colors.white.withOpacity(0.14),
          ),
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
