import 'dart:ui' show Color;

/// Raw colour palette (from ERP_MOBILE_DESIGN_GUIDE.md §2.1).
///
/// Widgets should NOT read these directly. Use
/// `Theme.of(context).colorScheme.xxx` so dark mode works automatically.
/// `AppTheme` is the only place that maps these into a `ColorScheme`.
abstract final class AppColors {
  // ── Brand ──
  static const Color primary = Color(0xFF3B4FE8);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFFE8EBFF);

  // ── Surfaces (light) ──
  static const Color surface = Color(0xFFF8F9FC); // page background
  static const Color card = Color(0xFFFFFFFF); // cards
  static const Color surfaceVariant = Color(0xFFEEF0F5); // input fill
  static const Color onSurface = Color(0xFF1A1D23); // main text
  static const Color onSurfaceVariant = Color(0xFF6B7280); // secondary text

  // ── Surfaces (dark) ── guide gives surface + card; the rest are our picks.
  static const Color surfaceDark = Color(0xFF0F1117);
  static const Color cardDark = Color(0xFF1A1D23);
  static const Color surfaceVariantDark = Color(0xFF262A33);
  static const Color onSurfaceDark = Color(0xFFF1F2F5);
  static const Color onSurfaceVariantDark = Color(0xFF9CA3AF);
  static const Color primaryContainerDark = Color(0xFF262C5C);

  /// Lighter brand blue for dark mode: #3B4FE8 on #0F1117 is only ~3:1
  /// contrast (text needs 4.5:1). This one is ~6:1.
  static const Color primaryDark = Color(0xFF7B8BFF);

  /// Dark text on the light [primaryDark] (white on it would be ~3:1).
  static const Color onPrimaryDark = Color(0xFF0F1117);

  static const Color errorDark = Color(0xFFF87171);

  /// Deeper green for BACKGROUNDS with white text: #16A34A + white is only
  /// 3.3:1 contrast (text needs 4.5:1); #15803D + white is 5.0:1.
  static const Color successDeep = Color(0xFF15803D);

  /// Lighter green for dark mode (with dark text on it), like [errorDark].
  static const Color successDark = Color(0xFF4ADE80);

  /// Deeper amber for BACKGROUNDS with white text: #D97706 + white is only
  /// 3.2:1; #B45309 + white is 5.0:1.
  static const Color warningDeep = Color(0xFFB45309);

  /// Lighter amber for dark mode (with dark text on it).
  static const Color warningDark = Color(0xFFFBBF24);
  static const Color errorContainerDark = Color(0xFF3B1518);
  static const Color onErrorContainerDark = Color(0xFFFCA5A5);

  // ── Status ──
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFD97706);
  static const Color error = Color(0xFFDC2626);
  static const Color info = Color(0xFF0284C7);

  static const Color successContainer = Color(0xFFDCFCE7);
  static const Color warningContainer = Color(0xFFFEF3C7);
  static const Color errorContainer = Color(0xFFFEE2E2);
  static const Color infoContainer = Color(0xFFE0F2FE);
}
