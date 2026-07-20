import 'package:flutter/foundation.dart';

import '../data/mock_animation_library.dart';
import '../models/animation_library_item.dart';
import '../services/remote_addressables_service.dart';
import '../services/sequence_connection_planner.dart';
import 'bookmark_controller.dart';
import 'sequence_controller.dart';
import 'sequence_history_controller.dart';

class LibraryDisplayItem {
  const LibraryDisplayItem({
    required this.item,
    required this.isRemote,
    required this.isInstalled,
    required this.isDownloading,
  });

  final AnimationLibraryItem item;
  final bool isRemote;
  final bool isInstalled;
  final bool isDownloading;
}

class LibraryController extends ChangeNotifier {
  LibraryController({
    required SequenceController sequenceController,
    required SequenceHistoryController sequenceHistoryController,
    required RemoteAddressablesService remoteAddressablesService,
    required BookmarkController bookmarkController,
    required Future<void> Function(AnimationLibraryItem item) onViewIn3D,
  }) : _sequenceController = sequenceController,
       _sequenceHistoryController = sequenceHistoryController,
       _remoteAddressablesService = remoteAddressablesService,
       _bookmarkController = bookmarkController,
       _onViewIn3D = onViewIn3D {
    _sequenceController.addListener(_onDependenciesChanged);
    _remoteAddressablesService.addListener(_onDependenciesChanged);
    _bookmarkController.addListener(_onDependenciesChanged);
  }

  final SequenceController _sequenceController;
  final SequenceHistoryController _sequenceHistoryController;
  final RemoteAddressablesService _remoteAddressablesService;
  final BookmarkController _bookmarkController;
  final Future<void> Function(AnimationLibraryItem item) _onViewIn3D;
  static const SequenceConnectionPlanner _connectionPlanner =
      SequenceConnectionPlanner(maxBridgeAnimations: 5);

  String? _selectedCategoryId;

  static const List<RemoteAnimationCategory> _bootstrapCategories = [
    RemoteAnimationCategory(
      id: 'control',
      displayName: 'Control',
      manifest: '',
      version: '',
      count: 6,
    ),
    RemoteAnimationCategory(
      id: 'fundamentals',
      displayName: 'Fundamentals',
      manifest: '',
      version: '',
      count: 6,
    ),
  ];

  List<RemoteAnimationCategory> get categories {
    final liveCategories = {
      for (final category in _remoteAddressablesService.categories)
        category.id.toLowerCase(): category,
    };
    final merged = <RemoteAnimationCategory>[
      for (final fallback in _bootstrapCategories)
        liveCategories.remove(fallback.id.toLowerCase()) ?? fallback,
      ...liveCategories.values,
    ];
    return List.unmodifiable(merged);
  }

  String? get selectedCategoryId => _selectedCategoryId;
  bool get isLoadingMetadata =>
      _remoteAddressablesService.isInitializing ||
      (_selectedCategoryId != null &&
          _remoteAddressablesService.loadingCategoryIds.contains(
            _selectedCategoryId,
          ));

  int get metadataPlaceholderCount {
    if (!isLoadingMetadata) return 0;

    final categoryId = _selectedCategoryId;
    if (categoryId != null && categoryId.isNotEmpty) {
      final remoteExpected = _remoteAddressablesService
          .expectedAnimationCountForCategory(categoryId);
      final expected = remoteExpected > 0
          ? remoteExpected
          : categories
                    .where((category) => category.id == categoryId)
                    .map((category) => category.count)
                    .firstOrNull ??
                6;
      final loaded = _remoteAddressablesService.loadedAnimationCountForCategory(
        categoryId,
      );
      return (expected - loaded).clamp(0, 12);
    }

    final expected = _remoteAddressablesService.expectedAnimationCount;
    final loaded = _remoteAddressablesService.availableItems.length;
    if (expected == 0) return 6;
    return (expected - loaded).clamp(0, 12);
  }

  Future<void> selectCategory(String? categoryId) async {
    final liveCategory = categoryId == null
        ? null
        : _remoteAddressablesService.categories
              .where(
                (category) =>
                    category.id.toLowerCase() == categoryId.toLowerCase(),
              )
              .firstOrNull;
    final resolvedCategoryId = liveCategory?.id ?? categoryId;

    _selectedCategoryId = resolvedCategoryId;
    notifyListeners();

    if (resolvedCategoryId == null || resolvedCategoryId.isEmpty) return;
    if (liveCategory == null) return;

    await _remoteAddressablesService.loadCategory(resolvedCategoryId);
  }

  Future<void> loadAllCategories() async {
    for (final category in _remoteAddressablesService.categories) {
      await _remoteAddressablesService.loadCategory(category.id);
    }
  }

  Future<String?> getOrDownloadPreview(String? previewPath) {
    return _remoteAddressablesService.getOrDownloadPreview(previewPath);
  }

  String? getCachedPreviewPath(String? previewPath) {
    return _remoteAddressablesService.getCachedPreviewPath(previewPath);
  }

