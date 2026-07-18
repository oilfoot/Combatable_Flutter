import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/library_controller.dart';
import '../controllers/sequence_controller.dart';
import '../controllers/sequence_history_controller.dart';
import '../models/animation_library_item.dart';
import '../theme/app_theme.dart';
import '../theme/sequence_builder_layout.dart';
import '../widgets/animation/animation_info_sheet.dart';
import '../widgets/animation/animation_card_flight.dart';
import '../widgets/animation/animation_preview_frame.dart';
import '../widgets/sequence_builder_library.dart';

part '../widgets/sequence_builder/sequence_timeline.dart';
part '../widgets/sequence_builder/sequence_timeline_transitions.dart';
part '../widgets/sequence_builder/sequence_builder_chrome.dart';

const _timelinePlaceholderRevealDelay = Duration(milliseconds: 324);

enum _QueuedHistoryAction { undo, redo }

class SequenceBuilderScreen extends StatefulWidget {
  const SequenceBuilderScreen({
    super.key,
    required this.sequenceController,
    required this.sequenceHistoryController,
    required this.libraryController,
    required this.onBuildUnitySequence,
  });

  final SequenceController sequenceController;
  final SequenceHistoryController sequenceHistoryController;
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
    this.removalCompletion,
  });

  final int id;
  final AnimationLibraryItem item;
  final bool animateOnMount;
  final bool animatePositionOnMount;
  final Completer<void>? removalCompletion;
}

class _TimelinePlaceholderHandle {
  _TimelinePlaceholderHandle({
    required this.id,
    required this.animateOnMount,
    this.revealImmediately = false,
  }) : containerKey = GlobalKey(debugLabel: 'timeline-placeholder-$id'),
       flightTargetKey = GlobalKey(debugLabel: 'timeline-flight-target-$id');

  final int id;
  final bool animateOnMount;
  final bool revealImmediately;
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

class _TimelineInsertionTransition {
  _TimelineInsertionTransition({
    required this.reservation,
    required this.flightTarget,
    required this.landingNeedsPreScroll,
    required this.usesLongScrollFlight,
    required this.arrival,
    required this.playsArrivalHaptic,
    required this.managesOwnScroll,
    required this.consumesBulkReservedExtent,
    required this.revealsNextPlaceholderImmediately,
  });

  final _PendingTimelineReservation reservation;
  final Offset? flightTarget;
  final bool landingNeedsPreScroll;
  final bool usesLongScrollFlight;
  final Completer<void> arrival;
  final bool playsArrivalHaptic;
  final bool managesOwnScroll;
  final bool consumesBulkReservedExtent;
  final bool revealsNextPlaceholderImmediately;
}

class _TimelineRemovalTransition {
  _TimelineRemovalTransition({
    required this.firstRemovedIndex,
    required this.replacementPlaceholderHandle,
  });

  final int firstRemovedIndex;
  final _TimelinePlaceholderHandle replacementPlaceholderHandle;
  final Completer<void> placeholderCompletion = Completer<void>();
  bool isRemovingContent = true;
}

class _SequenceBuilderScreenState extends State<SequenceBuilderScreen> {
  static const _previewPopHapticDelay = Duration(milliseconds: 90);

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
  int _nextTransitionId = 0;
  int _activeVisualAddFlights = 0;
  int _activeVisualRemovals = 0;
  int _activeBulkRestores = 0;
  double _bulkRestoreReservedExtent = 0;
  double _controlsHeaderTop = 0;
  bool _isControlsHeaderFloating = false;
  final List<_QueuedHistoryAction> _queuedHistoryActions = [];
  final Map<String, _TimelineInsertionTransition> _flightTransitions = {};
  _TimelineRemovalTransition? _timelineRemovalTransition;
  StreamSubscription<SequenceMutation>? _sequenceMutationSubscription;
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
    widget.sequenceHistoryController.addListener(_onHistoryChanged);
    widget.libraryController.addListener(_onControllerChanged);
    _sequenceMutationSubscription = widget.sequenceHistoryController.mutations
        .listen(_onSequenceMutation);
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
    widget.sequenceHistoryController.removeListener(_onHistoryChanged);
    widget.libraryController.removeListener(_onControllerChanged);
    _sequenceMutationSubscription?.cancel();
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

  void _onHistoryChanged() {
    if (mounted) setState(() {});
  }

