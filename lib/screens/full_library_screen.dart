import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_shell.dart';
import '../controllers/library_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/animation/animation_info_sheet.dart';
import '../widgets/animation/animation_card.dart';
import '../widgets/animation/animation_card_flight.dart';
import '../widgets/animation/animation_preview_frame.dart';
import '../widgets/library/library_browse_controls.dart';
import '../widgets/library/library_explore_section.dart';
import '../widgets/library/library_filter_sheet.dart';
import '../widgets/sequence_builder/smart_connect_dialog.dart';

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
  static const _searchDelay = Duration(milliseconds: 140);

  bool _isExploreMode = true;
  LibraryFilterSelection _filters = LibraryFilterSelection();
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _searchInput = '';
  String _query = '';
  Map<String, String> _searchIndex = const {};

  @override
  void initState() {
    super.initState();
    widget.libraryController.addListener(_onLibraryChanged);
    _rebuildSearchIndex();
  }

  @override
  void dispose() {
    widget.libraryController.removeListener(_onLibraryChanged);
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onLibraryChanged() {
    if (!mounted) return;
    setState(_rebuildSearchIndex);
  }

  void _rebuildSearchIndex() {
    _searchIndex = {
      for (final entry in widget.libraryController.allItems)
        entry.item.animationName: <String>[
          entry.item.title,
          entry.item.animationName,
          entry.item.startPosition,
          entry.item.endPosition,
          entry.item.category ?? '',
          ...entry.item.tags,
        ].join(' ').toLowerCase(),
    };
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    setState(() => _searchInput = value);

    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) {
      setState(() => _query = '');
      return;
    }

    _searchDebounce = Timer(_searchDelay, () {
      if (!mounted) return;
      setState(() => _query = normalized);
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    setState(() {
      _searchInput = '';
      _query = '';
    });
  }

  List<LibraryDisplayItem> _applyFilters(List<LibraryDisplayItem> items) {
    return items
        .where((entry) {
          if (_filters.downloadedOnly && !entry.isInstalled) return false;
          if (_filters.bookmarkedOnly &&
              !widget.libraryController.isBookmarked(entry.item)) {
            return false;
          }
          if (_filters.startPosition != null &&
              entry.item.startPosition != _filters.startPosition) {
            return false;
          }
          if (_filters.endPosition != null &&
              entry.item.endPosition != _filters.endPosition) {
            return false;
          }
          if (_filters.tags.isNotEmpty &&
              !_filters.tags.every(entry.item.tags.contains)) {
            return false;
          }
          if (_query.isNotEmpty &&
              !(_searchIndex[entry.item.animationName] ?? '').contains(
                _query,
              )) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  void _showExplore() {
    _searchDebounce?.cancel();
    _searchController.clear();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _searchInput = '';
      _query = '';
      _isExploreMode = true;
    });
    unawaited(widget.libraryController.selectCategory(null));
  }

  void _showAll() {
    setState(() => _isExploreMode = false);
    unawaited(widget.libraryController.selectCategory(null));
  }

  void _showCategory(String categoryId) {
    setState(() => _isExploreMode = false);
    unawaited(widget.libraryController.selectCategory(categoryId));
  }

  Future<void> _showFilters() async {
    setState(() => _isExploreMode = false);
    await showLibraryFilterSheet(
      context,
      initialSelection: _filters,
      allItems: widget.libraryController.allItems,
      onChanged: (selection) {
        if (!mounted) return;
        setState(() => _filters = selection);
      },
    );
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
      onBeforePrimaryAction: () => confirmSmartConnection(
        context,
        plan: widget.libraryController.planConnection(entry),
        selectedAnimation: entry.item,
      ),
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
    final items = _applyFilters(library.categoryFilteredItems);
    final isInitialLoading = library.allItems.isEmpty;
    final reportedPlaceholderCount = library.metadataPlaceholderCount;
    final placeholderCount = isInitialLoading
        ? (reportedPlaceholderCount < 6 ? 6 : reportedPlaceholderCount)
        : reportedPlaceholderCount;
    final topPadding = MediaQuery.paddingOf(context).top + 230;
    final showExplore = _isExploreMode && _query.isEmpty;

    return Scaffold(
      body: Stack(
        children: [
          if (showExplore)
            _buildExploreContent(
              topPadding,
              showLoadingSkeletons:
                  library.isLoadingMetadata || isInitialLoading,
            )
          else
            _buildBrowseContent(
              items: items,
              placeholderCount: placeholderCount,
              topPadding: topPadding,
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
                          'Library',
                          style: AppTypography.screenTitle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    height: 46,
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      textInputAction: TextInputAction.search,
                      style: AppTypography.body,
                      decoration: InputDecoration(
                        hintText: 'Search animations...',
                        hintStyle: AppTypography.body.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        prefixIcon: const Icon(Icons.search_rounded, size: 21),
                        suffixIcon: _searchInput.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear search',
                                onPressed: _clearSearch,
                                icon: const Icon(Icons.close_rounded, size: 20),
                              ),
                        filled: true,
                        fillColor: AppColors.surface,
                        contentPadding: EdgeInsets.zero,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadii.button),
                          borderSide: const BorderSide(
                            color: AppColors.borderSubtle,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadii.button),
                          borderSide: const BorderSide(
                            color: AppColors.borderSubtle,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadii.button),
                          borderSide: const BorderSide(
                            color: AppColors.accentSoft,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ColoredBox(
                    color: theme.scaffoldBackgroundColor,
                    child: Row(
                      children: [
                        Expanded(
                          child: ClipRect(
                            child: SizedBox(
                              height: 44,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: [
                                  LibraryCategoryPill(
                                    label: 'Explore',
                                    icon: Icons.auto_awesome_rounded,
                                    selected: showExplore,
                                    onTap: _showExplore,
                                  ),
                                  LibraryCategoryPill(
                                    label: 'All',
                                    selected:
                                        !showExplore &&
                                        library.selectedCategoryId == null,
                                    onTap: _showAll,
                                  ),
                                  ...library.categories.map(
                                    (category) => LibraryCategoryPill(
                                      label: category.displayName,
                                      selected:
                                          !showExplore &&
                                          library.selectedCategoryId ==
                                              category.id,
                                      onTap: () => _showCategory(category.id),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 30,
                          margin: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                          ),
                          color: AppColors.borderStrong,
                        ),
                        LibraryFilterButton(
                          activeCount: _filters.activeCount,
                          onTap: _showFilters,
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

  Widget _buildExploreContent(
    double topPadding, {
    required bool showLoadingSkeletons,
  }) {
    final library = widget.libraryController;
    final allItems = _applyFilters(library.allItems);
    final sections = <_ExploreSectionData>[];

    if (allItems.isNotEmpty) {
      final featuredItems = allItems.take(6).toList(growable: false);
      sections.add(
        _ExploreSectionData(
          title: 'Featured animations',
          subtitle: 'A simple place to start',
          items: featuredItems,
          placeholderCount: showLoadingSkeletons ? 6 - featuredItems.length : 0,
          onViewAll: _showAll,
        ),
      );
    }

    for (final category in library.categories) {
      final categoryItems = allItems
          .where((entry) => entry.item.category == category.id)
          .take(6)
          .toList(growable: false);
      final expectedCardCount = category.count < 6 ? category.count : 6;
      final missingCardCount = expectedCardCount - categoryItems.length;
      final placeholderCount = showLoadingSkeletons && missingCardCount > 0
          ? missingCardCount
          : 0;
      if (categoryItems.isEmpty && placeholderCount == 0) continue;
      sections.add(
        _ExploreSectionData(
          title: category.displayName,
          subtitle: 'Explore ${category.displayName.toLowerCase()}',
          items: categoryItems,
          placeholderCount: placeholderCount,
          onViewAll: () => _showCategory(category.id),
        ),
      );
    }

    if (sections.isEmpty && showLoadingSkeletons) {
      return ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          topPadding,
          AppSpacing.lg,
          AppShell.floatingNavExtraScrollSpace,
        ),
        children: const [
          LibraryExploreSectionSkeleton(),
          SizedBox(height: AppSpacing.xxl),
          LibraryExploreSectionSkeleton(),
        ],
      );
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        0,
        topPadding,
        0,
        AppShell.floatingNavExtraScrollSpace,
      ),
      itemCount: sections.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xxl),
      itemBuilder: (context, index) {
        final section = sections[index];
        return LibraryExploreSection(
          title: section.title,
          subtitle: section.subtitle,
          items: section.items,
          placeholderCount: section.placeholderCount,
          onViewAll: section.onViewAll,
          cardBuilder: _buildLibraryCard,
        );
      },
    );
  }

  Widget _buildBrowseContent({
    required List<LibraryDisplayItem> items,
    required int placeholderCount,
    required double topPadding,
  }) {
    if (items.isEmpty && placeholderCount == 0) {
      return ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          topPadding + AppSpacing.xxl,
          AppSpacing.lg,
          AppShell.floatingNavExtraScrollSpace,
        ),
        children: [
          LibraryEmptyBrowseState(
            hasFilters: _filters.activeCount > 0 || _query.isNotEmpty,
            onClearFilters: () {
              _clearSearch();
              setState(() => _filters = LibraryFilterSelection());
            },
          ),
        ],
      );
    }

    return GridView.builder(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        topPadding,
        AppSpacing.md,
        AppShell.floatingNavExtraScrollSpace,
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        childAspectRatio: 0.68,
      ),
      itemCount: items.length + placeholderCount,
      itemBuilder: (context, index) {
        if (index >= items.length) {
          return AnimationCardSkeleton.standard(
            key: ValueKey('library-skeleton-${index - items.length}'),
            borderRadius: AppRadii.card,
          );
        }
        return _buildLibraryCard(items[index], double.infinity);
      },
    );
  }

  Widget _buildLibraryCard(LibraryDisplayItem entry, double width) {
    final library = widget.libraryController;
    final flightKey = GlobalKey(
      debugLabel: 'library-card-${entry.item.animationName}',
    );

    return AnimationCard.standard(
      flightKey: flightKey,
      width: width,
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
      borderRadius: AppRadii.card,
    );
  }
}

class _ExploreSectionData {
  const _ExploreSectionData({
    required this.title,
    required this.subtitle,
    required this.items,
    this.placeholderCount = 0,
    required this.onViewAll,
  });

  final String title;
  final String subtitle;
  final List<LibraryDisplayItem> items;
  final int placeholderCount;
  final VoidCallback onViewAll;
}
