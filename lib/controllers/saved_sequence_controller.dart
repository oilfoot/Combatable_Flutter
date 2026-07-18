import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/animation_library_item.dart';
import '../models/saved_sequence.dart';

class SavedSequenceController extends ChangeNotifier {
  final List<SavedSequence> _sequences = [];
  Future<void>? _initialization;
  Future<void> _writeQueue = Future<void>.value();
  File? _storageFile;

  List<SavedSequence> get sequences =>
      List<SavedSequence>.unmodifiable(_sequences);

  Future<void> initialize() {
    return _initialization ??= _load();
  }

  Future<SavedSequence> save({
    required String name,
    required List<AnimationLibraryItem> animations,
  }) async {
    await initialize();

    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'A sequence name is required.');
    }
    if (animations.length < 2) {
      throw ArgumentError.value(
        animations.length,
        'animations',
        'At least two animation steps are required.',
      );
    }

    final now = DateTime.now();
    final sequence = SavedSequence(
      id: now.microsecondsSinceEpoch.toString(),
      name: normalizedName,
      animations: List<AnimationLibraryItem>.unmodifiable(animations),
      createdAt: now,
      updatedAt: now,
    );

    _sequences.insert(0, sequence);
    notifyListeners();
    await _enqueueWrite();
    return sequence;
  }

  Future<void> _load() async {
    final directory = await getApplicationSupportDirectory();
    final file = File('${directory.path}/saved_sequences.json');
    _storageFile = file;

    if (!await file.exists()) return;

    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! List<dynamic>) return;

      _sequences
        ..clear()
        ..addAll(
          decoded
              .whereType<Map<String, dynamic>>()
              .map(SavedSequence.fromJson)
              .where(
                (sequence) =>
                    sequence.id.isNotEmpty &&
                    sequence.name.isNotEmpty &&
                    sequence.animations.length >= 2,
              ),
        )
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      notifyListeners();
    } on FormatException {
      // Ignore malformed local data. A later save rewrites the cache.
    } on FileSystemException {
      // Saved sequences remain available in memory if storage is unavailable.
    }
  }

  Future<void> _enqueueWrite() {
    final snapshot = [for (final sequence in _sequences) sequence.toJson()];

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
