class UnityStepIndicatorMarker {
  const UnityStepIndicatorMarker({required this.key, required this.position});

  final String key;
  final double position;

  factory UnityStepIndicatorMarker.fromJson(Map<String, dynamic> json) {
    return UnityStepIndicatorMarker(
      key: json['key'] as String? ?? '',
      position: ((json['position'] as num?)?.toDouble() ?? 0).clamp(0, 1),
    );
  }
}

class UnityStepIndicatorRange {
  const UnityStepIndicatorRange({
    required this.key,
    required this.start,
    required this.end,
  });

  final String key;
  final double start;
  final double end;

  factory UnityStepIndicatorRange.fromJson(Map<String, dynamic> json) {
    final start = ((json['start'] as num?)?.toDouble() ?? 0)
        .clamp(0, 1)
        .toDouble();
    final end = ((json['end'] as num?)?.toDouble() ?? 0).clamp(0, 1).toDouble();
    return UnityStepIndicatorRange(
      key: json['key'] as String? ?? '',
      start: start,
      end: end < start ? start : end,
    );
  }
}

class UnityStepIndicatorState {
  const UnityStepIndicatorState({
    this.ready = false,
    this.focused = false,
    this.viewportStart = 0,
    this.viewportEnd = 1,
    this.focusedRangeKey = '',
    this.contentKey = '',
    this.transitionDuration = 0.42,
    this.transitionCenter = 0.5,
    this.transitionSpeed = 12,
    this.markers = const [],
    this.ranges = const [],
  });

  final bool ready;
  final bool focused;
  final double viewportStart;
  final double viewportEnd;
  final String focusedRangeKey;
  final String contentKey;
  final double transitionDuration;
  final double transitionCenter;
  final double transitionSpeed;
  final List<UnityStepIndicatorMarker> markers;
  final List<UnityStepIndicatorRange> ranges;

  factory UnityStepIndicatorState.fromJson(Map<String, dynamic> json) {
    List<T> readList<T>(String key, T Function(Map<String, dynamic>) fromJson) {
      final value = json[key];
      if (value is! List) return const [];
      return value
          .whereType<Map>()
          .map(
            (item) => fromJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .toList(growable: false);
    }

    final viewportStart = ((json['viewportStart'] as num?)?.toDouble() ?? 0)
        .clamp(0, 1)
        .toDouble();
    final parsedViewportEnd = ((json['viewportEnd'] as num?)?.toDouble() ?? 1)
        .clamp(0, 1)
        .toDouble();

    return UnityStepIndicatorState(
      ready: json['ready'] as bool? ?? false,
      focused: json['focused'] as bool? ?? false,
      viewportStart: viewportStart,
      viewportEnd: parsedViewportEnd <= viewportStart
          ? (viewportStart + 0.0001).clamp(0, 1)
          : parsedViewportEnd,
      focusedRangeKey: json['focusedRangeKey'] as String? ?? '',
      contentKey: json['contentKey'] as String? ?? '',
      transitionDuration:
          ((json['transitionDuration'] as num?)?.toDouble() ?? 0.42).clamp(
            0.2,
            1.2,
          ),
      transitionCenter: ((json['transitionCenter'] as num?)?.toDouble() ?? 0.5)
          .clamp(0, 1),
      transitionSpeed: ((json['transitionSpeed'] as num?)?.toDouble() ?? 12)
          .clamp(1, 30),
      markers: readList('markers', UnityStepIndicatorMarker.fromJson),
      ranges: readList('ranges', UnityStepIndicatorRange.fromJson),
    );
  }
}
