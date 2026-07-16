import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/library_controller.dart';
import '../controllers/sequence_controller.dart';
import '../controllers/sequence_history_controller.dart';
import '../models/animation_library_item.dart';
import '../widgets/animation/animation_info_sheet.dart';
import '../widgets/animation/animation_card_flight.dart';
import '../widgets/animation/animation_preview_frame.dart';
import '../widgets/sequence_builder_library.dart';

part '../widgets/sequence_builder/sequence_timeline.dart';
part '../widgets/sequence_builder/sequence_timeline_transitions.dart';
part '../widgets/sequence_builder/sequence_builder_chrome.dart';

const _timelinePlaceholderRevealDelay = Duration(milliseconds: 324);
const double _timelinePostRevealBottomClearance = 32;
const double _timelinePostRevealOverflowThreshold = 4;

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

class _TimelineInsertionTransition {
  _TimelineInsertionTransition({
    required this.reservation,
    required this.flightTarget,
    required this.landingNeedsPreScroll,
    required this.usesLongScrollFlight,
    required this.arrival,
  });

  final _PendingTimelineReservation reservation;
  final Offset? flightTarget;
  final bool landingNeedsPreScroll;
  final bool usesLongScrollFlight;
  final Completer<void> arrival;
}

class _SequenceBuilderScreenState extends State<SequenceBuilderScreen> {
  static const _previewPopHapticDelay = Duration(milliseconds: 90);

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
  int _nextTransitionId = 0;
  int _activeVisualAddFlights = 0;
  final Map<String, _TimelineInsertionTransition> _flightTransitions = {};
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

    setState(_syncVisualTimelineWithController);
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

  void _undoTimelineEdit() {
    if (!widget.sequenceHistoryController.canUndo ||
        _activeVisualAddFlights > 0 ||
        _pendingTimelineReservations.isNotEmpty) {
      return;
    }

    widget.sequenceHistoryController.undo();
    unawaited(HapticFeedback.selectionClick());
  }

  void _redoTimelineEdit() {
    if (!widget.sequenceHistoryController.canRedo ||
        _activeVisualAddFlights > 0 ||
        _pendingTimelineReservations.isNotEmpty) {
      return;
    }

    widget.sequenceHistoryController.redo();
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
      _cancelPendingTimelineReservations();
      _visualTimelineSteps.removeRange(index, _visualTimelineSteps.length);
      _openPlaceholderHandle = _newPlaceholderHandle(animateOnMount: false);
      _lastClaimedPlaceholderHandle = null;
    });
    widget.sequenceHistoryController.removeFrom(index);
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
      _visualTimelineSteps.clear();
      _cancelPendingTimelineReservations();
      _openPlaceholderHandle = _newPlaceholderHandle(animateOnMount: false);
      _lastClaimedPlaceholderHandle = null;
    });
    widget.sequenceHistoryController.clear();
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
                                        widget
                                            .sequenceHistoryController
                                            .canUndo &&
                                        _activeVisualAddFlights == 0 &&
                                        _pendingTimelineReservations.isEmpty,
                                    canRedo:
                                        widget
                                            .sequenceHistoryController
                                            .canRedo &&
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
}
