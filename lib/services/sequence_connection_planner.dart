import '../models/animation_library_item.dart';

enum SequenceConnectionStatus { direct, bridgeFound, unavailable }

class SequenceConnectionPlan {
  const SequenceConnectionPlan._({
    required this.status,
    required this.fromPosition,
    required this.toPosition,
    this.bridgeAnimations = const [],
  });

  factory SequenceConnectionPlan.direct({
    required String fromPosition,
    required String toPosition,
  }) {
    return SequenceConnectionPlan._(
      status: SequenceConnectionStatus.direct,
      fromPosition: fromPosition,
      toPosition: toPosition,
    );
  }

  factory SequenceConnectionPlan.bridgeFound({
    required String fromPosition,
    required String toPosition,
    required List<AnimationLibraryItem> bridgeAnimations,
  }) {
    return SequenceConnectionPlan._(
      status: SequenceConnectionStatus.bridgeFound,
      fromPosition: fromPosition,
      toPosition: toPosition,
      bridgeAnimations: List.unmodifiable(bridgeAnimations),
    );
  }

  factory SequenceConnectionPlan.unavailable({
    required String fromPosition,
    required String toPosition,
  }) {
    return SequenceConnectionPlan._(
      status: SequenceConnectionStatus.unavailable,
      fromPosition: fromPosition,
      toPosition: toPosition,
    );
  }

  final SequenceConnectionStatus status;
  final String fromPosition;
  final String toPosition;
  final List<AnimationLibraryItem> bridgeAnimations;

  bool get canConnect => status != SequenceConnectionStatus.unavailable;
  bool get needsConfirmation => status == SequenceConnectionStatus.bridgeFound;
}

/// Finds the shortest available animation route between two positions.
class SequenceConnectionPlanner {
  const SequenceConnectionPlanner({this.maxBridgeAnimations = 5});

  final int maxBridgeAnimations;

  SequenceConnectionPlan plan({
    required String? currentEndPosition,
    required AnimationLibraryItem selectedAnimation,
    required Iterable<AnimationLibraryItem> availableAnimations,
  }) {
    final from = currentEndPosition?.trim() ?? '';
    final to = selectedAnimation.startPosition.trim();

    if (from.isEmpty || from == to) {
      return SequenceConnectionPlan.direct(
        fromPosition: from.isEmpty ? 'Any' : from,
        toPosition: to,
      );
    }

    final adjacency = <String, List<AnimationLibraryItem>>{};
    for (final animation in availableAnimations) {
      if (animation.animationName == selectedAnimation.animationName) continue;
      final start = animation.startPosition.trim();
      final end = animation.endPosition.trim();
      if (start.isEmpty || end.isEmpty || start == end) continue;
      adjacency.putIfAbsent(start, () => []).add(animation);
    }

    final queue = <_ConnectionSearchNode>[
      _ConnectionSearchNode(
        position: from,
        path: const <AnimationLibraryItem>[],
      ),
    ];
    final visitedDepth = <String, int>{from: 0};
    var cursor = 0;

    while (cursor < queue.length) {
      final node = queue[cursor++];
      if (node.path.length >= maxBridgeAnimations) continue;

      for (final animation
          in adjacency[node.position] ?? const <AnimationLibraryItem>[]) {
        final nextPath = [...node.path, animation];
        final nextPosition = animation.endPosition.trim();

        if (nextPosition == to) {
          return SequenceConnectionPlan.bridgeFound(
            fromPosition: from,
            toPosition: to,
            bridgeAnimations: nextPath,
          );
        }

        final nextDepth = nextPath.length;
        final previousDepth = visitedDepth[nextPosition];
        if (previousDepth != null && previousDepth <= nextDepth) continue;

        visitedDepth[nextPosition] = nextDepth;
        queue.add(
          _ConnectionSearchNode(position: nextPosition, path: nextPath),
        );
      }
    }

    return SequenceConnectionPlan.unavailable(
      fromPosition: from,
      toPosition: to,
    );
  }
}

class _ConnectionSearchNode {
  const _ConnectionSearchNode({required this.position, required this.path});

  final String position;
  final List<AnimationLibraryItem> path;
}
