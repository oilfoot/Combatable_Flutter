part of '../../screens/sequence_builder_screen.dart';

extension _SequenceTimelineTransitions on _SequenceBuilderScreenState {
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
      return slotOffset /
          _SequenceBuilderScreenState._incomingTimelineStepExtent;
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

    return overflow / _SequenceBuilderScreenState._incomingTimelineStepExtent;
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
        (reserveNextSlot
            ? _SequenceBuilderScreenState._incomingTimelineStepExtent
            : 0);
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

  _TimelineInsertionTransition _prepareTimelineInsertion(
    AnimationLibraryItem item, {
    required Completer<void> arrival,
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
        ? _SequenceBuilderScreenState._incomingTimelineStepExtent
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
    );
  }

  Future<void> _playStandaloneInsertions(
    List<AnimationLibraryItem> insertedItems,
  ) async {
    for (final item in insertedItems) {
      if (!mounted || _isLibraryExpanded) return;

      final arrival = Completer<void>();
      final transition = _prepareTimelineInsertion(item, arrival: arrival);
      final playback = _playTimelineInsertion(transition);
      await WidgetsBinding.instance.endOfFrame;
      await Future<void>.delayed(const Duration(milliseconds: 70));
      if (!arrival.isCompleted) arrival.complete();
      await playback;
    }
  }

  Future<void> _playTimelineInsertion(
    _TimelineInsertionTransition transition,
  ) async {
    final reservation = transition.reservation;
    if (!mounted || reservation.isCancelled) return;

    _updateTimelineState(() {
      _pendingTimelineReservations.add(reservation);
      _lastClaimedPlaceholderHandle = reservation.handle;
      _openPlaceholderHandle = _newPlaceholderHandle(animateOnMount: true);
    });
    if (transition.landingNeedsPreScroll) {
      _requestTimelineScroll(reservation.handle, reserveNextSlot: true);
    }

    await transition.arrival.future;
    if (!mounted || reservation.isCancelled) return;

    late final _TimelinePlaceholderHandle scrollTarget;
    late final bool revealsFinalPlaceholder;
    _updateTimelineState(() {
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

    if (!transition.landingNeedsPreScroll && revealsFinalPlaceholder) {
      _requestTimelineScroll(
        scrollTarget,
        delay: _timelinePlaceholderRevealDelay,
        isPostRevealScroll: true,
      );
    }
    await Future<void>.delayed(
      _SequenceBuilderScreenState._previewPopHapticDelay,
    );
    await HapticFeedback.heavyImpact();
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
