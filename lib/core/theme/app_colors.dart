import 'dart:ui' show Color;

/// Centralised colour tokens.
///
/// Scheme-level colours (`colorScheme.primary`, etc.) are derived from the
/// brand seed via `ColorScheme.fromSeed`. Tokens here are the *raw* palette
/// — use the colour scheme inside widgets whenever possible.
abstract final class AppColors {
  // Brand ────────────────────────────────────────────────────────
  /// Seed for `ColorScheme.fromSeed`. Picked to give an enterprise
  /// trust-blue on Material 3 with sufficient contrast for finance UIs.
  static const Color brandSeed = Color(0xFF1F4E79);

  // Semantic ─────────────────────────────────────────────────────
  static const Color success = Color(0xFF1B873F);
  static const Color warning = Color(0xFFB75D00);
  static const Color danger  = Color(0xFFC62828);
  static const Color info    = Color(0xFF0277BD);

  // Neutrals ─────────────────────────────────────────────────────
  // Used for surfaces / dividers when the M3 scheme doesn't fit
  // (e.g. data-table zebra rows, audit highlights).
  static const Color neutral0   = Color(0xFFFFFFFF);
  static const Color neutral50  = Color(0xFFF7F8FA);
  static const Color neutral100 = Color(0xFFEEF0F4);
  static const Color neutral200 = Color(0xFFD9DDE3);
  static const Color neutral400 = Color(0xFF8B939E);
  static const Color neutral600 = Color(0xFF4A5260);
  static const Color neutral800 = Color(0xFF20262F);
  static const Color neutral900 = Color(0xFF11151B);

  // Splash (Screen 0.1) ──────────────────────────────────────────
  // Two-stop gradient that frames the [`AnimatedLogo`]. Picked from
  // the brand seed so the splash reads as the same product even when
  // the OS theme overrides the light/dark scheme later.
  static const Color splashGradientTop    = Color(0xFF1F4E79);
  static const Color splashGradientBottom = Color(0xFF0F2540);

  /// Foreground colour for the splash logo + label. Always readable
  /// against [splashGradientTop] / [splashGradientBottom] regardless
  /// of the active theme.
  static const Color splashForeground = Color(0xFFFFFFFF);

  /// Subtle white-on-dark for the version text + loading bar so they
  /// fade behind the brand mark instead of competing with it.
  static const Color splashMuted = Color(0xCCFFFFFF);
}
