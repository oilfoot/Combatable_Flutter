import 'dart:convert';
import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/animation_library_item.dart';
import 'unity_service.dart';

class RemoteAnimationCategory {
  const RemoteAnimationCategory({
    required this.id,
    required this.displayName,
    required this.manifest,
    required this.version,
    required this.count,
  });

  final String id;
  final String displayName;
  final String manifest;
  final String version;
  final int count;
}

class RemoteAddressablesService extends ChangeNotifier {
  RemoteAddressablesService({
    required UnityService unityService,
    FirebaseStorage? firebaseStorage,
  }) : _unityService = unityService,
       _firebaseStorage = firebaseStorage ?? FirebaseStorage.instance;

  final UnityService _unityService;
  final FirebaseStorage _firebaseStorage;

  static const String _remoteFolder = 'addressables/iOS';
  static const String _mainManifestFileName = 'main_manifest.json';
  static const Duration _mainManifestRefreshInterval = Duration(hours: 6);

  String _status = 'Remote library not loaded yet.';
  String? _addressablesDirPath;
  String? _catalogPath;

  bool _isInitializing = false;
  bool _isSendingCatalog = false;
  bool _isUnityPrepared = false;

  _MainManifest? _manifest;

  final List<RemoteAnimationCategory> _categories = [];
  final List<AnimationLibraryItem> _availableItems = [];
  final List<AnimationLibraryItem> _downloadedItems = [];
  final List<String> _downloadedJsonPaths = [];

  final Set<String> _downloadedKeys = {};
  final Set<String> _downloadingKeys = {};
  final Set<String> _loadedCategoryIds = {};
  final Set<String> _loadingCategoryIds = {};
  final Map<String, Future<String?>> _previewDownloadFutures = {};
  final Map<String, String> _cachedPreviewPaths = {};

  String get status => _status;
  String? get addressablesDirPath => _addressablesDirPath;
  String? get catalogPath => _catalogPath;

  bool get isInitializing => _isInitializing;
  bool get isSendingCatalog => _isSendingCatalog;

  List<RemoteAnimationCategory> get categories =>
      List.unmodifiable(_categories);
  Set<String> get loadedCategoryIds => Set.unmodifiable(_loadedCategoryIds);
  Set<String> get loadingCategoryIds => Set.unmodifiable(_loadingCategoryIds);
  List<AnimationLibraryItem> get availableItems =>
      List.unmodifiable(_availableItems);
  List<AnimationLibraryItem> get downloadedItems =>
      List.unmodifiable(_downloadedItems);
  List<String> get downloadedJsonPaths =>
      List.unmodifiable(_downloadedJsonPaths);
  int get expectedAnimationCount =>
      _categories.fold(0, (total, category) => total + category.count);
  int expectedAnimationCountForCategory(String categoryId) {
    for (final category in _categories) {
      if (category.id == categoryId) return category.count;
    }
    return 0;
  }

  int loadedAnimationCountForCategory(String categoryId) {
    return _availableItems.where((item) => item.category == categoryId).length;
  }

  bool get hasDownloadedContent =>
      _catalogPath != null &&
      _catalogPath!.isNotEmpty &&
      _downloadedJsonPaths.isNotEmpty;

  bool isAnimationDownloaded(String addressKey) {
    return _downloadedKeys.contains(addressKey.trim());
  }

  bool isAnimationDownloading(String addressKey) {
    return _downloadingKeys.contains(addressKey.trim());
  }

