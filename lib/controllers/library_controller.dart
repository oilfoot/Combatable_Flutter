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

  SequenceController get sequenceController => _sequenceController;
  RemoteAddressablesService get remoteAddressablesService =>
      _remoteAddressablesService;

  List<RemoteAnimationCategory> get categories =>
      _remoteAddressablesService.categories;

  String? get selectedCategoryId => _selectedCategoryId;

  void selectCategory(String? categoryId) {
    _selectedCategoryId = categoryId;
    notifyListeners();
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
      final key = item.downloadKey;

      byAnimationName.putIfAbsent(
        item.animationName,
        () => LibraryDisplayItem(
          item: item,
          isRemote: true,
          isInstalled: _remoteAddressablesService.isAnimationDownloaded(key),
          isDownloading: _remoteAddressablesService.isAnimationDownloading(key),
        ),
      );
    }

    final items = byAnimationName.values.toList()
      ..sort(
        (a, b) =>
            a.item.title.toLowerCase().compareTo(b.item.title.toLowerCase()),
      );

    return items;
  }

  List<LibraryDisplayItem> get categoryFilteredItems {
    if (_selectedCategoryId == null || _selectedCategoryId!.isEmpty) {
      return allItems;
    }

    return allItems.where((entry) {
      return entry.item.category == _selectedCategoryId;
    }).toList();
  }

  List<LibraryDisplayItem> get recommendedNextItems {
    return categoryFilteredItems
        .where((entry) => _sequenceController.canAddAnimation(entry.item))
        .toList();
  }

  String? get requiredNextStartPosition =>
      _sequenceController.requiredNextStartPosition;

  bool canAdd(AnimationLibraryItem item) {
    return _sequenceController.canAddAnimation(item);
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

  Future<void> refreshLibrary() async {
    await _remoteAddressablesService.refreshLibrary();
  }

  bool matchesSearch(LibraryDisplayItem entry, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;

    return entry.item.title.toLowerCase().contains(q) ||
        entry.item.animationName.toLowerCase().contains(q) ||
        entry.item.startPosition.toLowerCase().contains(q) ||
        entry.item.endPosition.toLowerCase().contains(q) ||
        (entry.item.category ?? '').toLowerCase().contains(q) ||
        entry.item.tags.any((tag) => tag.toLowerCase().contains(q));
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
