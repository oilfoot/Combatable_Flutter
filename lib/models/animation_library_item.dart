class AnimationLibraryItem {
  final String title;
  final String animationName;
  final String startPosition;
  final String endPosition;

  final String? addressKey;
  final String? description;
  final String? category;
  final List<String> tags;
  final String? previewPath;

  const AnimationLibraryItem({
    required this.title,
    required this.animationName,
    required this.startPosition,
    required this.endPosition,
    this.addressKey,
    this.description,
    this.category,
    this.tags = const [],
    this.previewPath,
  });

  String get downloadKey => addressKey ?? animationName;
}
