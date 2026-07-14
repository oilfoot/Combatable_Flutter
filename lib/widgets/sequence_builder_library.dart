import 'package:flutter/material.dart';

import '../app_shell.dart';
import '../controllers/library_controller.dart';
import 'animation/animation_card.dart';

enum SequenceBuilderLibraryPanelState { fullyCollapsed, collapsed, expanded }

class SequenceBuilderLibrary extends StatefulWidget {
  const SequenceBuilderLibrary({
    super.key,
    required this.panelState,
    required this.onStateChanged,
    required this.items,
    required this.libraryController,
    required this.onItemTap,
    required this.onPrimaryAction,
  });

  final SequenceBuilderLibraryPanelState panelState;
  final ValueChanged<SequenceBuilderLibraryPanelState> onStateChanged;
  final List<LibraryDisplayItem> items;
  final LibraryController libraryController;
  final Future<void> Function(LibraryDisplayItem entry) onItemTap;
  final Future<void> Function(GlobalKey sourceKey, LibraryDisplayItem entry)
  onPrimaryAction;

  static const double fullyCollapsedHeight = 176;
  static const double collapsedHeight = 272;
  static const double expandedHeightFactor = 0.85;
  static const double animationCardExtent = AnimationCard.compactExtent;
  static const double collapsedGridHeight = animationCardExtent + 4;

  @override
  State<SequenceBuilderLibrary> createState() => _SequenceBuilderLibraryState();
}

class _SequenceBuilderLibraryState extends State<SequenceBuilderLibrary> {
  static const _panelAnimationDuration = Duration(milliseconds: 320);
  static const _panelAnimationCurve = Curves.easeOutCubic;
  static const double _collapsedBottomPadding = 92;
  static const double _expandedBottomPadding = 12;
  // Keep flicks responsive without letting a short gesture skip too easily
  // between the two extreme states.
  static const double _velocityProjectionSeconds = 0.035;

  double? _dragHeight;

  double _heightForState(
    SequenceBuilderLibraryPanelState state,
    double expandedHeight,
  ) {
    return switch (state) {
      SequenceBuilderLibraryPanelState.fullyCollapsed =>
        SequenceBuilderLibrary.fullyCollapsedHeight,
      SequenceBuilderLibraryPanelState.collapsed =>
        SequenceBuilderLibrary.collapsedHeight,
      SequenceBuilderLibraryPanelState.expanded => expandedHeight,
    };
  }

  void _handleHeaderTap() {
    final nextState = switch (widget.panelState) {
      SequenceBuilderLibraryPanelState.fullyCollapsed =>
        SequenceBuilderLibraryPanelState.collapsed,
      SequenceBuilderLibraryPanelState.collapsed =>
        SequenceBuilderLibraryPanelState.expanded,
      SequenceBuilderLibraryPanelState.expanded =>
        SequenceBuilderLibraryPanelState.collapsed,
    };

    widget.onStateChanged(nextState);
  }

  void _handleArrowTap() {
    widget.onStateChanged(
      widget.panelState == SequenceBuilderLibraryPanelState.expanded
          ? SequenceBuilderLibraryPanelState.fullyCollapsed
          : SequenceBuilderLibraryPanelState.expanded,
    );
  }

  void _handleDragStart(double expandedHeight) {
    setState(() {
      _dragHeight = _heightForState(widget.panelState, expandedHeight);
    });
  }

  void _handleDragUpdate(DragUpdateDetails details, double expandedHeight) {
    final currentHeight = _dragHeight;
    if (currentHeight == null) return;

    setState(() {
      _dragHeight = (currentHeight - details.delta.dy).clamp(
        SequenceBuilderLibrary.fullyCollapsedHeight,
        expandedHeight,
      );
    });
  }

  void _handleDragEnd(DragEndDetails details, double expandedHeight) {
    final currentHeight = _dragHeight;
    if (currentHeight == null) return;

    final velocity = details.primaryVelocity ?? 0;
    final projectedHeight =
        (currentHeight - velocity * _velocityProjectionSeconds).clamp(
          SequenceBuilderLibrary.fullyCollapsedHeight,
          expandedHeight,
        );
    final snapPoints = <SequenceBuilderLibraryPanelState, double>{
      SequenceBuilderLibraryPanelState.fullyCollapsed:
          SequenceBuilderLibrary.fullyCollapsedHeight,
      SequenceBuilderLibraryPanelState.collapsed:
          SequenceBuilderLibrary.collapsedHeight,
      SequenceBuilderLibraryPanelState.expanded: expandedHeight,
    };
    var nearestState = snapPoints.keys.first;
    var nearestDistance = double.infinity;

    for (final entry in snapPoints.entries) {
      final distance = (entry.value - projectedHeight).abs();
      if (distance < nearestDistance) {
        nearestState = entry.key;
        nearestDistance = distance;
      }
    }

    widget.onStateChanged(nearestState);
    if (mounted) {
      setState(() {
        _dragHeight = null;
      });
    }
  }