  String? getCachedPreviewPath(String? previewPath) {
    final trimmedPreviewPath = previewPath?.trim();

    if (trimmedPreviewPath == null || trimmedPreviewPath.isEmpty) {
      return null;
    }

    final rememberedPath = _cachedPreviewPaths[trimmedPreviewPath];
    if (rememberedPath != null && File(rememberedPath).existsSync()) {
      return rememberedPath;
    }

    if (trimmedPreviewPath.startsWith('/')) {
      final file = File(trimmedPreviewPath);
      return file.existsSync() ? file.path : null;
    }

    if (trimmedPreviewPath.startsWith('http://') ||
        trimmedPreviewPath.startsWith('https://')) {
      return null;
    }

    final lower = trimmedPreviewPath.toLowerCase();
    final isSupportedPreview =
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.mp4');

    if (!isSupportedPreview) {
      return null;
    }

    final addressablesDirPath = _addressablesDirPath;

    if (addressablesDirPath == null || addressablesDirPath.isEmpty) {
      return null;
    }

    final filename = _previewCacheFilename(trimmedPreviewPath);

    if (filename.isEmpty) {
      return null;
    }

    final localPreviewFile = File('$addressablesDirPath/previews/$filename');
    if (localPreviewFile.existsSync()) {
      _cachedPreviewPaths[trimmedPreviewPath] = localPreviewFile.path;
      return localPreviewFile.path;
    }

    final legacyFilename = trimmedPreviewPath.split('/').last.trim();
    final legacyFile = File('$addressablesDirPath/previews/$legacyFilename');
    if (legacyFile.existsSync()) {
      _cachedPreviewPaths[trimmedPreviewPath] = legacyFile.path;
      return legacyFile.path;
    }
    return null;
  }

  Future<String?> getOrDownloadPreview(String? previewPath) async {
    final trimmedPreviewPath = previewPath?.trim();

    if (trimmedPreviewPath == null || trimmedPreviewPath.isEmpty) {
      return null;
    }

    final cachedPreviewPath = getCachedPreviewPath(trimmedPreviewPath);

    if (cachedPreviewPath != null) {
      return cachedPreviewPath;
    }

    if (trimmedPreviewPath.startsWith('/')) {
      final file = File(trimmedPreviewPath);
      return await file.exists() ? file.path : null;
    }

    if (trimmedPreviewPath.startsWith('http://') ||
        trimmedPreviewPath.startsWith('https://')) {
      return trimmedPreviewPath;
    }

    final lower = trimmedPreviewPath.toLowerCase();
    final isSupportedPreview =
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.mp4');

    if (!isSupportedPreview) {
      return null;
    }

    final existingFuture = _previewDownloadFutures[trimmedPreviewPath];

    if (existingFuture != null) {
      return existingFuture;
    }

    final future = _downloadPreviewToCache(trimmedPreviewPath);
    _previewDownloadFutures[trimmedPreviewPath] = future;

    try {
      return await future;
    } finally {
      _previewDownloadFutures.remove(trimmedPreviewPath);
    }
  }

