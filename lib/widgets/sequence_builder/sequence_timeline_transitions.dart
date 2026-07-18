part of '../../screens/sequence_builder_screen.dart';

const int _bulkRestoreMinimumWaveMilliseconds = 180;
const int _bulkRestoreMaximumWaveMilliseconds = 480;

extension _SequenceTimelineTransitions on _SequenceBuilderScreenState {
  Future<void> _playTimelineRemoval(SequenceMutation mutation) async {
    final firstRemovedIndex = mutation.commonPrefixLength;
    if (_activeVisualRemovals > 0 ||
        firstRemovedIndex >= _visualTimelineSteps.length) {
      _updateTimelineState(_syncVisualTimelineWithController);
      return;
    }

    _activeVisualRemovals++;
    final firstRemovedStep = _visualTimelineSteps[firstRemovedIndex];
    final transition = _TimelineRemovalTransition(
      firstRemovedIndex: firstRemovedIndex,
      replacementPlaceholderHandle: _TimelinePlaceholderHandle(
        id: firstRemovedStep.id,
        animateOnMount: false,
      ),
    );
    final removalScroll = _scrollTimelineForRemoval(
      _visualTimelineSteps.length - firstRemovedIndex,
    );
    final removalCompletions = <Completer<void>>[];
    _updateTimelineState(() {
      _cancelPendingTimelineReservations();
      _timelineRemovalTransition = transition;
      _visualTimelineSteps = [
        for (var index = 0; index < _visualTimelineSteps.length; index++)
          if (index < firstRemovedIndex)
            _visualTimelineSteps[index]
          else
            _TimelineVisualStep(
              id: _visualTimelineSteps[index].id,
              item: _visualTimelineSteps[index].item,
              animateOnMount: false,
              animatePositionOnMount: true,
              removalCompletion: () {
                final completion = Completer<void>();
                removalCompletions.add(completion);
                return completion;
              }(),
            ),
      ];
    });
    unawaited(HapticFeedback.mediumImpact());

    try {
      final oldPlaceholderHidden = transition.placeholderCompletion.future
          .timeout(const Duration(milliseconds: 300), onTimeout: () {});
      if (removalCompletions.isNotEmpty) {
        await Future.wait([
          oldPlaceholderHidden,
          removalScroll,
          ...removalCompletions.map((item) => item.future),
        ]);
      } else {
        await Future.wait([oldPlaceholderHidden, removalScroll]);
      }
      if (!mounted) return;

      _updateTimelineState(() {
        _visualTimelineSteps.removeRange(
          firstRemovedIndex,
          _visualTimelineSteps.length,
        );
        _openPlaceholderHandle = transition.replacementPlaceholderHandle;
        _lastClaimedPlaceholderHandle = null;
        _timelineRemovalTransition = null;
      });
    } finally {
      _activeVisualRemovals--;
      _updateTimelineState(() {});
      _drainQueuedHistoryActions();
    }
  }

