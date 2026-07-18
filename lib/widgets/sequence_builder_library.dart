import 'package:flutter/material.dart';

import '../app_shell.dart';
import '../controllers/library_controller.dart';
import '../theme/app_theme.dart';
import 'animation/animation_card.dart';

enum SequenceBuilderLibraryPanelState { fullyCollapsed, collapsed, expanded }

class SequenceBuilderLibrary extends StatefulWidget {
  const SequenceBuilderLibrary({
    super.key,
    required this.panelState,
    required this.panelSurfaceKey,
    required this.onStateChanged,
    required this.items,
    required this.libraryController,
    required this.onItemTap,
    required this.onPrimaryAction,
    this.showNavigationScrim = true,
  });

  final SequenceBuilderLibraryPanelState panelState;
  final GlobalKey panelSurfaceKey;
  final ValueChanged<SequenceBuilderLibraryPanelState> onStateChanged;
  final List<LibraryDisplayItem> items;
  final LibraryController libraryController;
  final Future<void> Function(LibraryDisplayItem entry) onItemTap;
  final Future<void> Function(GlobalKey sourceKey, LibraryDisplayItem entry)
  onPrimaryAction;
  final bool showNavigationScrim;

  static const double fullyCollapsedHeight = 176;
  static const double collapsedHeight = 272;
  static const double expandedHeightFactor = 0.85;
  static const double animationCardExtent = AnimationCard.compactExtent;
  static const double collapsedGridHeight = animationCardExtent + 4;

  // Adjust this value to tune the soft edge above the navigation bar.
  // Smaller = more compact/sharper, larger = wider/softer.
  static const double navigationScrimFadeHeight = 50;

  @override
  State<SequenceBuilderLibrary> createState() => _SequenceBuilderLibraryState();
}

