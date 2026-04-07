import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/animation_library_item.dart';
import '../services/unity_service.dart';

class SequenceController extends ChangeNotifier {
  SequenceController({required this.unityService}) {
    _logSub = unityService.logs.listen((log) {
      _logs.insert(0, log);

      if (_logs.length > 50) {
        _logs.removeLast();
      }

      notifyListeners();
    });
  }

  final UnityService unityService;
  StreamSubscription<String>? _logSub;

  String _sequenceName = 'New Sequence';
  final List<AnimationLibraryItem> _selectedAnimations =
      <AnimationLibraryItem>[];
  final List<String> _logs = <String>[];

  String get sequenceName => _sequenceName;
  List<AnimationLibraryItem> get selectedAnimations =>
      List.unmodifiable(_selectedAnimations);
  List<String> get logs => List.unmodifiable(_logs);

  bool get isUnityReady => unityService.isUnityReady;
  bool get hasAnimations => _selectedAnimations.isNotEmpty;

  void setSequenceName(String value) {
    final trimmed = value.trim();
    _sequenceName = trimmed.isEmpty ? 'New Sequence' : trimmed;
    notifyListeners();
  }

  String? get requiredNextStartPosition {
    if (_selectedAnimations.isEmpty) return null;
    return _selectedAnimations.last.endPosition;
  }

  bool canAddAnimation(AnimationLibraryItem item) {
    if (_selectedAnimations.isEmpty) return true;

    final requiredStart = requiredNextStartPosition;
    if (requiredStart == null) return true;

    return item.startPosition == requiredStart;
  }

  List<AnimationLibraryItem> getAvailableLibraryItems(
    List<AnimationLibraryItem> fullLibrary,
  ) {
    if (_selectedAnimations.isEmpty) {
      return List<AnimationLibraryItem>.from(fullLibrary);
    }

    final requiredStart = requiredNextStartPosition;
    return fullLibrary
        .where((item) => item.startPosition == requiredStart)
        .toList();
  }

  void addAnimationItem(AnimationLibraryItem item) {
    if (!canAddAnimation(item)) {
      _addLocalLog(
        "Blocked animation: ${item.title} does not match required start position '$requiredNextStartPosition'.",
      );
      notifyListeners();
      return;
    }

    _selectedAnimations.add(item);
    _addLocalLog(
      "Added animation: ${item.title} (${item.animationName}) "
      "[${item.startPosition} -> ${item.endPosition}]",
    );
    notifyListeners();
  }

  void removeAnimationAt(int index) {
    if (index < 0 || index >= _selectedAnimations.length) return;

    final removed = _selectedAnimations[index];
    _selectedAnimations.removeAt(index);
    _addLocalLog(
      "Removed animation: ${removed.title} "
      "[${removed.startPosition} -> ${removed.endPosition}]",
    );
    notifyListeners();
  }

  void clearAnimations() {
    _selectedAnimations.clear();
    _addLocalLog("Cleared animation list.");
    notifyListeners();
  }

  void loadQuickTestData(List<AnimationLibraryItem> libraryItems) {
    _sequenceName = 'Prototype Sequence';
    _selectedAnimations.clear();

    for (final item in libraryItems) {
      if (_selectedAnimations.isEmpty || canAddAnimation(item)) {
        _selectedAnimations.add(item);
      }

      if (_selectedAnimations.length >= 3) {
        break;
      }
    }

    _addLocalLog("Inserted quick test data.");
    notifyListeners();
  }

  List<String> getAnimationNamesForUnity() {
    return _selectedAnimations.map((item) => item.animationName).toList();
  }

  Future<void> sendToUnity() async {
    await unityService.sendSequence(
      sequenceName: _sequenceName,
      animations: getAnimationNamesForUnity(),
    );
  }

  void _addLocalLog(String text) {
    _logs.insert(0, text);

    if (_logs.length > 50) {
      _logs.removeLast();
    }
  }

  @override
  void dispose() {
    _logSub?.cancel();
    super.dispose();
  }
}
