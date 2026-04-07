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

  void setSequenceName(String value) {
    final trimmed = value.trim();
    _sequenceName = trimmed.isEmpty ? 'New Sequence' : trimmed;
    notifyListeners();
  }

  void addAnimationItem(AnimationLibraryItem item) {
    _selectedAnimations.add(item);
    _addLocalLog("Added animation: ${item.title} (${item.animationName})");
    notifyListeners();
  }

  void removeAnimationAt(int index) {
    if (index < 0 || index >= _selectedAnimations.length) return;

    final removed = _selectedAnimations[index];
    _selectedAnimations.removeAt(index);
    _addLocalLog("Removed animation: ${removed.title}");
    notifyListeners();
  }

  void clearAnimations() {
    _selectedAnimations.clear();
    _addLocalLog("Cleared animation list.");
    notifyListeners();
  }

  void loadQuickTestData(List<AnimationLibraryItem> libraryItems) {
    _sequenceName = 'Prototype Sequence';
    _selectedAnimations
      ..clear()
      ..addAll(libraryItems.take(3));

    _addLocalLog("Inserted quick test data.");
    notifyListeners();
  }

  Future<void> sendToUnity() async {
    final animationNames = _selectedAnimations
        .map((item) => item.animationName)
        .toList();

    await unityService.sendSequence(
      sequenceName: _sequenceName,
      animations: animationNames,
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
