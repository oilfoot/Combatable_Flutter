class UnityPreviewState {
  const UnityPreviewState({
    this.ready = false,
    this.sequenceName = 'Preview',
    this.isPlaying = false,
    this.loopEnabled = true,
    this.playbackSpeed = 1,
    this.currentStepIndex = 0,
    this.stepCount = 0,
    this.canGoPrevious = false,
    this.canGoNext = false,
    this.scopeAvailable = false,
    this.scopeFocused = false,
    this.focusedClipName = '',
    this.commentsEnabled = true,
    this.commentVisible = false,
    this.commentText = '',
    this.commentYOffset = 0,
    this.timelineRectValid = false,
    this.timelineLeft = 0,
    this.timelineBottom = 0,
    this.timelineWidth = 0,
    this.timelineHeight = 0,
  });

  final bool ready;
  final String sequenceName;
  final bool isPlaying;
  final bool loopEnabled;
  final double playbackSpeed;
  final int currentStepIndex;
  final int stepCount;
  final bool canGoPrevious;
  final bool canGoNext;
  final bool scopeAvailable;
  final bool scopeFocused;
  final String focusedClipName;
  final bool commentsEnabled;
  final bool commentVisible;
  final String commentText;
  final double commentYOffset;
  final bool timelineRectValid;
  final double timelineLeft;
  final double timelineBottom;
  final double timelineWidth;
  final double timelineHeight;

  factory UnityPreviewState.fromJson(Map<String, dynamic> json) {
    bool boolValue(String key, bool fallback) =>
        json[key] is bool ? json[key] as bool : fallback;
    int intValue(String key) => (json[key] as num?)?.toInt() ?? 0;
    double doubleValue(String key, double fallback) =>
        (json[key] as num?)?.toDouble() ?? fallback;

    return UnityPreviewState(
      ready: boolValue('ready', false),
      sequenceName: json['sequenceName'] as String? ?? 'Preview',
      isPlaying: boolValue('isPlaying', false),
      loopEnabled: boolValue('loopEnabled', true),
      playbackSpeed: doubleValue('playbackSpeed', 1),
      currentStepIndex: intValue('currentStepIndex'),
      stepCount: intValue('stepCount'),
      canGoPrevious: boolValue('canGoPrevious', false),
      canGoNext: boolValue('canGoNext', false),
      scopeAvailable: boolValue('scopeAvailable', false),
      scopeFocused: boolValue('scopeFocused', false),
      focusedClipName: json['focusedClipName'] as String? ?? '',
      commentsEnabled: boolValue('commentsEnabled', true),
      commentVisible: boolValue('commentVisible', false),
      commentText: json['commentText'] as String? ?? '',
      commentYOffset: doubleValue('commentYOffset', 0),
      timelineRectValid: boolValue('timelineRectValid', false),
      timelineLeft: doubleValue('timelineLeft', 0),
      timelineBottom: doubleValue('timelineBottom', 0),
      timelineWidth: doubleValue('timelineWidth', 0),
      timelineHeight: doubleValue('timelineHeight', 0),
    );
  }
}