  Future<void> _scrollTimelineForRemoval(int removedStepCount) async {
    if (!_timelineScrollController.hasClients || removedStepCount <= 0) return;

    _timelineScrollRequestVersionState =
        (_timelineScrollRequestVersionState ?? 0) + 1;
    final position = _timelineScrollController.position;
    final predictedFinalMaximum = math.max(
      position.minScrollExtent,
      position.maxScrollExtent -
          removedStepCount * SequenceBuilderLayout.railPositionToPositionExtent,
    );
    const deletionScrollSafetyMargin = 20.0;
    final targetOffset = math.max(
      position.minScrollExtent,
      predictedFinalMaximum - deletionScrollSafetyMargin,
    );

    if (_timelineScrollController.offset <= targetOffset + 0.5) return;

    try {
      await _timelineScrollController.animateTo(
        targetOffset,
        duration: _timelineRemovalDuration,
        curve: Curves.easeInOutCubic,
      );
    } catch (_) {
      // A newer timeline transition intentionally replaces this scroll.
    }
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
      return slotOffset / SequenceBuilderLayout.timelineStepExtent;
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

    return overflow / SequenceBuilderLayout.timelineStepExtent;
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
        addStepBottom +
        (reserveNextSlot ? SequenceBuilderLayout.timelineStepExtent : 0);
    final viewportTop = viewportBox.localToGlobal(Offset.zero).dy;
    final viewportBottom = viewportBox
        .localToGlobal(Offset(0, viewportBox.size.height))
        .dy;
    final panelTop = panelBox.localToGlobal(Offset.zero).dy;
    final visibleTop = viewportTop + 12;
    final occlusionBoundary = panelTop > visibleTop ? panelTop : viewportBottom;
    if (isPostRevealScroll &&
        requiredBottom <=
            occlusionBoundary +
                SequenceBuilderLayout.postRevealOverflowThreshold) {
      return;
    }
    final bottomClearance = isPostRevealScroll
        ? SequenceBuilderLayout.postRevealBottomClearance
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

  _TimelineInsertionTransition _prepareTimelineInsertion(
    AnimationLibraryItem item, {
    required Completer<void> arrival,
    bool playsArrivalHaptic = true,
    bool managesOwnScroll = false,
    bool consumesBulkReservedExtent = false,
    bool revealsNextPlaceholderImmediately = false,
  }) {
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
        ? SequenceBuilderLayout.timelineStepExtent
        : 0.0;
    final flightTarget = _projectLandingTarget(
      baseHandle: baseHandle,
      slotOffset: slotOffset,
    );
    final landingOverflowSteps = _landingOverflowSteps(
      baseHandle: baseHandle,
      slotOffset: slotOffset,
    );

    return _TimelineInsertionTransition(
      reservation: _PendingTimelineReservation(
        handle: landingHandle,
        item: item,
      ),
      flightTarget: flightTarget,
      landingNeedsPreScroll: landingOverflowSteps > 0,
      usesLongScrollFlight:
          landingOverflowSteps >=
          AnimationCardFlightTuning.sequenceBuilderLongScrollStepThreshold,
      arrival: arrival,
      playsArrivalHaptic: playsArrivalHaptic,
      managesOwnScroll: managesOwnScroll,
      consumesBulkReservedExtent: consumesBulkReservedExtent,
      revealsNextPlaceholderImmediately: revealsNextPlaceholderImmediately,
    );
  }

  Future<void> _playStandaloneInsertions(
    List<AnimationLibraryItem> insertedItems,
  ) async {
    if (insertedItems.isEmpty) return;

    final isBulkRestore = insertedItems.length > 1;
    if (isBulkRestore) {
      _activeBulkRestores++;
      _updateTimelineState(() {
        _bulkRestoreReservedExtent =
            insertedItems.length *
            SequenceBuilderLayout.railPositionToPositionExtent;
      });
      await WidgetsBinding.instance.endOfFrame;
    }

    final waveMilliseconds = (140 + insertedItems.length * 22).clamp(
      _bulkRestoreMinimumWaveMilliseconds,
      _bulkRestoreMaximumWaveMilliseconds,
    );
    if (isBulkRestore) {
      unawaited(_scrollTimelineForBulkRestore(waveMilliseconds));
    }
    final playbacks = <Future<void>>[];

    for (var index = 0; index < insertedItems.length; index++) {
      final normalizedIndex = insertedItems.length == 1
          ? 0.0
          : index / (insertedItems.length - 1);
      final easeOutEventTime = 1 - math.sqrt(1 - normalizedIndex);
      final delay = Duration(
        milliseconds: (waveMilliseconds * easeOutEventTime).round(),
      );
      playbacks.add(
        _playStandaloneInsertionAfterDelay(
          insertedItems[index],
          delay: delay,
          playsArrivalHaptic: index >= insertedItems.length - 3,
          isBulkRestore: isBulkRestore,
          isLastInsertion: index == insertedItems.length - 1,
        ),
      );
    }

    try {
      await Future.wait(playbacks);
    } finally {
      _updateTimelineState(() {
        _bulkRestoreReservedExtent = 0;
      });
      if (isBulkRestore) _activeBulkRestores--;
      _drainQueuedHistoryActions();
    }
  }

  Future<void> _scrollTimelineForBulkRestore(int waveMilliseconds) async {
    if (!_timelineScrollController.hasClients) return;

    final position = _timelineScrollController.position;
    final targetOffset = position.maxScrollExtent;
    if (targetOffset <= _timelineScrollController.offset + 0.5) return;

    try {
      await _timelineScrollController.animateTo(
        targetOffset,
        duration: Duration(
          milliseconds: (waveMilliseconds + 320).clamp(560, 820),
        ),
        curve: Curves.easeInOutCubic,
      );
    } catch (_) {
      // The growing timeline may retarget the active scroll position.
    }
  }

  Future<void> _playStandaloneInsertionAfterDelay(
    AnimationLibraryItem item, {
    required Duration delay,
    required bool playsArrivalHaptic,
    required bool isBulkRestore,
    required bool isLastInsertion,
  }) async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (!mounted || _isLibraryExpanded || _activeVisualRemovals > 0) return;

    final arrival = Completer<void>();
    final transition = _prepareTimelineInsertion(
      item,
      arrival: arrival,
      playsArrivalHaptic: playsArrivalHaptic,
      managesOwnScroll: true,
      consumesBulkReservedExtent: isBulkRestore,
      revealsNextPlaceholderImmediately: isBulkRestore && isLastInsertion,
    );
    final playback = _playTimelineInsertion(transition);
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 70));
    if (!arrival.isCompleted) arrival.complete();
    await playback;
  }

  Future<void> _playTimelineInsertion(
    _TimelineInsertionTransition transition,
  ) async {
    final reservation = transition.reservation;
    if (!mounted || reservation.isCancelled) return;

    _updateTimelineState(() {
      _pendingTimelineReservations.add(reservation);
      _lastClaimedPlaceholderHandle = reservation.handle;
      _openPlaceholderHandle = _newPlaceholderHandle(
        animateOnMount: true,
        revealImmediately: transition.revealsNextPlaceholderImmediately,
      );
    });
    if (!transition.managesOwnScroll && transition.landingNeedsPreScroll) {
      _requestTimelineScroll(reservation.handle, reserveNextSlot: true);
    }

    await transition.arrival.future;
    if (!mounted || reservation.isCancelled) return;

    late final _TimelinePlaceholderHandle scrollTarget;
    late final bool revealsFinalPlaceholder;
    var committedStepCount = 0;
    _updateTimelineState(() {
      reservation.hasArrived = true;

      while (_pendingTimelineReservations.isNotEmpty &&
          _pendingTimelineReservations.first.hasArrived) {
        final arrivedReservation = _pendingTimelineReservations.removeAt(0);
        committedStepCount++;
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
      if (transition.consumesBulkReservedExtent && committedStepCount > 0) {
        _bulkRestoreReservedExtent = math.max(
          0,
          _bulkRestoreReservedExtent -
              committedStepCount *
                  SequenceBuilderLayout.railPositionToPositionExtent,
        );
      }
    });

    if (!transition.managesOwnScroll &&
        !transition.landingNeedsPreScroll &&
        revealsFinalPlaceholder) {
      _requestTimelineScroll(
        scrollTarget,
        delay: _timelinePlaceholderRevealDelay,
        isPostRevealScroll: true,
      );
    }
    if (transition.playsArrivalHaptic) {
      await Future<void>.delayed(
        _SequenceBuilderScreenState._previewPopHapticDelay,
      );
      await HapticFeedback.heavyImpact();
    }
    _drainQueuedHistoryActions();
  }

  Future<void> _animateAndAdd(
    GlobalKey sourceKey,
    LibraryDisplayItem entry, {
    Size? flightSize,
  }) async {
    if (_activeVisualRemovals > 0) return;

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

    final arrival = Completer<void>();
    final transition = _prepareTimelineInsertion(entry.item, arrival: arrival);
    final transitionId = 'sequence-insert-${_nextTransitionId++}';
    _flightTransitions[transitionId] = transition;
    _activeVisualAddFlights++;
    final cachedPreviewPath = widget.libraryController.getCachedPreviewPath(
      entry.item.previewPath,
    );
    try {
      final flight = AnimationCardFlight.run(
        sourceKey: sourceKey,
        targetKey: transition.reservation.handle.flightTargetKey,
        destination: transition.flightTarget == null
            ? null
            : (_) => transition.flightTarget!,
        finalScale: AnimationCardFlightTuning.collapsedBuilderFinalScale,
        flightSize: flightSize,
        fadeOut: false,
        preventDownwardFlight: true,
        duration: transition.usesLongScrollFlight
            ? AnimationCardFlightTuning.sequenceBuilderLongScrollDuration
            : AnimationCardFlightTuning.sequenceBuilderDuration,
        arcLift: transition.usesLongScrollFlight
            ? AnimationCardFlightTuning.sequenceBuilderLongScrollArcLift
            : AnimationCardFlightTuning.sequenceBuilderArcLift,
        scaleStart: transition.usesLongScrollFlight
            ? AnimationCardFlightTuning.sequenceBuilderLongScrollScaleStart
            : AnimationCardFlightTuning.sequenceBuilderScaleStart,
        flightChild: AnimationPreviewFrame(
          previewPath: cachedPreviewPath ?? entry.item.previewPath,
          resolvePreviewPath: widget.libraryController.getOrDownloadPreview,
          resolveCachedPreviewPath:
              widget.libraryController.getCachedPreviewPath,
        ),
        actionTiming: AnimationFlightActionTiming.alongsideFlight,
        action: () => _handlePrimaryAction(entry, transitionId: transitionId),
      );

      await flight;
      if (!arrival.isCompleted) arrival.complete();
    } finally {
      _flightTransitions.remove(transitionId);
      if (!arrival.isCompleted) arrival.complete();
      _activeVisualAddFlights--;
      _updateTimelineState(() {});
      _drainQueuedHistoryActions();
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
      _updateTimelineState(() {});
      _drainQueuedHistoryActions();
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