  bool _handleTimelineScrollNotification(ScrollNotification notification) {
    if (notification is! ScrollUpdateNotification) {
      return false;
    }

    final pixels = math.max(0.0, notification.metrics.pixels);
    final scrollDelta = notification.scrollDelta ?? 0;
    var nextTop = _controlsHeaderTop;
    var nextFloating = _isControlsHeaderFloating;

    if (pixels <= 1) {
      nextTop = 0;
      nextFloating = false;
    } else if (!nextFloating && pixels < SequenceBuilderLayout.headerExtent) {
      nextTop = -pixels;
    } else {
      final directUpwardDrag =
          notification.dragDetails != null && scrollDelta < 0;
      if (!nextFloating && directUpwardDrag) {
        nextFloating = true;
      }

      if (nextFloating) {
        nextTop = (nextTop - scrollDelta).clamp(
          -SequenceBuilderLayout.headerExtent,
          0.0,
        );
        if (nextTop <= -SequenceBuilderLayout.headerExtent && scrollDelta > 0) {
          nextFloating = false;
        }
      } else {
        nextTop = -SequenceBuilderLayout.headerExtent;
      }
    }

    if (nextTop != _controlsHeaderTop ||
        nextFloating != _isControlsHeaderFloating) {
      setState(() {
        _controlsHeaderTop = nextTop;
        _isControlsHeaderFloating = nextFloating;
      });
    }

    return false;
  }

  void _updateTimelineState(VoidCallback update) {
    if (mounted) setState(update);
  }

  void _onSequenceMutation(SequenceMutation mutation) {
    if (!mounted) return;

    if (_isLibraryExpanded) {
      return;
    }

    if (mutation.isInsertion) {
      final linkedTransition = mutation.transitionId == null
          ? null
          : _flightTransitions.remove(mutation.transitionId);
      if (linkedTransition != null && mutation.insertedItems.length == 1) {
        unawaited(_playTimelineInsertion(linkedTransition));
        return;
      }

      unawaited(_playStandaloneInsertions(mutation.insertedItems));
      return;
    }

    if (mutation.isRemoval) {
      unawaited(_playTimelineRemoval(mutation));
      return;
    }

    setState(_syncVisualTimelineWithController);
  }

  _TimelinePlaceholderHandle _newPlaceholderHandle({
    required bool animateOnMount,
    bool revealImmediately = false,
  }) {
    return _TimelinePlaceholderHandle(
      id: _takeTimelineSlotId(),
      animateOnMount: animateOnMount,
      revealImmediately: revealImmediately,
    );
  }

  void _syncVisualTimelineWithController() {
    final logicalAnimations = widget.sequenceController.selectedAnimations;
    final sharedLength = math.min(
      logicalAnimations.length,
      _visualTimelineSteps.length,
    );
    var commonPrefixLength = 0;
    while (commonPrefixLength < sharedLength &&
        identical(
          logicalAnimations[commonPrefixLength],
          _visualTimelineSteps[commonPrefixLength].item,
        )) {
      commonPrefixLength++;
    }
    final alreadySynchronized =
        logicalAnimations.length == _visualTimelineSteps.length &&
        commonPrefixLength == logicalAnimations.length;

    if (alreadySynchronized) return;

    _visualTimelineSteps = [
      ..._visualTimelineSteps.take(commonPrefixLength),
      ...logicalAnimations
          .skip(commonPrefixLength)
          .map(
            (item) => _TimelineVisualStep(
              id: _takeTimelineSlotId(),
              item: item,
              animateOnMount: false,
              animatePositionOnMount: false,
            ),
          ),
    ];
    _openPlaceholderHandle = _newPlaceholderHandle(animateOnMount: false);
    _lastClaimedPlaceholderHandle = null;
  }

  void _cancelPendingTimelineReservations() {
    for (final reservation in _pendingTimelineReservations) {
      reservation.isCancelled = true;
    }
    _pendingTimelineReservations.clear();
  }

  bool get _isTimelineTransitionBusy =>
      _activeVisualAddFlights > 0 ||
      _activeVisualRemovals > 0 ||
      _activeBulkRestores > 0 ||
      _pendingTimelineReservations.isNotEmpty;

  void _queueHistoryAction(_QueuedHistoryAction action) {
    if (_queuedHistoryActions.length >= 10) return;
    _queuedHistoryActions.add(action);
    unawaited(HapticFeedback.selectionClick());
  }

