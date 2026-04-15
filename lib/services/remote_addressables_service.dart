import 'dart:convert';
import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/animation_library_item.dart';
import 'unity_service.dart';

class RemoteAddressablesService extends ChangeNotifier {
  RemoteAddressablesService({
    required UnityService unityService,
    FirebaseStorage? firebaseStorage,
  }) : _unityService = unityService,
       _firebaseStorage = firebaseStorage ?? FirebaseStorage.instance;

  final UnityService _unityService;
  final FirebaseStorage _firebaseStorage;

  static const String _remoteFolder = 'addressables/iOS';
  static const String _manifestFileName = 'addressables_manifest.json';

  String _status = 'Remote library not loaded yet.';
  String? _addressablesDirPath;
  String? _catalogPath;
  bool _isInitializing = false;
  bool _isSendingCatalog = false;
  bool _isUnityPrepared = false;

  _AddressablesManifest? _manifest;

  final List<AnimationLibraryItem> _availableItems = <AnimationLibraryItem>[];
  final List<AnimationLibraryItem> _downloadedItems = <AnimationLibraryItem>[];
  final List<String> _downloadedJsonPaths = <String>[];

  final Set<String> _downloadedKeys = <String>{};
  final Set<String> _downloadingKeys = <String>{};

  String get status => _status;
  String? get addressablesDirPath => _addressablesDirPath;
  String? get catalogPath => _catalogPath;
  bool get isInitializing => _isInitializing;
  bool get isSendingCatalog => _isSendingCatalog;

  List<AnimationLibraryItem> get availableItems =>
      List<AnimationLibraryItem>.unmodifiable(_availableItems);

  List<AnimationLibraryItem> get downloadedItems =>
      List<AnimationLibraryItem>.unmodifiable(_downloadedItems);

  List<String> get downloadedJsonPaths =>
      List<String>.unmodifiable(_downloadedJsonPaths);

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