  Future<void> initializeLibrary({bool forceRefresh = false}) async {
    if (_isInitializing) return;

    _isInitializing = true;
    _status = 'Loading animation library...';
    notifyListeners();

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final addressablesDir = Directory('${appDir.path}/addressables');

      if (!await addressablesDir.exists()) {
        await addressablesDir.create(recursive: true);
      }

      _addressablesDirPath = addressablesDir.path;

      final restoredFromCache = await _tryRestoreStateFromDisk(
        addressablesDir: addressablesDir,
      );

      if (restoredFromCache) {
        _status =
            'Animation library ready from cache.\n'
            'Available: ${_availableItems.length}\n'
            'Downloaded: ${_downloadedItems.length}';
        notifyListeners();
      }

      await _downloadMainManifestToLocal(
        addressablesDir: addressablesDir,
        forceRefresh: forceRefresh,
      );
      await _restoreStateFromDisk(addressablesDir: addressablesDir);
      await _loadMissingCategoryManifests();

      _status =
          'Remote library ready.\n'
          'Available: ${_availableItems.length}\n'
          'Downloaded: ${_downloadedItems.length}';
    } catch (e) {
      if (_manifest != null ||
          _availableItems.isNotEmpty ||
          _categories.isNotEmpty) {
        _status =
            'Using cached library. Remote refresh failed:\n$e\n'
            'Available: ${_availableItems.length}\n'
            'Downloaded: ${_downloadedItems.length}';
      } else {
        _status = 'Failed to load remote library:\n$e';
      }
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  Future<void> refreshLibrary() async {
    await initializeLibrary(forceRefresh: true);
  }

  Future<void> _loadMissingCategoryManifests() async {
    for (final category in List<RemoteAnimationCategory>.of(_categories)) {
      if (_loadedCategoryIds.contains(category.id)) continue;
      try {
        await loadCategory(category.id);
      } catch (error) {
        debugPrint(
          '[RemoteAddressablesService] Failed to preload '
          '${category.id}: $error',
        );
      }
    }
  }

  Future<void> loadCategory(String categoryId) async {
    final trimmedCategoryId = categoryId.trim();

    if (trimmedCategoryId.isEmpty) return;
    if (_loadedCategoryIds.contains(trimmedCategoryId)) return;
    if (_loadingCategoryIds.contains(trimmedCategoryId)) return;

    final manifest = _manifest;

    if (manifest == null) {
      throw Exception('Main manifest is not loaded.');
    }

    _CategoryManifestRef? categoryRef;

    for (final category in manifest.categories) {
      if (category.id == trimmedCategoryId) {
        categoryRef = category;
        break;
      }
    }

    if (categoryRef == null) {
      throw Exception('Category "$trimmedCategoryId" was not found.');
    }

    _loadingCategoryIds.add(trimmedCategoryId);
    _status = 'Loading ${categoryRef.displayName}...';
    notifyListeners();

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final addressablesDir = Directory('${appDir.path}/addressables');

      if (!await addressablesDir.exists()) {
        await addressablesDir.create(recursive: true);
      }

      _addressablesDirPath = addressablesDir.path;

      final localCategoryFile = File(
        '${addressablesDir.path}/${categoryRef.manifest}',
      );

      await localCategoryFile.parent.create(recursive: true);

      await _downloadFileAtomically(
        reference: _firebaseStorage.ref(
          '$_remoteFolder/${categoryRef.manifest}',
        ),
        destination: localCategoryFile,
        validateContent: (content) {
          _parseCategoryManifest(content);
        },
      );

      final categoryContent = await localCategoryFile.readAsString();
      final loadedEntries = _parseCategoryManifest(categoryContent);

      final existingEntries = manifest.entries
          .where((entry) => entry.category != trimmedCategoryId)
          .toList();

      existingEntries.addAll(loadedEntries);

      _manifest = manifest.copyWith(entries: existingEntries);

      _availableItems
        ..clear()
        ..addAll(existingEntries.map(_toLibraryItem));

      for (final entry in loadedEntries) {
        final localStepsFile = _localFileForRemotePath(
          addressablesDir: addressablesDir,
          remotePath: entry.stepsFile,
        );

        final localBundleFile = _localBundleFileForCatalog(
          addressablesDir: addressablesDir,
          remotePath: entry.bundle,
        );

        final hasSteps = await localStepsFile.exists();
        final hasBundle = await localBundleFile.exists();

        if (hasSteps && hasBundle) {
          _downloadedKeys.add(entry.id);

          if (!_downloadedJsonPaths.contains(localStepsFile.path)) {
            _downloadedJsonPaths.add(localStepsFile.path);
          }
        }
      }

      _rebuildDownloadedItems();
      _loadedCategoryIds.add(trimmedCategoryId);

      _status =
          '${categoryRef.displayName} ready.\n'
          'Available: ${_availableItems.length}\n'
          'Downloaded: ${_downloadedItems.length}';
    } catch (e) {
      _status = 'Failed to load category "$trimmedCategoryId":\n$e';
      rethrow;
    } finally {
      _loadingCategoryIds.remove(trimmedCategoryId);
      notifyListeners();
    }
  }

