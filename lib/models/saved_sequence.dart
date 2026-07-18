import 'animation_library_item.dart';

class SavedSequence {
  const SavedSequence({
    required this.id,
    required this.name,
    required this.animations,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final List<AnimationLibraryItem> animations;
  final DateTime createdAt;
  final DateTime updatedAt;

  int get stepCount => animations.length;
  String get startPosition =>
      animations.isEmpty ? 'Any' : animations.first.startPosition;
  String get endPosition =>
      animations.isEmpty ? 'Any' : animations.last.endPosition;

  factory SavedSequence.fromJson(Map<String, dynamic> json) {
    final animationValues = json['animations'] as List<dynamic>? ?? const [];

    return SavedSequence(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      animations: animationValues
          .whereType<Map<String, dynamic>>()
          .map(AnimationLibraryItem.fromJson)
          .toList(growable: false),
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'animations': [for (final animation in animations) animation.toJson()],
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
