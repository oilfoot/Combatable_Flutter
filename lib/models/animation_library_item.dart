class AnimationLibraryItem {
  final String title; // shown in Flutter UI
  final String animationName; // sent to Unity

  const AnimationLibraryItem({
    required this.title,
    required this.animationName,
  });
}
