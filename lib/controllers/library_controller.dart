import 'package:flutter/foundation.dart';

import '../data/mock_animation_library.dart';
import '../models/animation_library_item.dart';
import '../services/remote_addressables_service.dart';
import 'sequence_controller.dart';

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
    required RemoteAddressablesService remoteAddressablesService,
  }) : _sequenceController = sequenceController,
       _remoteAddressablesService = remoteAddressablesService {
    _sequenceController.addListener(_onDependenciesChanged);
    _remoteAddressablesService.addListener(_onDependenciesChanged);
  }

  final SequenceController _sequenceController;
  final RemoteAddressablesService _remoteAddressablesService;

  String? _selectedCategoryId;

  List<RemoteAnimationCategory> get categories =>
      _remoteAddressablesService.categories;

  String? get selectedCategoryId => _selectedCategoryId;

  Future<void> selectCategory(String? categoryId) async {
    _selectedCategoryId = categoryId;
    notifyListeners();

    if (categoryId == null || categoryId.isEmpty) return;

    await _remoteAddressablesService.loadCategory(categoryId);
  }

  Future<void> loadAllCategories() async {
    for (final category in categories) {
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
    if (entry.isDownloading) return 'Downloading...';
    if (!entry.isRemote) return 'Add';
    if (entry.isInstalled) return 'Add';
    return 'Download & Add';
  }

  Future<void> performPrimaryAction(LibraryDisplayItem entry) async {
    if (entry.isDownloading) return;

    if (entry.isRemote && !entry.isInstalled) {
      await _remoteAddressablesService.downloadAnimation(
        entry.item.downloadKey,
      );
    }

    _sequenceController.addAnimationItem(entry.item);
  }

  void _onDependenciesChanged() {
    notifyListeners();
  }

  @override
  void dispose() {
    _sequenceController.removeListener(_onDependenciesChanged);
    _remoteAddressablesService.removeListener(_onDependenciesChanged);
    super.dispose();
  }
}
