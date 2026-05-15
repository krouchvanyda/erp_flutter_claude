/// Raw numeric font-size tokens.
///
/// **Why this exists alongside [AppTypography]**: the typography file
/// returns full `TextStyle` instances bound to a `TextTheme`. Some
/// surfaces — splash, lock screen, snackbar overrides — need to compose
/// styles inline (custom font weight + brand colour) and only want the
/// raw `fontSize` token. Pulling those numbers from one named place
/// keeps the design ladder consistent.
///
/// Use [AppTypography] for full styles inside themed surfaces; use this
/// for one-off custom text (e.g. [`AppLabel`]).
abstract final class AppFontSizes {
  // Display ──────────────────────────────────────────────────────
  static const double displayLarge  = 57.0;
  static const double displayMedium = 45.0;
  static const double displaySmall  = 36.0;

  // Headline ─────────────────────────────────────────────────────
  static const double headlineLarge  = 32.0;
  static const double headlineMedium = 28.0;
  static const double headlineSmall  = 24.0;

  // Title ────────────────────────────────────────────────────────
  static const double titleLarge  = 20.0;
  static const double titleMedium = 16.0;
  static const double titleSmall  = 14.0;

  // Body ─────────────────────────────────────────────────────────
  static const double bodyLarge  = 16.0;
  static const double bodyMedium = 14.0;
  static const double bodySmall  = 12.0;

  // Label ────────────────────────────────────────────────────────
  static const double labelLarge  = 14.0;
  static const double labelMedium = 12.0;
  static const double labelSmall  = 11.0;

  // Splash brand mark — outsized on purpose so the wordmark is the
  // first thing the user sees on cold start.
  static const double splashLogo = 48.0;
}
