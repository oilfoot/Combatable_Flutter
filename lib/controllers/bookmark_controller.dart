import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/animation_library_item.dart';

class BookmarkController extends ChangeNotifier {
  final Map<String, AnimationLibraryItem> _itemsByAnimationName = {};
  Future<void>? _initialization;
  Future<void> _writeQueue = Future<void>.value();
  File? _storageFile;

  List<AnimationLibraryItem> get items =>
      List<AnimationLibraryItem>.unmodifiable(_itemsByAnimationName.values);

  Future<void> initialize() {
    return _initialization ??= _load();
  }

  bool isBookmarked(AnimationLibraryItem item) {
    return _itemsByAnimationName.containsKey(item.animationName);
  }

  Future<void> toggle(AnimationLibraryItem item) async {
    await initialize();

    if (isBookmarked(item)) {
      _itemsByAnimationName.remove(item.animationName);
    } else {
      _itemsByAnimationName[item.animationName] = item;
    }

    notifyListeners();
    await _enqueueWrite();
  }

  Future<void> _load() async {
    final directory = await getApplicationSupportDirectory();
    final file = File('${directory.path}/animation_bookmarks.json');
    _storageFile = file;

    if (!await file.exists()) {
      return;
    }

    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! List<dynamic>) return;

      for (final value in decoded.whereType<Map<String, dynamic>>()) {
        final item = AnimationLibraryItem.fromJson(value);
        if (item.animationName.isNotEmpty) {
          _itemsByAnimationName[item.animationName] = item;
        }
      }
      notifyListeners();
    } on FormatException {
      // Ignore a malformed local cache. A later bookmark action rewrites it.
    } on FileSystemException {
      // Bookmarks remain usable in memory if local storage is unavailable.
    }
  }

  Future<void> _enqueueWrite() {
    final snapshot = [
      for (final item in _itemsByAnimationName.values) item.toJson(),
    ];

    _writeQueue = _writeQueue.then((_) async {
      final file = _storageFile;
      if (file == null) return;

      try {
        await file.writeAsString(jsonEncode(snapshot), flush: true);
      } on FileSystemException {
        // Keep the in-memory state even if persistence temporarily fails.
      }
    });

    return _writeQueue;
  }
}
