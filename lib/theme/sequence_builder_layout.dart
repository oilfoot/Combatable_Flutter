/// Geometry shared by the Sequence Builder screen and its timeline widgets.
///
/// These values describe component structure, while general-purpose spacing,
/// radii, colors, and typography remain in `app_theme.dart`.
abstract final class SequenceBuilderLayout {
  static const double headerExtent = 196;
  static const double minimumControlTarget = 44;
  static const double primaryActionHeight = 52;

  static const double timelineTileHeight = 96;
  static const double timelinePreviewSize = 72;
  static const double timelinePositionNodeSize = 28;
  static const double timelineEntryGap = 6;

  static const double timelineStepExtent =
      timelineTileHeight + (timelineEntryGap * 2) + timelinePositionNodeSize;
  static const double railPositionToPositionExtent = timelineStepExtent;
  static const double railPositionToPlaceholderExtent = 68;
  static const double railWidth = 1;
  static const double railLeft = (timelinePositionNodeSize - railWidth) / 2;
  static const double railTop = timelinePositionNodeSize / 2;

  static const double postRevealBottomClearance = 32;
  static const double postRevealOverflowThreshold = 4;
}