  List<LibraryDisplayItem> get allItems {
    final Map<String, LibraryDisplayItem> byAnimationName = {};

    for (final item in mockAnimationLibrary) {
      byAnimationName[item.animationName] = LibraryDisplayItem(
        item: item,
        isRemote: false,
        isInstalled: true,
        isDownloading: false,
      );
    }

    for (final item in _remoteAddressablesService.availableItems) {
      byAnimationName[item.animationName] = LibraryDisplayItem(
        item: item,
        isRemote: true,
        isInstalled: _remoteAddressablesService.isAnimationDownloaded(
          item.downloadKey,
        ),
        isDownloading: _remoteAddressablesService.isAnimationDownloading(
          item.downloadKey,
        ),
      );
    }

    return byAnimationName.values.toList()
      ..sort((a, b) => a.item.title.compareTo(b.item.title));
  }

  List<LibraryDisplayItem> get categoryFilteredItems {
    if (_selectedCategoryId == null || _selectedCategoryId!.isEmpty) {
      return allItems;
    }

    return allItems
        .where((entry) => entry.item.category == _selectedCategoryId)
        .toList();
  }

  List<LibraryDisplayItem> get bookmarkedItems {
    final liveItems = {
      for (final entry in allItems) entry.item.animationName: entry,
    };

    return _bookmarkController.items
        .map((snapshot) {
          final liveEntry = liveItems[snapshot.animationName];
          if (liveEntry != null) return liveEntry;

          return LibraryDisplayItem(
            item: snapshot,
            isRemote: snapshot.addressKey != null,
            isInstalled:
                snapshot.addressKey == null ||
                _remoteAddressablesService.isAnimationDownloaded(
                  snapshot.downloadKey,
                ),
            isDownloading: _remoteAddressablesService.isAnimationDownloading(
              snapshot.downloadKey,
            ),
          );
        })
        .toList(growable: false);
  }

  bool isBookmarked(AnimationLibraryItem item) {
    return _bookmarkController.isBookmarked(item);
  }

  Future<void> toggleBookmark(AnimationLibraryItem item) {
    return _bookmarkController.toggle(item);
  }

  List<LibraryDisplayItem> get recommendedNextItems {
    return categoryFilteredItems
        .where((entry) => _sequenceController.canAddAnimation(entry.item))
        .toList();
  }

  bool matchesSearch(LibraryDisplayItem entry, String query) {
    final normalizedQuery = query.trim().toLowerCase();

    if (normalizedQuery.isEmpty) return true;

    return entry.item.title.toLowerCase().contains(normalizedQuery) ||
        entry.item.animationName.toLowerCase().contains(normalizedQuery) ||
        entry.item.startPosition.toLowerCase().contains(normalizedQuery) ||
        entry.item.endPosition.toLowerCase().contains(normalizedQuery) ||
        (entry.item.category ?? '').toLowerCase().contains(normalizedQuery) ||
        entry.item.tags.any(
          (tag) => tag.toLowerCase().contains(normalizedQuery),
        );
  }

  String getPrimaryActionLabel(LibraryDisplayItem entry) {
    return getAddActionLabel(entry);
  }

  String getAddActionLabel(LibraryDisplayItem entry) {
    if (entry.isDownloading) return 'Downloading...';
    if (requiresDownload(entry)) return 'Download';
    return 'Add to timeline';
  }

  String getViewActionLabel(LibraryDisplayItem entry) {
    return 'View in 3D';
  }

  bool requiresDownload(LibraryDisplayItem entry) {
    return entry.isRemote && !entry.isInstalled;
  }

  Future<void> download(LibraryDisplayItem entry) async {
    if (entry.isDownloading || !requiresDownload(entry)) return;
    await _remoteAddressablesService.downloadAnimation(entry.item.downloadKey);
  }

  Future<void> performPrimaryAction(
    LibraryDisplayItem entry, {
    String? transitionId,
  }) async {
    if (entry.isDownloading) return;

    if (requiresDownload(entry)) {
      await _remoteAddressablesService.downloadAnimation(
        entry.item.downloadKey,
      );
      return;
    }

    final plan = planConnection(entry);
    if (!plan.canConnect) {
      throw StateError(
        'No Smart Connect route from ${plan.fromPosition} '
        'to ${plan.toPosition}.',
      );
    }

    _sequenceHistoryController.addAnimations([
      ...plan.bridgeAnimations,
      entry.item,
    ], transitionId: transitionId);
  }

  SequenceConnectionPlan planConnection(LibraryDisplayItem entry) {
    return _connectionPlanner.plan(
      currentEndPosition: _sequenceController.requiredNextStartPosition,
      selectedAnimation: entry.item,
      availableAnimations: allItems
          .where((candidate) => candidate.isInstalled)
          .map((candidate) => candidate.item),
    );
  }

  Future<void> performViewAction(LibraryDisplayItem entry) async {
    if (entry.isDownloading) return;

    if (requiresDownload(entry)) {
      await download(entry);
      return;
    }

    await _onViewIn3D(entry.item);
  }

  void _onDependenciesChanged() {
    notifyListeners();
  }

  @override
  void dispose() {
    _sequenceController.removeListener(_onDependenciesChanged);
    _remoteAddressablesService.removeListener(_onDependenciesChanged);
    _bookmarkController.removeListener(_onDependenciesChanged);
    super.dispose();
  }
}
