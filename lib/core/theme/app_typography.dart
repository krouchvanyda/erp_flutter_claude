import 'package:flutter/material.dart';

/// Typography scale tuned for an enterprise ERP — legible body type at
/// dense data-table sizes, tight headlines for KPI tiles, monospace numerics
/// for currency/quantity columns.
abstract final class AppTypography {
  static const String _sansFamily  = 'Roboto';     // Material default
  static const String _monoFamily  = 'RobotoMono'; // future-proof for fonts
  // ── Letter spacings tuned to M3 defaults ─────────────────────
  static const double _displayTracking = -0.25;
  static const double _headlineTracking = 0;
  static const double _titleTracking    = 0.15;
  static const double _bodyTracking     = 0.25;
  static const double _labelTracking    = 0.5;

  /// Returns a complete [TextTheme]. Colours are deliberately omitted —
  /// `ThemeData` resolves them from the active [ColorScheme].
  static TextTheme textTheme() => const TextTheme(
        displayLarge: TextStyle(
          fontFamily: _sansFamily,
          fontSize: 57, height: 1.12, fontWeight: FontWeight.w400,
          letterSpacing: _displayTracking,
        ),
        displayMedium: TextStyle(
          fontFamily: _sansFamily,
          fontSize: 45, height: 1.15, fontWeight: FontWeight.w400,
          letterSpacing: _displayTracking,
        ),
        displaySmall: TextStyle(
          fontFamily: _sansFamily,
          fontSize: 36, height: 1.22, fontWeight: FontWeight.w400,
          letterSpacing: _displayTracking,
        ),
        headlineLarge: TextStyle(
          fontFamily: _sansFamily,
          fontSize: 32, height: 1.25, fontWeight: FontWeight.w600,
          letterSpacing: _headlineTracking,
        ),
        headlineMedium: TextStyle(
          fontFamily: _sansFamily,
          fontSize: 28, height: 1.28, fontWeight: FontWeight.w600,
          letterSpacing: _headlineTracking,
        ),
        headlineSmall: TextStyle(
          fontFamily: _sansFamily,
          fontSize: 24, height: 1.33, fontWeight: FontWeight.w600,
          letterSpacing: _headlineTracking,
        ),
        titleLarge: TextStyle(
          fontFamily: _sansFamily,
          fontSize: 20, height: 1.40, fontWeight: FontWeight.w600,
          letterSpacing: _titleTracking,
        ),
        titleMedium: TextStyle(
          fontFamily: _sansFamily,
          fontSize: 16, height: 1.50, fontWeight: FontWeight.w600,
          letterSpacing: _titleTracking,
        ),
        titleSmall: TextStyle(
          fontFamily: _sansFamily,
          fontSize: 14, height: 1.42, fontWeight: FontWeight.w600,
          letterSpacing: _titleTracking,
        ),
        bodyLarge: TextStyle(
          fontFamily: _sansFamily,
          fontSize: 16, height: 1.50, fontWeight: FontWeight.w400,
          letterSpacing: _bodyTracking,
        ),
        bodyMedium: TextStyle(
          fontFamily: _sansFamily,
          fontSize: 14, height: 1.42, fontWeight: FontWeight.w400,
          letterSpacing: _bodyTracking,
        ),
        bodySmall: TextStyle(
          fontFamily: _sansFamily,
          fontSize: 12, height: 1.33, fontWeight: FontWeight.w400,
          letterSpacing: _bodyTracking,
        ),
        labelLarge: TextStyle(
          fontFamily: _sansFamily,
          fontSize: 14, height: 1.42, fontWeight: FontWeight.w600,
          letterSpacing: _labelTracking,
        ),
        labelMedium: TextStyle(
          fontFamily: _sansFamily,
          fontSize: 12, height: 1.33, fontWeight: FontWeight.w600,
          letterSpacing: _labelTracking,
        ),
        labelSmall: TextStyle(
          fontFamily: _sansFamily,
          fontSize: 11, height: 1.45, fontWeight: FontWeight.w600,
          letterSpacing: _labelTracking,
        ),
      );

  /// Tabular-figures style for currency / quantity / id columns.
  /// Use via `Text('1,234.56', style: AppTypography.numericMono(context))`.
  static TextStyle numericMono(BuildContext context) {
    return Theme.of(context).textTheme.bodyMedium!.copyWith(
          fontFamily: _monoFamily,
          fontFeatures: const [FontFeature.tabularFigures()],
        );
  }
}
