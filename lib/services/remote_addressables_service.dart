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

  String _status = 'Not downloaded yet.';
  String? _addressablesDirPath;
  String? _catalogPath;
  bool _isDownloading = false;
  bool _isSendingCatalog = false;

  /// 🔥 NEW: tracks if Unity already knows the catalog
  bool _isUnityPrepared = false;

  final List<AnimationLibraryItem> _downloadedItems = [];
  final List<String> _downloadedJsonPaths = [];

  static const List<String> _coreAddressableFiles = [
    'catalog.hash',
    'catalog.bin',
    'remotegroup_assets_all_9b649835c7f880b94bee3adee85f030e.bundle',
    'addressables_manifest.json',
  ];

  String get status => _status;
  String? get addressablesDirPath => _addressablesDirPath;
  String? get catalogPath => _catalogPath;
  bool get isDownloading => _isDownloading;
  bool get isSendingCatalog => _isSendingCatalog;

  /// 🔥 NEW
  bool get hasDownloadedContent =>
      _catalogPath != null &&
      _catalogPath!.isNotEmpty &&
      _downloadedJsonPaths.isNotEmpty;

  List<AnimationLibraryItem> get downloadedItems =>
      List.unmodifiable(_downloadedItems);

  List<String> get downloadedJsonPaths =>
      List.unmodifiable(_downloadedJsonPaths);

  // =========================
  // DOWNLOAD
  // =========================
  Future<void> downloadAddressables() async {
    if (_isDownloading) return;

    _isDownloading = true;
    _status = 'Downloading Addressables...';
    notifyListeners();

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final addressablesDir = Directory('${appDir.path}/addressables');

      if (!await addressablesDir.exists()) {
        await addressablesDir.create(recursive: true);
      }

      for (final fileName in _coreAddressableFiles) {
        final localFile = File('${addressablesDir.path}/$fileName');
        final ref = _firebaseStorage.ref('addressables/iOS/$fileName');
        await ref.writeToFile(localFile);
      }

      final manifestFile = File(
        '${addressablesDir.path}/addressables_manifest.json',
      );

      if (!await manifestFile.exists()) {
        throw Exception('Manifest file was not downloaded.');
      }

      final manifestContent = await manifestFile.readAsString();
      final manifestEntries = _parseManifest(manifestContent);

      final parsedItems = <AnimationLibraryItem>[];
      final jsonPaths = <String>[];

      for (final entry in manifestEntries) {
        final jsonFileName = (entry['jsonFile'] ?? '').toString().trim();

        if (jsonFileName.isEmpty) {
          throw Exception('Manifest entry is missing jsonFile.');
        }

        final localJsonFile = File('${addressablesDir.path}/$jsonFileName');

        final jsonRef = _firebaseStorage.ref('addressables/iOS/$jsonFileName');

        await jsonRef.writeToFile(localJsonFile);

        final configContent = await localJsonFile.readAsString();
        final item = _parseAnimationConfig(configContent);

        parsedItems.add(item);
        jsonPaths.add(localJsonFile.path);
      }

      final catalogPath = '${addressablesDir.path}/catalog.bin';

      _addressablesDirPath = addressablesDir.path;
      _catalogPath = catalogPath;

      _downloadedItems
        ..clear()
        ..addAll(parsedItems);

      _downloadedJsonPaths
        ..clear()
        ..addAll(jsonPaths);

      /// 🔥 IMPORTANT: force Unity re-init
      _isUnityPrepared = false;

      /// 🔥 auto prepare immediately
      await ensureUnityPrepared();

      _status = 'Addressables ready.\nLoaded ${parsedItems.length} animations.';
    } catch (e) {
      _status = 'Download failed:\n$e';
    } finally {
      _isDownloading = false;
      notifyListeners();
    }
  }

  // =========================
  // UNITY SYNC
  // =========================
  Future<void> ensureUnityPrepared() async {
    if (_isUnityPrepared) return;
    if (!hasDownloadedContent) return;

    await loadCatalogInUnity();
  }

  Future<void> loadCatalogInUnity() async {
    if (_isSendingCatalog) return;

    if (_catalogPath == null || _catalogPath!.isEmpty) {
      _status = 'No catalog available.';
      notifyListeners();
      return;
    }

    _isSendingCatalog = true;
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

      /// 🔥 CRITICAL
      _isUnityPrepared = true;

      _status = 'Unity catalog loaded.';
    } catch (e) {
      _isUnityPrepared = false;
      _status = 'Unity load failed:\n$e';
    } finally {
      _isSendingCatalog = false;
      notifyListeners();
    }
  }

  /// 🔥 called when Unity is paused
  void markUnityStateDirty() {
    _isUnityPrepared = false;
  }

  // =========================
  // RESTORE FROM DISK
  // =========================
  Future<void> refreshDownloadedStateFromDisk() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final addressablesDir = Directory('${appDir.path}/addressables');

      if (!await addressablesDir.exists()) return;

      final manifestFile = File(
        '${addressablesDir.path}/addressables_manifest.json',
      );
      final catalogFile = File('${addressablesDir.path}/catalog.bin');

      if (!await manifestFile.exists() || !await catalogFile.exists()) return;

      final manifestContent = await manifestFile.readAsString();
      final manifestEntries = _parseManifest(manifestContent);

      final parsedItems = <AnimationLibraryItem>[];
      final jsonPaths = <String>[];

      for (final entry in manifestEntries) {
        final jsonFileName = (entry['jsonFile'] ?? '').toString().trim();

        final localJsonFile = File('${addressablesDir.path}/$jsonFileName');

        if (!await localJsonFile.exists()) continue;

        final configContent = await localJsonFile.readAsString();

        parsedItems.add(_parseAnimationConfig(configContent));
        jsonPaths.add(localJsonFile.path);
      }

      _addressablesDirPath = addressablesDir.path;
      _catalogPath = catalogFile.path;

      _downloadedItems
        ..clear()
        ..addAll(parsedItems);

      _downloadedJsonPaths
        ..clear()
        ..addAll(jsonPaths);

      /// 🔥 VERY IMPORTANT
      _isUnityPrepared = false;

      _status = 'Restored ${parsedItems.length} animations from disk.';
      notifyListeners();
    } catch (_) {}
  }

  // =========================
  // HELPERS
  // =========================
  List<Map<String, dynamic>> _parseManifest(String jsonString) {
    final decoded = jsonDecode(jsonString);

    if (decoded is! List) {
      throw Exception('Manifest invalid.');
    }

    return decoded.cast<Map<String, dynamic>>();
  }

  AnimationLibraryItem _parseAnimationConfig(String jsonString) {
    final decoded = jsonDecode(jsonString);

    final animationName = (decoded['animationName'] ?? '').toString().trim();

    return AnimationLibraryItem(
      title: (decoded['displayName'] ?? animationName).toString(),
      animationName: animationName,
      startPosition: (decoded['startPosition'] ?? '').toString(),
      endPosition: (decoded['endPosition'] ?? '').toString(),
    );
  }
}
