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

  factory AnimationLibraryItem.fromJson(Map<String, dynamic> json) {
    return AnimationLibraryItem(
      title: json['title'] as String? ?? '',
      animationName: json['animationName'] as String? ?? '',
      startPosition: json['startPosition'] as String? ?? '',
      endPosition: json['endPosition'] as String? ?? '',
      addressKey: json['addressKey'] as String?,
      description: json['description'] as String?,
      category: json['category'] as String?,
      tags: (json['tags'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      previewPath: json['previewPath'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'title': title,
      'animationName': animationName,
      'startPosition': startPosition,
      'endPosition': endPosition,
      'addressKey': addressKey,
      'description': description,
      'category': category,
      'tags': tags,
      'previewPath': previewPath,
    };
  }
}