  void _handleDragCancel() {
    setState(() {
      _dragHeight = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final expandedHeight =
        screenHeight * SequenceBuilderLibrary.expandedHeightFactor;
    final targetHeight = _heightForState(widget.panelState, expandedHeight);
    final height = _dragHeight ?? targetHeight;
    final collapsedRange =
        SequenceBuilderLibrary.collapsedHeight -
        SequenceBuilderLibrary.fullyCollapsedHeight;
    final collapsedProgress =
        ((height - SequenceBuilderLibrary.fullyCollapsedHeight) /
                collapsedRange)
            .clamp(0.0, 1.0);
    final contentOpacity = 0.4 + (collapsedProgress * 0.6);
    final expandedRange =
        expandedHeight - SequenceBuilderLibrary.collapsedHeight;
    final expandedProgress = expandedRange <= 0
        ? 1.0
        : ((height - SequenceBuilderLibrary.collapsedHeight) / expandedRange)
              .clamp(0.0, 1.0);
    final expandedCardsOpacity = (expandedProgress / 0.6).clamp(0.0, 1.0);
    final bottomPadding =
        _collapsedBottomPadding -
        ((_collapsedBottomPadding - _expandedBottomPadding) * expandedProgress);
    final isExpanded =
        widget.panelState == SequenceBuilderLibraryPanelState.expanded;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: (_) => _handleDragStart(expandedHeight),
      onVerticalDragUpdate: (details) =>
          _handleDragUpdate(details, expandedHeight),
      onVerticalDragEnd: (details) => _handleDragEnd(details, expandedHeight),
      onVerticalDragCancel: _handleDragCancel,
      child: AnimatedContainer(
        duration: _dragHeight == null ? _panelAnimationDuration : Duration.zero,
        curve: _panelAnimationCurve,
        height: height,
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(16, 6, 16, bottomPadding),
        decoration: BoxDecoration(
          color: const Color(0xF2141418),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(
            top: BorderSide(color: Colors.white.withOpacity(0.12)),
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 24,
              offset: Offset(0, -8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _handleHeaderTap,
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.28),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text(
                        'Library',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: _handleArrowTap,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 32,
                        ),
                        icon: Icon(
                          isExpanded
                              ? Icons.keyboard_arrow_down
                              : Icons.keyboard_arrow_up,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: IgnorePointer(
                ignoring: height < SequenceBuilderLibrary.collapsedHeight - 1,
                child: AnimatedOpacity(
                  opacity: contentOpacity,
                  duration: _dragHeight == null
                      ? const Duration(milliseconds: 180)
                      : Duration.zero,
                  curve: Curves.easeOut,
                  child: widget.items.isEmpty
                      ? Center(
                          child: Text(
                            'No valid next animations available',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.62),
                            ),
                          ),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final gridHeight = expandedProgress > 0
                                ? constraints.maxHeight
                                : constraints.constrainHeight(
                                    SequenceBuilderLibrary.collapsedGridHeight,
                                  );

                            return Align(
                              alignment: Alignment.topLeft,
                              child: SizedBox(
                                width: double.infinity,
                                height: gridHeight,
                                child: GridView.builder(
                                  padding: const EdgeInsets.only(
                                    bottom:
                                        AppShell.floatingNavExtraScrollSpace,
                                  ),
                                  physics: expandedProgress > 0
                                      ? const BouncingScrollPhysics()
                                      : const NeverScrollableScrollPhysics(),
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 3,
                                        mainAxisSpacing: 12,
                                        crossAxisSpacing: 12,
                                        mainAxisExtent: SequenceBuilderLibrary
                                            .animationCardExtent,
                                      ),
                                  itemCount: widget.items.length,
                                  itemBuilder: (context, index) {
                                    final entry = widget.items[index];
                                    final flightKey = GlobalKey(
                                      debugLabel:
                                          'builder-card-${entry.item.animationName}',
                                    );
                                    final card = AnimationCard.compact(
                                      key: ValueKey(entry.item.animationName),
                                      flightKey: flightKey,
                                      item: entry.item,
                                      isDownloaded: entry.isInstalled,
                                      isDownloading: entry.isDownloading,
                                      resolvePreviewPath: widget
                                          .libraryController
                                          .getOrDownloadPreview,
                                      resolveCachedPreviewPath: widget
                                          .libraryController
                                          .getCachedPreviewPath,
                                      onPrimaryAction: () => widget
                                          .onPrimaryAction(flightKey, entry),
                                      onInfoTap: () => widget.onItemTap(entry),
                                    );

                                    if (index < 3) return card;

                                    return AnimatedOpacity(
                                      key: ValueKey(
                                        'reveal-${entry.item.animationName}',
                                      ),
                                      opacity: expandedCardsOpacity,
                                      duration: _dragHeight == null
                                          ? const Duration(milliseconds: 180)
                                          : Duration.zero,
                                      curve: Curves.easeOut,
                                      child: card,
                                    );
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
