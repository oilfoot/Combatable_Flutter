import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/animation_library_item.dart';
import 'sequence_controller.dart';

enum SequenceMutationOrigin { user, undo, redo }

class SequenceMutation {
  const SequenceMutation({
    required this.before,
    required this.after,
    required this.origin,
    this.transitionId,
  });

  final List<AnimationLibraryItem> before;
  final List<AnimationLibraryItem> after;
  final SequenceMutationOrigin origin;

  /// Links an optional interaction animation, such as a card flight, to the
  /// otherwise standalone timeline transition.
  final String? transitionId;

  int get commonPrefixLength {
    final limit = before.length < after.length ? before.length : after.length;
    var index = 0;
    while (index < limit && identical(before[index], after[index])) {
      index++;
    }
    return index;
  }

  List<AnimationLibraryItem> get insertedItems {
    final prefix = commonPrefixLength;
    if (after.length <= prefix) return const [];
    return after.sublist(prefix);
  }

  List<AnimationLibraryItem> get removedItems {
    final prefix = commonPrefixLength;
    if (before.length <= prefix) return const [];
    return before.sublist(prefix);
  }

  bool get isInsertion => insertedItems.isNotEmpty && removedItems.isEmpty;
  bool get isRemoval => removedItems.isNotEmpty && insertedItems.isEmpty;
}

class SequenceHistoryController extends ChangeNotifier {
  SequenceHistoryController({
    required SequenceController sequenceController,
    this.maxHistoryLength = 10,
  }) : _sequenceController = sequenceController;

  final SequenceController _sequenceController;
  final int maxHistoryLength;
  final List<List<AnimationLibraryItem>> _undoHistory = [];
  final List<List<AnimationLibraryItem>> _redoHistory = [];
  final StreamController<SequenceMutation> _mutations =
      StreamController<SequenceMutation>.broadcast(sync: true);

  Stream<SequenceMutation> get mutations => _mutations.stream;
  bool get canUndo => _undoHistory.isNotEmpty;
  bool get canRedo => _redoHistory.isNotEmpty;
  int get undoDepth => _undoHistory.length;
  int get redoDepth => _redoHistory.length;

  bool addAnimation(AnimationLibraryItem item, {String? transitionId}) {
    if (!_sequenceController.canAddAnimation(item)) return false;

    final before = _snapshot();
    _sequenceController.addAnimationItem(item);
    _commitUserMutation(before, transitionId: transitionId);
    return true;
  }

  bool addAnimations(List<AnimationLibraryItem> items, {String? transitionId}) {
    if (items.isEmpty) return false;

    final before = _snapshot();
    if (!_sequenceController.addAnimationItems(items)) return false;
    _commitUserMutation(before, transitionId: transitionId);
    return true;
  }

  bool removeFrom(int index) {
    if (index < 0 || index >= _sequenceController.selectedAnimations.length) {
      return false;
    }

    final before = _snapshot();
    _sequenceController.removeAnimationsFrom(index);
    _commitUserMutation(before);
    return true;
  }

  bool clear() {
    if (_sequenceController.selectedAnimations.isEmpty) return false;

    final before = _snapshot();
    _sequenceController.clearAnimations();
    _commitUserMutation(before);
    return true;
  }

  void undo() {
    if (!canUndo) return;

    final before = _snapshot();
    final after = _undoHistory.removeLast();
    _redoHistory.add(before);
    _sequenceController.replaceAnimations(after);
    _emit(before, after, SequenceMutationOrigin.undo);
  }

  void redo() {
    if (!canRedo) return;

    final before = _snapshot();
    final after = _redoHistory.removeLast();
    _undoHistory.add(before);
    _trimUndoHistory();
    _sequenceController.replaceAnimations(after);
    _emit(before, after, SequenceMutationOrigin.redo);
  }

  void _commitUserMutation(
    List<AnimationLibraryItem> before, {
    String? transitionId,
  }) {
    final after = _snapshot();
    _undoHistory.add(before);
    _trimUndoHistory();
    _redoHistory.clear();
    _emit(
      before,
      after,
      SequenceMutationOrigin.user,
      transitionId: transitionId,
    );
  }

  void _trimUndoHistory() {
    while (_undoHistory.length > maxHistoryLength) {
      _undoHistory.removeAt(0);
    }
  }

  List<AnimationLibraryItem> _snapshot() =>
      List<AnimationLibraryItem>.from(_sequenceController.selectedAnimations);

  void _emit(
    List<AnimationLibraryItem> before,
    List<AnimationLibraryItem> after,
    SequenceMutationOrigin origin, {
    String? transitionId,
  }) {
    _mutations.add(
      SequenceMutation(
        before: List.unmodifiable(before),
        after: List.unmodifiable(after),
        origin: origin,
        transitionId: transitionId,
      ),
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _mutations.close();
    super.dispose();
  }
}