class _SequenceBuilderLibraryState extends State<SequenceBuilderLibrary> {
  static const _panelAnimationDuration = AppMotion.panel;
  static const _panelAnimationCurve = AppMotion.enter;
  static const double _bottomPadding = AppSpacing.md;
  static const double _navigationScrimSolidHeight = 88;
  static const double _navigationScrimHeight =
      _navigationScrimSolidHeight +
      SequenceBuilderLibrary.navigationScrimFadeHeight;
  static const double _navigationScrimFadeEnd =
      SequenceBuilderLibrary.navigationScrimFadeHeight / _navigationScrimHeight;
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
    final expandedRange =
        expandedHeight - SequenceBuilderLibrary.collapsedHeight;
    final expandedProgress = expandedRange <= 0
        ? 1.0
        : ((height - SequenceBuilderLibrary.collapsedHeight) / expandedRange)
              .clamp(0.0, 1.0);
    final isExpanded =
        widget.panelState == SequenceBuilderLibraryPanelState.expanded;
    final expandedCardsOpacity = isExpanded
        ? expandedProgress
        : (expandedProgress / 0.6).clamp(0.0, 1.0);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: (_) => _handleDragStart(expandedHeight),
      onVerticalDragUpdate: (details) =>
          _handleDragUpdate(details, expandedHeight),
      onVerticalDragEnd: (details) => _handleDragEnd(details, expandedHeight),
      onVerticalDragCancel: _handleDragCancel,
      child: AnimatedContainer(
        key: widget.panelSurfaceKey,
        duration: _dragHeight == null ? _panelAnimationDuration : Duration.zero,
        curve: _panelAnimationCurve,
        height: height,
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 6, 16, _bottomPadding),
        decoration: BoxDecoration(
          color: AppColors.panel,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadii.panel),
          ),
          border: const Border(top: BorderSide(color: AppColors.borderSubtle)),
          boxShadow: [AppShadows.panel],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Column(
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
                            color: AppColors.textDisabled,
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          const Text(
                            'Library',
                            style: AppTypography.sectionTitle,
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
                const SizedBox(height: AppSpacing.xs),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap:
                        widget.panelState ==
                            SequenceBuilderLibraryPanelState.fullyCollapsed
                        ? () => widget.onStateChanged(
                            SequenceBuilderLibraryPanelState.collapsed,
                          )
                        : null,
                    child: IgnorePointer(
                      ignoring:
                          height < SequenceBuilderLibrary.collapsedHeight - 1,
                      child: AnimatedSwitcher(
                        duration: AppMotion.quick,
                        switchInCurve: AppMotion.enter,
                        switchOutCurve: AppMotion.exit,
                        layoutBuilder: (currentChild, previousChildren) {
                          return Stack(
                            alignment: Alignment.topCenter,
                            children: [...previousChildren, ?currentChild],
                          );
                        },
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: ScaleTransition(
                              alignment: Alignment.topCenter,
                              scale: Tween<double>(
                                begin: 0.975,
                                end: 1,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                        child: widget.items.isEmpty
                            ? const _EmptyLibraryState(
                                key: ValueKey('empty-library'),
                              )
                            : LayoutBuilder(
                                key: ValueKey(
                                  widget.items
                                      .map((entry) => entry.item.animationName)
                                      .join('|'),
                                ),
                                builder: (context, constraints) {
                                  final gridHeight = expandedProgress > 0
                                      ? constraints.maxHeight
                                      : constraints.constrainHeight(
                                          SequenceBuilderLibrary
                                              .collapsedGridHeight,
                                        );

                                  return Align(
                                    alignment: Alignment.topLeft,
                                    child: SizedBox(
                                      width: double.infinity,
                                      height: gridHeight,
                                      child: GridView.builder(
                                        padding: EdgeInsets.only(
                                          bottom: widget.showNavigationScrim
                                              ? AppShell
                                                    .floatingNavExtraScrollSpace
                                              : AppSpacing.panel,
                                        ),
                                        physics: expandedProgress > 0
                                            ? const BouncingScrollPhysics()
                                            : const NeverScrollableScrollPhysics(),
                                        gridDelegate:
                                            const SliverGridDelegateWithFixedCrossAxisCount(
                                              crossAxisCount: 3,
                                              mainAxisSpacing: AppSpacing.md,
                                              crossAxisSpacing: AppSpacing.md,
                                              mainAxisExtent:
                                                  SequenceBuilderLibrary
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
                                            key: ValueKey(
                                              entry.item.animationName,
                                            ),
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
                                            onPrimaryAction: () =>
                                                widget.onPrimaryAction(
                                                  flightKey,
                                                  entry,
                                                ),
                                            onInfoTap: () =>
                                                widget.onItemTap(entry),
                                          );

                                          if (index < 3) return card;

                                          return AnimatedOpacity(
                                            key: ValueKey(
                                              'reveal-${entry.item.animationName}',
                                            ),
                                            opacity: expandedCardsOpacity,
                                            duration: _dragHeight == null
                                                ? AppMotion.cardReveal
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
                ),
              ],
            ),
            if (widget.showNavigationScrim)
              Positioned(
                left: 0,
                right: 0,
                bottom: -_bottomPadding,
                height: _navigationScrimHeight,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.transparent,
                          AppColors.panel,
                          AppColors.panel,
                        ],
                        stops: [0, _navigationScrimFadeEnd, 1],
                      ),
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

class _EmptyLibraryState extends StatelessWidget {
  const _EmptyLibraryState({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(2, 10, 2, 0),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.button),
            border: Border.all(
              color: AppColors.accentSoft.withValues(alpha: AppOpacity.muted),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: AppOpacity.subtle),
                  borderRadius: BorderRadius.circular(AppRadii.small),
                ),
                child: const Icon(
                  Icons.search_off_rounded,
                  size: 22,
                  color: AppColors.accentSoft,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'No matching animations',
                      style: AppTypography.componentTitle,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'No card can continue from the current position.',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