  Future<void> downloadAnimation(String addressKey) async {
    final trimmedKey = addressKey.trim();

    if (trimmedKey.isEmpty) {
      throw Exception('addressKey is empty.');
    }

    if (_downloadingKeys.contains(trimmedKey)) return;
    if (isAnimationDownloaded(trimmedKey)) return;

    final entry = _findEntry(trimmedKey);

    if (entry == null) {
      throw Exception('No manifest entry found for "$trimmedKey".');
    }

    _downloadingKeys.add(trimmedKey);
    _status = 'Downloading ${entry.displayName}...';
    notifyListeners();

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final addressablesDir = Directory('${appDir.path}/addressables');

      if (!await addressablesDir.exists()) {
        await addressablesDir.create(recursive: true);
      }

      _addressablesDirPath = addressablesDir.path;

      await _ensureCoreFilesDownloaded(addressablesDir: addressablesDir);

      final localStepsFile = _localFileForRemotePath(
        addressablesDir: addressablesDir,
        remotePath: entry.stepsFile,
      );

      await localStepsFile.parent.create(recursive: true);

      await _firebaseStorage
          .ref(_storageRefPath(entry.stepsFile))
          .writeToFile(localStepsFile);

      final localBundleFile = _localBundleFileForCatalog(
        addressablesDir: addressablesDir,
        remotePath: entry.bundle,
      );

      await localBundleFile.parent.create(recursive: true);

      await _firebaseStorage
          .ref(_storageRefPath(entry.bundle))
          .writeToFile(localBundleFile);

      _downloadedKeys.add(trimmedKey);

      if (!_downloadedJsonPaths.contains(localStepsFile.path)) {
        _downloadedJsonPaths.add(localStepsFile.path);
      }

      _rebuildDownloadedItems();

      _isUnityPrepared = false;

      _status =
          'Downloaded ${entry.displayName}.\n'
          'Available: ${_availableItems.length}\n'
          'Downloaded: ${_downloadedItems.length}';

      notifyListeners();
    } catch (e) {
      _status = 'Failed to download $trimmedKey:\n$e';
      rethrow;
    } finally {
      _downloadingKeys.remove(trimmedKey);
      notifyListeners();
    }
  }

  Future<void> ensureUnityPrepared() async {
    if (_isUnityPrepared) return;
    if (!hasDownloadedContent) return;

    await loadCatalogInUnity();
  }

  Future<void> loadCatalogInUnity() async {
    if (_isSendingCatalog) return;

    if (_catalogPath == null || _catalogPath!.isEmpty) {
      _status = 'No catalog path available yet.';
      notifyListeners();
      return;
    }

    _isSendingCatalog = true;
    _status = 'Sending catalog path to Unity...';
    notifyListeners();

    try {
      await _unityService.resumeUnity();

      await _unityService.loadLocalAddressablesCatalog(
        catalogPath: _catalogPath!,
      );

      if (_downloadedJsonPaths.isNotEmpty) {
        await _unityService.registerDownloadedJsonFiles(
          jsonPaths: _downloadedJsonPaths,
        );
      }

      _isUnityPrepared = true;

      _status =
          'Unity prepared.\n'
          'Catalog: $_catalogPath\n'
          'Registered ${_downloadedJsonPaths.length} downloaded JSON file(s).';
    } catch (e) {
      _isUnityPrepared = false;
      _status = 'Failed to prepare Unity:\n$e';
    } finally {
      _isSendingCatalog = false;
      notifyListeners();
    }
  }

  void markUnityStateDirty() {
    _isUnityPrepared = false;
  }

  Future<bool> _tryRestoreStateFromDisk({
    required Directory addressablesDir,
  }) async {
    final manifestFile = File('${addressablesDir.path}/$_mainManifestFileName');

    if (!await manifestFile.exists()) {
      return false;
    }

    try {
      await _restoreStateFromDisk(addressablesDir: addressablesDir);
      return true;
    } catch (e) {
      debugPrint('[RemoteAddressablesService] Failed to restore cache: $e');
      return false;
    }
  }

  Future<void> _downloadMainManifestToLocal({
    required Directory addressablesDir,
    required bool forceRefresh,
  }) async {
    final manifestRef = _firebaseStorage.ref(
      '$_remoteFolder/$_mainManifestFileName',
    );

    final manifestLocalFile = File(
      '${addressablesDir.path}/$_mainManifestFileName',
    );

    if (!forceRefresh && await manifestLocalFile.exists()) {
      final modifiedAt = await manifestLocalFile.lastModified();
      if (DateTime.now().difference(modifiedAt) <
          _mainManifestRefreshInterval) {
        return;
      }
    }

    await _downloadFileAtomically(
      reference: manifestRef,
      destination: manifestLocalFile,
      validateContent: (content) {
        _parseMainManifest(content);
      },
    );

    if (!await manifestLocalFile.exists()) {
      throw Exception('Main manifest file was not downloaded.');
    }

    final manifestContent = await manifestLocalFile.readAsString();
    _manifest = _parseMainManifest(manifestContent);
  }

  Future<void> _ensureCoreFilesDownloaded({
    required Directory addressablesDir,
  }) async {
    final manifest = _manifest;

    if (manifest == null) {
      throw Exception('Main manifest is not loaded.');
    }

    final catalogLocalFile = File(
      '${addressablesDir.path}/${manifest.catalogFile}',
    );

    if (!await catalogLocalFile.exists()) {
      await _firebaseStorage
          .ref('$_remoteFolder/${manifest.catalogFile}')
          .writeToFile(catalogLocalFile);
    }

    _catalogPath = catalogLocalFile.path;

    if (manifest.hashFile.trim().isNotEmpty) {
      final hashLocalFile = File(
        '${addressablesDir.path}/${manifest.hashFile}',
      );

      if (!await hashLocalFile.exists()) {
        await _firebaseStorage
            .ref('$_remoteFolder/${manifest.hashFile}')
            .writeToFile(hashLocalFile);
      }
    }
  }

  Future<void> _restoreStateFromDisk({
    required Directory addressablesDir,
  }) async {
    final manifestFile = File('${addressablesDir.path}/$_mainManifestFileName');

    if (!await manifestFile.exists()) {
      throw Exception('Local main manifest file does not exist.');
    }

    final manifestContent = await manifestFile.readAsString();
    final mainManifest = _parseMainManifest(manifestContent);

    _manifest = mainManifest;

    final allEntries = <_AnimationManifestEntry>[];

    _loadedCategoryIds.clear();

    for (final category in mainManifest.categories) {
      final categoryFile = File('${addressablesDir.path}/${category.manifest}');

      if (!await categoryFile.exists()) {
        continue;
      }

      final categoryContent = await categoryFile.readAsString();
      final localCategoryVersion = _parseCategoryManifestVersion(
        categoryContent,
      );

      if (category.version.isNotEmpty &&
          localCategoryVersion != category.version) {
        await categoryFile.delete();
        continue;
      }

      final entries = _parseCategoryManifest(categoryContent);

      allEntries.addAll(entries);
      _loadedCategoryIds.add(category.id);
    }

    _manifest = mainManifest.copyWith(entries: allEntries);

    _categories
      ..clear()
      ..addAll(
        mainManifest.categories.map(
          (category) => RemoteAnimationCategory(
            id: category.id,
            displayName: category.displayName,
            manifest: category.manifest,
            version: category.version,
            count: category.count,
          ),
        ),
      );

    _availableItems
      ..clear()
      ..addAll(allEntries.map(_toLibraryItem));

    final catalogFile = File(
      '${addressablesDir.path}/${mainManifest.catalogFile}',
    );
    _catalogPath = await catalogFile.exists() ? catalogFile.path : null;

    _downloadedKeys.clear();
    _downloadedJsonPaths.clear();
    _loadingCategoryIds.clear();

    for (final entry in allEntries) {
      final localStepsFile = _localFileForRemotePath(
        addressablesDir: addressablesDir,
        remotePath: entry.stepsFile,
      );

      final localBundleFile = _localBundleFileForCatalog(
        addressablesDir: addressablesDir,
        remotePath: entry.bundle,
      );

      final hasSteps = await localStepsFile.exists();
      final hasBundle = await localBundleFile.exists();

      if (hasSteps && hasBundle) {
        _downloadedKeys.add(entry.id);
        _downloadedJsonPaths.add(localStepsFile.path);
      }
    }

    _rebuildDownloadedItems();
    _isUnityPrepared = false;
  }

  void _rebuildDownloadedItems() {
    final manifest = _manifest;

    if (manifest == null) {
      _downloadedItems.clear();
      return;
    }

    _downloadedItems
      ..clear()
      ..addAll(
        manifest.entries
            .where((entry) => _downloadedKeys.contains(entry.id))
            .map(_toLibraryItem),
      );
  }

  _AnimationManifestEntry? _findEntry(String addressKey) {
    final manifest = _manifest;

    if (manifest == null) return null;

    for (final entry in manifest.entries) {
      if (entry.id == addressKey) {
        return entry;
      }
    }

    return null;
  }

  AnimationLibraryItem _toLibraryItem(_AnimationManifestEntry entry) {
    return AnimationLibraryItem(
      title: entry.displayName,
      animationName: entry.animationName,
      addressKey: entry.id,
      description: entry.description,
      category: entry.category,
      tags: entry.tags,
      startPosition: entry.startPosition,
      endPosition: entry.endPosition,
      previewPath: entry.preview,
    );
  }

  _MainManifest _parseMainManifest(String jsonString) {
    final decoded = jsonDecode(jsonString);

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Main manifest must be a JSON object.');
    }

    final version = (decoded['version'] ?? '').toString().trim();
    final platform = (decoded['platform'] ?? '').toString().trim();
    final catalogFile = (decoded['catalogFile'] ?? '').toString().trim();
    final hashFile = (decoded['hashFile'] ?? '').toString().trim();

    if (catalogFile.isEmpty) {
      throw Exception('Main manifest is missing catalogFile.');
    }

    final rawCategories = decoded['categories'];

    if (rawCategories is! List) {
      throw Exception('Main manifest is missing categories array.');
    }

    final categories = rawCategories.map<_CategoryManifestRef>((raw) {
      if (raw is! Map<String, dynamic>) {
        throw Exception('Category entry is not a JSON object.');
      }

      final id = (raw['id'] ?? '').toString().trim();
      final displayName = (raw['displayName'] ?? '').toString().trim();
      final manifest = (raw['manifest'] ?? '').toString().trim();
      final version = (raw['version'] ?? '').toString().trim();
      final countRaw = raw['count'];

      if (id.isEmpty) {
        throw Exception('Category is missing id.');
      }

      if (manifest.isEmpty) {
        throw Exception('Category "$id" is missing manifest path.');
      }

      return _CategoryManifestRef(
        id: id,
        displayName: displayName.isEmpty ? id : displayName,
        manifest: manifest,
        version: version,
        count: countRaw is int ? countRaw : int.tryParse('$countRaw') ?? 0,
      );
    }).toList();

    return _MainManifest(
      version: version,
      platform: platform,
      catalogFile: catalogFile,
      hashFile: hashFile,
      categories: categories,
      entries: const [],
    );
  }

  String _parseCategoryManifestVersion(String jsonString) {
    final decoded = jsonDecode(jsonString);

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Category manifest must be a JSON object.');
    }

    return (decoded['version'] ?? '').toString().trim();
  }

  List<_AnimationManifestEntry> _parseCategoryManifest(String jsonString) {
    final decoded = jsonDecode(jsonString);

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Category manifest must be a JSON object.');
    }

    final category = (decoded['category'] ?? '').toString().trim();
    final rawAnimations = decoded['animations'];

    if (rawAnimations is! List) {
      throw Exception('Category manifest is missing animations array.');
    }

    return rawAnimations.map<_AnimationManifestEntry>((raw) {
      if (raw is! Map<String, dynamic>) {
        throw Exception('Animation entry is not a JSON object.');
      }

      final id = (raw['id'] ?? '').toString().trim();
      final animationName = (raw['animationName'] ?? '').toString().trim();
      final displayName = (raw['displayName'] ?? '').toString().trim();
      final description = (raw['description'] ?? '').toString().trim();
      final entryCategory = (raw['category'] ?? category).toString().trim();
      final startPosition = (raw['startPosition'] ?? '').toString().trim();
      final endPosition = (raw['endPosition'] ?? '').toString().trim();
      final stepsFile = (raw['stepsFile'] ?? '').toString().trim();
      final bundle = (raw['bundle'] ?? '').toString().trim();
      final preview = raw['preview']?.toString().trim();

      final rawTags = raw['tags'];
      final tags = rawTags is List
          ? rawTags.map((tag) => tag.toString()).toList()
          : <String>[];

      if (id.isEmpty) {
        throw Exception('Animation entry is missing id.');
      }

      if (animationName.isEmpty) {
        throw Exception('Animation "$id" is missing animationName.');
      }

      if (stepsFile.isEmpty) {
        throw Exception('Animation "$id" is missing stepsFile.');
      }

      if (bundle.isEmpty) {
        throw Exception('Animation "$id" is missing bundle.');
      }

      return _AnimationManifestEntry(
        id: id,
        displayName: displayName.isEmpty ? id : displayName,
        description: description,
        category: entryCategory,
        tags: tags,
        startPosition: startPosition,
        endPosition: endPosition,
        stepsFile: stepsFile,
        bundle: bundle,
        preview: preview == null || preview.isEmpty ? null : preview,
        animationName: animationName,
      );
    }).toList();
  }

  String _storageRefPath(String path) {
    if (path.startsWith(_remoteFolder)) {
      return path;
    }

    return '$_remoteFolder/$path';
  }

  Future<String?> _downloadPreviewToCache(String remotePreviewPath) async {
    final appDir = await getApplicationDocumentsDirectory();
    final addressablesDir = Directory('${appDir.path}/addressables');
    final previewsDir = Directory('${addressablesDir.path}/previews');

    if (!await previewsDir.exists()) {
      await previewsDir.create(recursive: true);
    }

    final filename = _previewCacheFilename(remotePreviewPath);

    if (filename.trim().isEmpty) {
      return null;
    }

    final localPreviewFile = File('${previewsDir.path}/$filename');

    if (await localPreviewFile.exists()) {
      _cachedPreviewPaths[remotePreviewPath] = localPreviewFile.path;
      return localPreviewFile.path;
    }

    final legacyFilename = remotePreviewPath.split('/').last;
    final legacyFile = File('${previewsDir.path}/$legacyFilename');
    if (await legacyFile.exists()) {
      _cachedPreviewPaths[remotePreviewPath] = legacyFile.path;
      return legacyFile.path;
    }

    await _downloadFileAtomically(
      reference: _firebaseStorage.ref(_storageRefPath(remotePreviewPath)),
      destination: localPreviewFile,
    );

    if (await localPreviewFile.exists()) {
      _cachedPreviewPaths[remotePreviewPath] = localPreviewFile.path;
      return localPreviewFile.path;
    }

    return null;
  }

  String _previewCacheFilename(String remotePreviewPath) {
    return remotePreviewPath.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  }

  Future<void> _downloadFileAtomically({
    required Reference reference,
    required File destination,
    void Function(String content)? validateContent,
  }) async {
    await destination.parent.create(recursive: true);
    final partialFile = File('${destination.path}.part');

    try {
      if (await partialFile.exists()) await partialFile.delete();
      await reference.writeToFile(partialFile);
      if (await partialFile.length() == 0) {
        throw const FileSystemException('Downloaded file is empty.');
      }
      if (validateContent != null) {
        validateContent(await partialFile.readAsString());
      }
      if (await destination.exists()) await destination.delete();
      await partialFile.rename(destination.path);
    } catch (_) {
      if (await partialFile.exists()) await partialFile.delete();
      rethrow;
    }
  }

  File _localFileForRemotePath({
    required Directory addressablesDir,
    required String remotePath,
  }) {
    var localRelativePath = remotePath;

    if (localRelativePath.startsWith('$_remoteFolder/')) {
      localRelativePath = localRelativePath.replaceFirst('$_remoteFolder/', '');
    }

    return File('${addressablesDir.path}/$localRelativePath');
  }

  File _localBundleFileForCatalog({
    required Directory addressablesDir,
    required String remotePath,
  }) {
    final filename = remotePath.split('/').last;
    return File('${addressablesDir.path}/$filename');
  }
}