  void _drainQueuedHistoryActions() {
    if (!mounted ||
        _isTimelineTransitionBusy ||
        _queuedHistoryActions.isEmpty) {
      return;
    }

    final action = _queuedHistoryActions.removeAt(0);
    scheduleMicrotask(() {
      if (!mounted) return;
      switch (action) {
        case _QueuedHistoryAction.undo:
          if (widget.sequenceHistoryController.canUndo) {
            _undoTimelineEdit();
          } else {
            _drainQueuedHistoryActions();
          }
          return;
        case _QueuedHistoryAction.redo:
          if (widget.sequenceHistoryController.canRedo) {
            _redoTimelineEdit();
          } else {
            _drainQueuedHistoryActions();
          }
          return;
      }
    });
  }

  void _undoTimelineEdit() {
    if (!widget.sequenceHistoryController.canUndo) {
      return;
    }
    if (_isTimelineTransitionBusy) {
      _queueHistoryAction(_QueuedHistoryAction.undo);
      return;
    }

    widget.sequenceHistoryController.undo();
    unawaited(HapticFeedback.selectionClick());
  }

  void _redoTimelineEdit() {
    if (!widget.sequenceHistoryController.canRedo) {
      return;
    }
    if (_isTimelineTransitionBusy) {
      _queueHistoryAction(_QueuedHistoryAction.redo);
      return;
    }

    widget.sequenceHistoryController.redo();
    unawaited(HapticFeedback.mediumImpact());
  }

  void _removeTimelineAnimationAt(int index) {
    if (_activeVisualRemovals > 0 ||
        index < 0 ||
        index >= _visualTimelineSteps.length) {
      return;
    }

    widget.sequenceHistoryController.removeFrom(index);
  }

  void _clearAllTimelineAnimations() {
    if (_activeVisualRemovals > 0) return;
    if (widget.sequenceController.selectedAnimations.isEmpty) return;

    widget.sequenceHistoryController.clear();
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
      isBookmarked: widget.libraryController.isBookmarked(entry.item),
      onBookmarkToggle: () =>
          widget.libraryController.toggleBookmark(entry.item),
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
      isBookmarked: widget.libraryController.isBookmarked(item),
      onBookmarkToggle: () => widget.libraryController.toggleBookmark(item),
      onPrimaryAction: () async {},
    );
  }

  Future<void> _handlePrimaryAction(
    LibraryDisplayItem entry, {
    String? transitionId,
  }) async {
    try {
      await widget.libraryController.performPrimaryAction(
        entry,
        transitionId: transitionId,
      );
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
              SequenceBuilderLayout.timelineStepExtent +
              _bulkRestoreReservedExtent
        : SequenceBuilderLibrary.collapsedHeight +
              16 +
              SequenceBuilderLayout.timelineStepExtent +
              _bulkRestoreReservedExtent;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => _setLibraryPanelState(
                  SequenceBuilderLibraryPanelState.fullyCollapsed,
                ),
                child: NotificationListener<ScrollNotification>(
                  onNotification: _handleTimelineScrollNotification,
                  child: SingleChildScrollView(
                    key: _timelineViewportKey,
                    controller: _timelineScrollController,
                    padding: EdgeInsets.only(bottom: timelineBottomPadding),
                    child: Column(
                      children: [
                        const SizedBox(
                          height: SequenceBuilderLayout.headerExtent,
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                          child: _TimelineSection(
                            key: _timelineTargetKey,
                            steps: _visualTimelineSteps,
                            pendingReservations: _pendingTimelineReservations,
                            openPlaceholderHandle: _openPlaceholderHandle,
                            removalTransition: _timelineRemovalTransition,
                            requiredNextPosition: _visibleRequiredNextPosition(
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
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: _controlsHeaderTop,
              left: 0,
              right: 0,
              height: SequenceBuilderLayout.headerExtent,
              child: ColoredBox(
                color: AppColors.background,
                child: _SequenceHeader(
                  sequenceNameController: _sequenceNameController,
                  onNameChanged: sequence.setSequenceName,
                  onBuildUnitySequence: widget.onBuildUnitySequence,
                  canUndo: widget.sequenceHistoryController.canUndo,
                  canRedo: widget.sequenceHistoryController.canRedo,
                  canClear:
                      visibleAnimations.isNotEmpty &&
                      _activeVisualRemovals == 0,
                  onUndo: _undoTimelineEdit,
                  onRedo: _redoTimelineEdit,
                  onClear: _clearAllTimelineAnimations,
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                ignoring: !_isLibraryExpanded,
                child: AnimatedOpacity(
                  opacity: _isLibraryExpanded ? 1 : 0,
                  duration: AppMotion.standard,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _setLibraryPanelState(
                      SequenceBuilderLibraryPanelState.collapsed,
                    ),
                    child: ColoredBox(
                      color: AppColors.black.withValues(
                        alpha: AppOpacity.scrim,
                      ),
                    ),
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
}
