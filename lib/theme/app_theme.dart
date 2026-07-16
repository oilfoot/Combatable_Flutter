import 'package:flutter/material.dart';

/// Semantic colors shared by Combatable's UI.
///
/// Widgets should choose a color by its purpose, not by its raw shade. This
/// keeps future visual changes local to this file.
abstract final class AppColors {
  static const background = Color(0xFF121015);
  static const panel = Color(0xFF141418);
  static const elevatedSurface = Color(0xFF26232C);

  static const accent = Color(0xFF8F55FF);
  static const accentSoft = Color(0xFFC8A7FF);

  static const destructive = Color(0xFFFF718B);
  static const destructiveSoft = Color(0xFFFF8CA0);
  static const onDestructive = Color(0xFF26151B);

  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0x99FFFFFF);
  static const textDisabled = Color(0x33FFFFFF);

  static const surface = Color(0x0FFFFFFF);
  static const borderSubtle = Color(0x17FFFFFF);
  static const borderStrong = Color(0x29FFFFFF);

  static const black = Color(0xFF000000);
  static const transparent = Color(0x00000000);
}

/// A deliberately small opacity scale for derived colors.
abstract final class AppOpacity {
  static const double faint = 0.06;
  static const double subtle = 0.12;
  static const double muted = 0.26;
  static const double medium = 0.38;
  static const double strong = 0.52;
  static const double scrim = 0.40;
  static const double barrier = 0.68;
}

abstract final class AppSpacing {
  static const double xxs = 3;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double buttonGap = 10;
  static const double dialogSection = 14;
  static const double dialog = 22;
  static const double panel = 28;
}

abstract final class AppRadii {
  static const double small = 12;
  static const double medium = 14;
  static const double button = 16;
  static const double card = 18;
  static const double dialog = 24;
  static const double panel = 28;
  static const double pill = 999;
}

abstract final class AppTypography {
  static const screenTitle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w800,
  );
  static const sectionTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w800,
  );
  static const componentTitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w800,
  );
  static const dialogTitle = TextStyle(
    fontSize: 19,
    fontWeight: FontWeight.w800,
  );
  static const body = TextStyle(fontSize: 14, height: 1.35);
  static const caption = TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500);
  static const controlLabel = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w800,
  );
  static const compactCardTitle = TextStyle(
    fontSize: 11,
    height: 1.02,
    fontWeight: FontWeight.w800,
  );
  static const button = TextStyle(fontSize: 16, fontWeight: FontWeight.w800);
  static const label = TextStyle(fontSize: 13, fontWeight: FontWeight.w700);
}

abstract final class AppMotion {
  static const quick = Duration(milliseconds: 150);
  static const cardReveal = Duration(milliseconds: 180);
  static const standard = Duration(milliseconds: 220);
  static const panel = Duration(milliseconds: 320);

  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve emphasized = Curves.easeInOutCubic;
}

abstract final class AppShadows {
  static final panel = BoxShadow(
    color: AppColors.black.withValues(alpha: AppOpacity.strong),
    blurRadius: 24,
    offset: const Offset(0, -8),
  );

  static final dialog = BoxShadow(
    color: AppColors.black.withValues(alpha: AppOpacity.medium),
    blurRadius: 28,
    offset: const Offset(0, 14),
  );

  static const compactImageText = Shadow(
    color: AppColors.black,
    blurRadius: 8,
    offset: Offset(0, 2),
  );

  static final imageText = Shadow(
    color: AppColors.black.withValues(alpha: AppOpacity.barrier),
    blurRadius: 10,
    offset: const Offset(0, 2),
  );
}

abstract final class AppTheme {
  static ThemeData dark() {
    // Keep untouched screens on Flutter's current dark defaults while the
    // design system is introduced progressively. App-wide component themes
    // can be added here as each screen is migrated.
    return ThemeData.dark();
  }
}