class _MainManifest {
  const _MainManifest({
    required this.version,
    required this.platform,
    required this.catalogFile,
    required this.hashFile,
    required this.categories,
    required this.entries,
  });

  final String version;
  final String platform;
  final String catalogFile;
  final String hashFile;
  final List<_CategoryManifestRef> categories;
  final List<_AnimationManifestEntry> entries;

  _MainManifest copyWith({List<_AnimationManifestEntry>? entries}) {
    return _MainManifest(
      version: version,
      platform: platform,
      catalogFile: catalogFile,
      hashFile: hashFile,
      categories: categories,
      entries: entries ?? this.entries,
    );
  }
}

class _CategoryManifestRef {
  const _CategoryManifestRef({
    required this.id,
    required this.displayName,
    required this.manifest,
    required this.version,
    required this.count,
  });

  final String id;
  final String displayName;
  final String manifest;
  final String version;
  final int count;
}

class _AnimationManifestEntry {
  const _AnimationManifestEntry({
    required this.id,
    required this.displayName,
    required this.description,
    required this.category,
    required this.tags,
    required this.startPosition,
    required this.endPosition,
    required this.stepsFile,
    required this.bundle,
    required this.preview,
    required this.animationName,
  });

  final String id;
  final String displayName;
  final String description;
  final String category;
  final List<String> tags;
  final String startPosition;
  final String endPosition;
  final String stepsFile;
  final String bundle;
  final String? preview;
  final String animationName;
}
