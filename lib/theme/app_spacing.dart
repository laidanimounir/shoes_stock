class AppSpacing {
  AppSpacing._();

  // ────────────────────────────────────────────
  // SPACING
  // ────────────────────────────────────────────
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;

  // ────────────────────────────────────────────
  // INSETS
  // ────────────────────────────────────────────
  static const double screenHorizontal = 16.0;
  static const double screenVertical = 24.0;
  static const double cardPadding = 16.0;
  static const double listItemPadding = 12.0;
  static const double sectionGap = 32.0;
  static const double itemGap = 12.0;
}

class AppRadius {
  AppRadius._();

  static const double sm = 6.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double full = 999.0;
}

class AppElevation {
  AppElevation._();

  static const double none = 0.0;
  static const double low = 1.0;
  static const double medium = 2.0;
  static const double high = 4.0;
  static const double floating = 8.0;
}

class AppDuration {
  AppDuration._();

  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);
  static const Duration entry = Duration(milliseconds: 350);
}
