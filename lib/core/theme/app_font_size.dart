/// Font size scale (design guide §2.2). Used by `AppTextStyle` and `AppLabel`
/// so the theme and custom text share the same sizes.
abstract final class AppFontSize {
  static const double value11 = 11; // labelSmall — chips, badges
  static const double value12 = 12; // bodySmall / labelMedium — captions
  static const double value14 = 14; // bodyMedium / labelLarge / titleSmall
  static const double value16 = 16; // bodyLarge / titleMedium
  static const double value18 = 18; // headlineSmall — dialog titles
  static const double value20 = 20; // headlineMedium / titleLarge — sections
  static const double value24 = 24; // headlineLarge / displaySmall — titles
  static const double value28 = 28; // displayMedium
  static const double value32 = 32; // displayLarge — splash
}
