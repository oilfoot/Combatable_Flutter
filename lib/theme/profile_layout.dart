/// Geometry used by the Profile screen.
///
/// General spacing, color, radius, and typography decisions stay in
/// `app_theme.dart`; these values only describe Profile-specific components.
abstract final class ProfileLayout {
  static const double pagePadding = 16;
  static const double settingsButtonSize = 44;
  static const double avatarSize = 88;
  static const double tabHeight = 56;
  static const double tabIndicatorHeight = 2;
  static const double favoriteGridSpacing = 10;
  static const double favoriteCardAspectRatio = 0.64;
  static const int favoriteGridColumns = 3;
  static const double sequenceRowHeight = 112;
  static const double sequencePreviewSize = 80;
}
