import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_shell.dart';
import '../controllers/library_controller.dart';
import 'library_search_screen.dart';
import '../widgets/animation/animation_info_sheet.dart';
import '../widgets/animation/animation_card.dart';
import '../widgets/animation/animation_card_flight.dart';
import '../widgets/animation/animation_preview_frame.dart';

class FullLibraryScreen extends StatefulWidget {
  const FullLibraryScreen({
    super.key,
    required this.libraryController,
    required this.sequenceBuilderNavKey,
  });

  final LibraryController libraryController;
  final GlobalKey sequenceBuilderNavKey;

  @override
  State<FullLibraryScreen> createState() => _FullLibraryScreenState();
}

class _FullLibraryScreenState extends State<FullLibraryScreen> {
  static const _arrivalHapticDelay = Duration(milliseconds: 90);

  @override
  void initState() {
    super.initState();
    widget.libraryController.addListener(_onLibraryChanged);
  }

  @override
  void dispose() {
    widget.libraryController.removeListener(_onLibraryChanged);
    super.dispose();
  }

  void _onLibraryChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _showAnimationInfo(LibraryDisplayItem entry) async {
    await AnimationInfoSheet.show(
      context,
      item: entry.item,
      isDownloaded: entry.isInstalled,
      isDownloading: entry.isDownloading,
      buttonText: widget.libraryController.getAddActionLabel(entry),
      showPrimaryAction: entry.isInstalled,
      viewIn3DLabel: widget.libraryController.getViewActionLabel(entry),
      onViewIn3D: () => _handleViewAction(entry),
      resolvePreviewPath: widget.libraryController.getOrDownloadPreview,
      resolveCachedPreviewPath: widget.libraryController.getCachedPreviewPath,
      isBookmarked: widget.libraryController.isBookmarked(entry.item),
      onBookmarkToggle: () =>
          widget.libraryController.toggleBookmark(entry.item),
      onAnimatedPrimaryAction: widget.libraryController.requiresDownload(entry)
          ? null
          : (sourceKey) => _animateAndAdd(sourceKey, entry),
      onPrimaryAction: () => _handlePrimaryAction(entry),
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

  Future<void> _handleViewAction(LibraryDisplayItem entry) async {
    try {
      await widget.libraryController.performViewAction(entry);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open ${entry.item.title} in 3D: $e')),
      );
    }
  }

  Future<void> _animateAndAdd(
    GlobalKey sourceKey,
    LibraryDisplayItem entry, {
    Size? flightSize,
  }) async {
    unawaited(HapticFeedback.lightImpact());

    final cachedPreviewPath = widget.libraryController.getCachedPreviewPath(
      entry.item.previewPath,
    );

    await AnimationCardFlight.run(
      sourceKey: sourceKey,
      targetKey: widget.sequenceBuilderNavKey,
      finalScale: AnimationCardFlightTuning.fullLibraryFinalScale,
      scaleEnd: AnimationCardFlightTuning.detailMorphScaleEnd,
      morphFrame: true,
      flightSize: flightSize,
      fadeOut: false,
      flightChild: AnimationPreviewFrame(
        previewPath: cachedPreviewPath ?? entry.item.previewPath,
        resolvePreviewPath: widget.libraryController.getOrDownloadPreview,
        resolveCachedPreviewPath: widget.libraryController.getCachedPreviewPath,
      ),
      actionTiming: AnimationFlightActionTiming.alongsideFlight,
      action: () => _handlePrimaryAction(entry),
    );
    await Future<void>.delayed(_arrivalHapticDelay);
    await HapticFeedback.heavyImpact();
  }

  @override
  Widget build(BuildContext context) {
    final library = widget.libraryController;
    final theme = Theme.of(context);
    final items = library.categoryFilteredItems;
    final placeholderCount = library.metadataPlaceholderCount;

    return Scaffold(
      body: Stack(
        children: [
          GridView.builder(
            padding: const EdgeInsets.fromLTRB(
              12,
              200,
              12,
              AppShell.floatingNavExtraScrollSpace,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 0.62,
            ),
            itemCount: items.length + placeholderCount,
            itemBuilder: (context, index) {
              if (index >= items.length) {
                return AnimationCardSkeleton.standard(
                  key: ValueKey('library-skeleton-${index - items.length}'),
                );
              }

              final entry = items[index];
              final flightKey = GlobalKey(
                debugLabel: 'library-card-${entry.item.animationName}',
              );

              return AnimationCard.standard(
                flightKey: flightKey,
                width: double.infinity,
                item: entry.item,
                isDownloaded: entry.isInstalled,
                isDownloading: entry.isDownloading,
                actionLabel: library.getViewActionLabel(entry),
                primaryActionIcon: Icons.view_in_ar_rounded,
                isBookmarked: library.isBookmarked(entry.item),
                onBookmarkTap: () async {
                  await HapticFeedback.selectionClick();
                  await library.toggleBookmark(entry.item);
                },
                resolvePreviewPath: library.getOrDownloadPreview,
                resolveCachedPreviewPath: library.getCachedPreviewPath,
                onTap: () => _showAnimationInfo(entry),
                onPrimaryAction: () => _handleViewAction(entry),
              );
            },
          ),

          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 18,
                left: 16,
                right: 16,
                bottom: 18,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    theme.scaffoldBackgroundColor,
                    theme.scaffoldBackgroundColor.withValues(alpha: 0.92),
                    theme.scaffoldBackgroundColor.withValues(alpha: 0),
                  ],
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Bibliothek',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => LibrarySearchScreen(
                                libraryController: library,
                                sequenceBuilderNavKey:
                                    widget.sequenceBuilderNavKey,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    height: 52,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _CategoryPill(
                          label: 'Alle',
                          selected: library.selectedCategoryId == null,
                          onTap: () {
                            unawaited(library.selectCategory(null));
                          },
                        ),
                        ...library.categories.map(
                          (category) => _CategoryPill(
                            label: category.displayName,
                            selected: library.selectedCategoryId == category.id,
                            onTap: () {
                              unawaited(library.selectCategory(category.id));
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? Colors.white.withValues(alpha: 0.88)
                : Colors.black.withValues(alpha: 0.34),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? Colors.white.withValues(alpha: 0.7)
                  : Colors.white.withValues(alpha: 0.14),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.black : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