  Future<void> initializeLibrary() async {
    if (_isInitializing) return;

    _isInitializing = true;
    _status = 'Loading remote animation library...';
    notifyListeners();

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final addressablesDir = Directory('${appDir.path}/addressables');

      if (!await addressablesDir.exists()) {
        await addressablesDir.create(recursive: true);
      }

      _addressablesDirPath = addressablesDir.path;

      await _downloadManifestToLocal(addressablesDir: addressablesDir);
      await _restoreStateFromDisk(addressablesDir: addressablesDir);

      _status =
          'Remote library ready.\n'
          'Available: ${_availableItems.length}\n'
          'Downloaded: ${_downloadedItems.length}';
    } catch (e) {
      _status = 'Failed to load remote library:\n$e';
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  Future<void> refreshLibrary() async {
    await initializeLibrary();
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
    _status = 'Downloading ${entry.title}...';
    notifyListeners();

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final addressablesDir = Directory('${appDir.path}/addressables');

      if (!await addressablesDir.exists()) {
        await addressablesDir.create(recursive: true);
      }

      _addressablesDirPath = addressablesDir.path;

      await _ensureCoreFilesDownloaded(addressablesDir: addressablesDir);

      final localJsonFile = File('${addressablesDir.path}/${entry.jsonFile}');
      await _firebaseStorage
          .ref('$_remoteFolder/${entry.jsonFile}')
          .writeToFile(localJsonFile);

      final localBundleFile = File(
        '${addressablesDir.path}/${entry.bundleFile}',
      );
      await _firebaseStorage
          .ref('$_remoteFolder/${entry.bundleFile}')
          .writeToFile(localBundleFile);

      _downloadedKeys.add(trimmedKey);

      if (!_downloadedJsonPaths.contains(localJsonFile.path)) {
        _downloadedJsonPaths.add(localJsonFile.path);
      }

      _rebuildDownloadedItems();

      _isUnityPrepared = false;

      _status =
          'Downloaded ${entry.title}.\n'
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

  Future<void> _downloadManifestToLocal({
    required Directory addressablesDir,
  }) async {
    final manifestRef = _firebaseStorage.ref(
      '$_remoteFolder/$_manifestFileName',
    );
    final manifestLocalFile = File(
      '${addressablesDir.path}/$_manifestFileName',
    );

    await manifestRef.writeToFile(manifestLocalFile);

    if (!await manifestLocalFile.exists()) {
      throw Exception('Manifest file was not downloaded.');
    }
  }

  Future<void> _ensureCoreFilesDownloaded({
    required Directory addressablesDir,
  }) async {
    final manifest = _manifest;
    if (manifest == null) {
      throw Exception('Manifest is not loaded.');
    }

    final manifestLocalFile = File(
      '${addressablesDir.path}/$_manifestFileName',
    );
    if (!await manifestLocalFile.exists()) {
      await _downloadManifestToLocal(addressablesDir: addressablesDir);
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
    final manifestFile = File('${addressablesDir.path}/$_manifestFileName');
    if (!await manifestFile.exists()) {
      throw Exception('Local manifest file does not exist.');
    }

    final manifestContent = await manifestFile.readAsString();
    final manifest = _parseManifest(manifestContent);
    _manifest = manifest;

    _availableItems
      ..clear()
      ..addAll(
        manifest.entries.map((entry) {
          return AnimationLibraryItem(
            title: entry.title,
            animationName: entry.animationName,
            startPosition: entry.startPosition,
            endPosition: entry.endPosition,
          );
        }),
      );

    final catalogFile = File('${addressablesDir.path}/${manifest.catalogFile}');
    _catalogPath = await catalogFile.exists() ? catalogFile.path : null;

    _downloadedKeys.clear();
    _downloadedJsonPaths.clear();

    for (final entry in manifest.entries) {
      final localJsonFile = File('${addressablesDir.path}/${entry.jsonFile}');
      final localBundleFile = File(
        '${addressablesDir.path}/${entry.bundleFile}',
      );

      final hasJson = await localJsonFile.exists();
      final hasBundle = await localBundleFile.exists();

      if (hasJson && hasBundle) {
        _downloadedKeys.add(entry.addressKey);
        _downloadedJsonPaths.add(localJsonFile.path);
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
            .where((entry) => _downloadedKeys.contains(entry.addressKey))
            .map(
              (entry) => AnimationLibraryItem(
                title: entry.title,
                animationName: entry.animationName,
                startPosition: entry.startPosition,
                endPosition: entry.endPosition,
              ),
            ),
      );
  }

  _AddressablesManifestEntry? _findEntry(String addressKey) {
    final manifest = _manifest;
    if (manifest == null) return null;

    for (final entry in manifest.entries) {
      if (entry.addressKey == addressKey) {
        return entry;
      }
    }

    return null;
  }

  _AddressablesManifest _parseManifest(String jsonString) {
    final decoded = jsonDecode(jsonString);

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Manifest must be a JSON object.');
    }

    final catalogFile = (decoded['catalogFile'] ?? '').toString().trim();
    final hashFile = (decoded['hashFile'] ?? '').toString().trim();

    if (catalogFile.isEmpty) {
      throw Exception('Manifest is missing catalogFile.');
    }

    final rawEntries = decoded['entries'];
    if (rawEntries is! List) {
      throw Exception('Manifest is missing entries array.');
    }

    final entries = rawEntries.map<_AddressablesManifestEntry>((raw) {
      if (raw is! Map<String, dynamic>) {
        throw Exception('Manifest entry is not a JSON object.');
      }

      final addressKey = (raw['addressKey'] ?? '').toString().trim();
      final title = (raw['title'] ?? '').toString().trim();
      final animationName = (raw['animationName'] ?? '').toString().trim();
      final startPosition = (raw['startPosition'] ?? '').toString().trim();
      final endPosition = (raw['endPosition'] ?? '').toString().trim();
      final jsonFile = (raw['jsonFile'] ?? '').toString().trim();
      final bundleFile = (raw['bundleFile'] ?? '').toString().trim();

      if (addressKey.isEmpty) {
        throw Exception('Manifest entry is missing addressKey.');
      }
      if (jsonFile.isEmpty) {
        throw Exception('Manifest entry is missing jsonFile for $addressKey.');
      }
      if (bundleFile.isEmpty) {
        throw Exception(
          'Manifest entry is missing bundleFile for $addressKey.',
        );
      }

      return _AddressablesManifestEntry(
        addressKey: addressKey,
        title: title.isEmpty ? addressKey : title,
        animationName: animationName.isEmpty ? addressKey : animationName,
        startPosition: startPosition,
        endPosition: endPosition,
        jsonFile: jsonFile,
        bundleFile: bundleFile,
      );
    }).toList();

    return _AddressablesManifest(
      catalogFile: catalogFile,
      hashFile: hashFile,
      entries: entries,
    );
  }
}

class _AddressablesManifest {
  _AddressablesManifest({
    required this.catalogFile,
    required this.hashFile,
    required this.entries,
  });

  final String catalogFile;
  final String hashFile;
  final List<_AddressablesManifestEntry> entries;
}

class _AddressablesManifestEntry {
  _AddressablesManifestEntry({
    required this.addressKey,
    required this.title,
    required this.animationName,
    required this.startPosition,
    required this.endPosition,
    required this.jsonFile,
    required this.bundleFile,
  });

  final String addressKey;
  final String title;
  final String animationName;
  final String startPosition;
  final String endPosition;
  final String jsonFile;
  final String bundleFile;
}
