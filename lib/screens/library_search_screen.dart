import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_shell.dart';
import '../controllers/library_controller.dart';
import '../theme/app_theme.dart';
import '../theme/sequence_builder_layout.dart';
import '../widgets/animation/animation_card_flight.dart';
import '../widgets/animation/animation_info_sheet.dart';
import '../widgets/animation/animation_preview_frame.dart';
import '../widgets/sequence_builder/smart_connect_dialog.dart';

class LibrarySearchScreen extends StatefulWidget {
  const LibrarySearchScreen({
    super.key,
    required this.libraryController,
    required this.sequenceBuilderNavKey,
  });

  final LibraryController libraryController;
  final GlobalKey sequenceBuilderNavKey;

  @override
  State<LibrarySearchScreen> createState() => _LibrarySearchScreenState();
}

class _LibrarySearchScreenState extends State<LibrarySearchScreen> {
  static const _arrivalHapticDelay = Duration(milliseconds: 90);

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _searchDebounce;

  String _query = '';
  List<_IndexedLibraryItem> _searchIndex = const [];
  List<LibraryDisplayItem> _searchResults = const [];
  bool _isLoadingCategories = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    widget.libraryController.addListener(_onLibraryChanged);
    _rebuildSearchIndex();
    _loadSearchData();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    widget.libraryController.removeListener(_onLibraryChanged);
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onLibraryChanged() {
    if (!mounted) return;
    setState(_rebuildSearchIndex);
  }

  Future<void> _loadSearchData() async {
    setState(() {
      _isLoadingCategories = true;
      _loadError = null;
    });

    try {
      await widget.libraryController.loadAllCategories();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = '$e';
      });
    } finally {
      if (mounted) setState(() => _isLoadingCategories = false);
    }
  }

  void _rebuildSearchIndex() {
    _searchIndex = widget.libraryController.allItems
        .map((entry) {
          final item = entry.item;
          final searchable = <String>[
            item.title,
            item.animationName,
            item.startPosition,
            item.endPosition,
            item.category ?? '',
            ...item.tags,
          ].join(' ').toLowerCase();

          return _IndexedLibraryItem(entry: entry, searchableText: searchable);
        })
        .toList(growable: false);
    _applySearch();
  }

  void _applySearch() {
    final normalizedQuery = _query.trim().toLowerCase();
    _searchResults = normalizedQuery.isEmpty
        ? [for (final indexed in _searchIndex) indexed.entry]
        : [
            for (final indexed in _searchIndex)
              if (indexed.searchableText.contains(normalizedQuery))
                indexed.entry,
          ];
  }

  void _onQueryChanged(String value) {
    _searchDebounce?.cancel();
    setState(() => _query = value);
    _searchDebounce = Timer(const Duration(milliseconds: 140), () {
      if (!mounted) return;
      setState(_applySearch);
    });
  }

  void _clearQuery() {
    _searchDebounce?.cancel();
    _searchController.clear();
    setState(() {
      _query = '';
      _applySearch();
    });
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
      onViewIn3D: () => widget.libraryController.performViewAction(entry),
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
    final items = _searchResults;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Row(
                children: [
                  IconButton.filled(
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).pop(),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.surface,
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.borderSubtle),
                    ),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  const Expanded(
                    child: Text('Search', style: AppTypography.screenTitle),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                decoration: InputDecoration(
                  hintText: 'Search animations...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          onPressed: _clearQuery,
                          icon: const Icon(Icons.close),
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadii.button),
                    borderSide: const BorderSide(color: AppColors.borderSubtle),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadii.button),
                    borderSide: const BorderSide(color: AppColors.borderSubtle),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadii.button),
                    borderSide: const BorderSide(color: AppColors.accentSoft),
                  ),
                  filled: true,
                  fillColor: AppColors.surface,
                  hintStyle: AppTypography.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                onChanged: _onQueryChanged,
              ),
            ),
            if (_isLoadingCategories)
              const LinearProgressIndicator(
                minHeight: 2,
                color: AppColors.accent,
                backgroundColor: AppColors.surface,
              ),
            if (_loadError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.xs,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: Text(
                  'Could not load all categories: $_loadError',
                  style: AppTypography.body.copyWith(
                    color: AppColors.destructiveSoft,
                  ),
                ),
              ),
            Expanded(
              child: items.isEmpty
                  ? _SearchEmptyState(hasQuery: _query.trim().isNotEmpty)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.sm,
                        AppSpacing.lg,
                        AppShell.floatingNavExtraScrollSpace,
                      ),
                      itemCount: items.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.md),
                      itemBuilder: (context, index) {
                        final entry = items[index];
                        return _SearchResultTile(
                          key: ValueKey(
                            'search-result-${entry.item.animationName}',
                          ),
                          entry: entry,
                          resolvePreviewPath:
                              widget.libraryController.getOrDownloadPreview,
                          resolveCachedPreviewPath:
                              widget.libraryController.getCachedPreviewPath,
                          onTap: () => _showAnimationInfo(entry),
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

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({
    super.key,
    required this.entry,
    required this.resolvePreviewPath,
    required this.resolveCachedPreviewPath,
    required this.onTap,
  });

  final LibraryDisplayItem entry;
  final Future<String?> Function(String? previewPath) resolvePreviewPath;
  final String? Function(String? previewPath) resolveCachedPreviewPath;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final item = entry.item;
    return SizedBox(
      height: SequenceBuilderLayout.timelineTileHeight,
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: const BorderSide(color: AppColors.borderSubtle),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.small),
                  child: SizedBox.square(
                    dimension: SequenceBuilderLayout.timelinePreviewSize,
                    child: AnimationPreviewFrame(
                      previewPath: item.previewPath,
                      aspectRatio: 1,
                      resolvePreviewPath: resolvePreviewPath,
                      resolveCachedPreviewPath: resolveCachedPreviewPath,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.componentTitle,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        _subtitleText(
                          itemTags: item.tags,
                          category: item.category,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '${item.startPosition}  →  ${item.endPosition}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.accentSoft,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _subtitleText({
    required List<String> itemTags,
    required String? category,
  }) {
    final parts = <String>[
      if (category != null && category.trim().isNotEmpty) category,
      ...itemTags,
    ];

    return parts.isEmpty ? itemLabelFallback : parts.join(' · ');
  }

  static const itemLabelFallback = 'Animation';
}

class _IndexedLibraryItem {
  const _IndexedLibraryItem({
    required this.entry,
    required this.searchableText,
  });

  final LibraryDisplayItem entry;
  final String searchableText;
}

class _SearchEmptyState extends StatelessWidget {
  const _SearchEmptyState({required this.hasQuery});

  final bool hasQuery;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.panel),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 36,
              color: AppColors.accentSoft,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              hasQuery ? 'No animations found' : 'No animations available',
              style: AppTypography.componentTitle,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              hasQuery
                  ? 'Try another name, category, tag, or position.'
                  : 'Your library will appear here when it is ready.',
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
