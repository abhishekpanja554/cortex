/// Spacing scale (4-pt grid). Use these instead of ad-hoc numbers.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;

  /// Horizontal page gutter used by every screen (iOS inset-grouped margin).
  static const double page = 16;
}

/// Corner radii. Drawn as iOS "continuous" corners via [AppShapes], so the
/// values run a little larger than plain rounded rectangles would.
class AppRadius {
  AppRadius._();

  static const double sm = 10;
  static const double md = 14;
  static const double lg = 20;
  static const double xl = 26;
  static const double xxl = 34;
  static const double pill = 999;
}
