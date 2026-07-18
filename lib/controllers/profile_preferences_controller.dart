import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

enum ProfileCollectionPreference { favorites, sequences }

class ProfilePreferencesController extends ChangeNotifier {
  ProfileCollectionPreference _selectedCollection =
      ProfileCollectionPreference.favorites;
  Future<void>? _initialization;
  Future<void> _writeQueue = Future<void>.value();
  File? _storageFile;

  ProfileCollectionPreference get selectedCollection => _selectedCollection;

  Future<void> initialize() {
    return _initialization ??= _load();
  }

  Future<void> selectCollection(ProfileCollectionPreference collection) async {
    await initialize();
    if (_selectedCollection == collection) return;

    _selectedCollection = collection;
    notifyListeners();
    await _enqueueWrite();
  }

  Future<void> _load() async {
    final directory = await getApplicationSupportDirectory();
    final file = File('${directory.path}/profile_preferences.json');
    _storageFile = file;
    if (!await file.exists()) return;

    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return;

      _selectedCollection = switch (decoded['selectedCollection']) {
        'sequences' => ProfileCollectionPreference.sequences,
        _ => ProfileCollectionPreference.favorites,
      };
      notifyListeners();
    } on FormatException {
      // Keep the default when the local preference is malformed.
    } on FileSystemException {
      // The in-memory preference remains usable when storage is unavailable.
    }
  }

  Future<void> _enqueueWrite() {
    final value = jsonEncode({'selectedCollection': _selectedCollection.name});

    _writeQueue = _writeQueue.then((_) async {
      final file = _storageFile;
      if (file == null) return;
      try {
        await file.writeAsString(value, flush: true);
      } on FileSystemException {
        // Keep the selected tab in memory if persistence temporarily fails.
      }
    });
    return _writeQueue;
  }
}
