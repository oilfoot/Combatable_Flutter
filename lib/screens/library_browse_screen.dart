import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/library_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/animation/animation_card.dart';
import '../widgets/animation/animation_card_flight.dart';
import '../widgets/animation/animation_info_sheet.dart';
import '../widgets/animation/animation_preview_frame.dart';
import '../widgets/sequence_builder/smart_connect_dialog.dart';

class LibraryBrowseScreen extends StatefulWidget {
  const LibraryBrowseScreen({
    super.key,
    required this.title,
    required this.libraryController,
    required this.sequenceBuilderNavKey,
    this.categoryId,
  });

  final String title;
  final String? categoryId;
  final LibraryController libraryController;
  final GlobalKey sequenceBuilderNavKey;

  @override
  State<LibraryBrowseScreen> createState() => _LibraryBrowseScreenState();
}

class _LibraryBrowseScreenState extends State<LibraryBrowseScreen> {
  static const _arrivalHapticDelay = Duration(milliseconds: 90);

  @override
  void initState() {
    super.initState();
    widget.libraryController.addListener(_onLibraryChanged);
    unawaited(widget.libraryController.loadAllCategories());
  }

  @override
  void dispose() {
    widget.libraryController.removeListener(_onLibraryChanged);
    super.dispose();
  }

  void _onLibraryChanged() {
    if (mounted) setState(() {});
  }

  List<LibraryDisplayItem> get _items {
    final categoryId = widget.categoryId;
    if (categoryId == null || categoryId.isEmpty) {
      return widget.libraryController.allItems;
    }
    return widget.libraryController.allItems
        .where((entry) => entry.item.category == categoryId)
        .toList(growable: false);
  }

  Future<void> _showAnimationInfo(LibraryDisplayItem entry) async {
    final library = widget.libraryController;
    await AnimationInfoSheet.show(
      context,
      item: entry.item,
      isDownloaded: entry.isInstalled,
      isDownloading: entry.isDownloading,
      buttonText: library.getAddActionLabel(entry),
      showPrimaryAction: entry.isInstalled,
      viewIn3DLabel: library.getViewActionLabel(entry),
      onViewIn3D: () => _handleViewAction(entry),
      resolvePreviewPath: library.getOrDownloadPreview,
      resolveCachedPreviewPath: library.getCachedPreviewPath,
      isBookmarked: library.isBookmarked(entry.item),
      onBookmarkToggle: () => library.toggleBookmark(entry.item),
      onAnimatedPrimaryAction: library.requiresDownload(entry)
          ? null
          : (sourceKey) => _animateAndAdd(sourceKey, entry),
      onBeforePrimaryAction: () => confirmSmartConnection(
        context,
        plan: library.planConnection(entry),
        selectedAnimation: entry.item,
      ),
      onPrimaryAction: () => _handlePrimaryAction(entry),
    );
  }

  Future<void> _handlePrimaryAction(LibraryDisplayItem entry) async {
    try {
      await widget.libraryController.performPrimaryAction(entry);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add ${entry.item.title}: $error')),
      );
    }
  }

  Future<void> _handleViewAction(LibraryDisplayItem entry) async {
    try {
      await widget.libraryController.performViewAction(entry);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open ${entry.item.title} in 3D: $error'),
        ),
      );
    }
  }

  Future<void> _animateAndAdd(
    GlobalKey sourceKey,
    LibraryDisplayItem entry,
  ) async {
    unawaited(HapticFeedback.lightImpact());
    final library = widget.libraryController;
    final cachedPreviewPath = library.getCachedPreviewPath(
      entry.item.previewPath,
    );

    await AnimationCardFlight.run(
      sourceKey: sourceKey,
      targetKey: widget.sequenceBuilderNavKey,
      finalScale: AnimationCardFlightTuning.fullLibraryFinalScale,
      scaleEnd: AnimationCardFlightTuning.detailMorphScaleEnd,
      morphFrame: true,
      fadeOut: false,
      flightChild: AnimationPreviewFrame(
        previewPath: cachedPreviewPath ?? entry.item.previewPath,
        resolvePreviewPath: library.getOrDownloadPreview,
        resolveCachedPreviewPath: library.getCachedPreviewPath,
      ),
      actionTiming: AnimationFlightActionTiming.alongsideFlight,
      action: () => _handlePrimaryAction(entry),
    );
    await Future<void>.delayed(_arrivalHapticDelay);
    await HapticFeedback.heavyImpact();
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final isLoading = widget.libraryController.isLoadingMetadata;
    final placeholderCount = items.isEmpty && isLoading ? 6 : 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Row(
                children: [
                  IconButton.filled(
                    tooltip: 'Back',
                    onPressed: () => Navigator.pop(context),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.surface,
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.borderSubtle),
                    ),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.screenTitle,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${items.length} animations',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            Expanded(
              child: items.isEmpty && !isLoading
                  ? const _EmptyCategoryState()
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        0,
                        AppSpacing.md,
                        AppSpacing.xxl,
                      ),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: AppSpacing.md,
                            crossAxisSpacing: AppSpacing.md,
                            childAspectRatio: 0.68,
                          ),
                      itemCount: items.length + placeholderCount,
                      itemBuilder: (context, index) {
                        if (index >= items.length) {
                          return const AnimationCardSkeleton.standard(
                            borderRadius: AppRadii.card,
                          );
                        }
                        final entry = items[index];
                        return AnimationCard.standard(
                          item: entry.item,
                          width: double.infinity,
                          isDownloaded: entry.isInstalled,
                          isDownloading: entry.isDownloading,
                          actionLabel: widget.libraryController
                              .getViewActionLabel(entry),
                          primaryActionIcon: Icons.view_in_ar_rounded,
                          isBookmarked: widget.libraryController.isBookmarked(
                            entry.item,
                          ),
                          onBookmarkTap: () async {
                            await HapticFeedback.selectionClick();
                            await widget.libraryController.toggleBookmark(
                              entry.item,
                            );
                          },
                          resolvePreviewPath:
                              widget.libraryController.getOrDownloadPreview,
                          resolveCachedPreviewPath:
                              widget.libraryController.getCachedPreviewPath,
                          onTap: () => _showAnimationInfo(entry),
                          onPrimaryAction: () => _handleViewAction(entry),
                          borderRadius: AppRadii.card,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCategoryState extends StatelessWidget {
  const _EmptyCategoryState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'No animations in this collection yet.',
        style: AppTypography.body.copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}
