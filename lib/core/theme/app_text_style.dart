import 'package:flutter/painting.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_font_size.dart';

/// Text styles (from ERP_MOBILE_DESIGN_GUIDE.md §2.2) + one style builder.
///
/// - The named styles (`titleMedium`, …) feed `ThemeData.textTheme` in
///   `AppTheme`, so Material widgets (AppBar, buttons, ListTile) use them.
/// - [build] is used by the `AppLabel` widget for custom text.
/// - All 15 Material slots are filled, so no widget falls back to Roboto
///   (which has no Khmer).
///
/// No colour on the named styles: `AppTheme` adds it per light/dark mode.
abstract final class AppTextStyle {
  /// Default font from the design guide. Change here to switch the whole app
  /// (any Google Font name works, e.g. 'Poppins').
  static const String defaultFontFamily = 'Inter';

  /// Khmer letters are not in Inter/Poppins → Flutter falls back to this.
  static final String khmerFallback = GoogleFonts.notoSansKhmer().fontFamily!;

  /// Builds a [TextStyle] with the given font + Khmer fallback.
  static TextStyle build({
    required double fontSize,
    String fontFamily = defaultFontFamily,
    FontWeight fontWeight = FontWeight.normal,
    Color? color,
    double? lineHeight,
    double? letterSpacing,
    TextDecoration? decoration,
    Color? decorationColor,
  }) {
    return GoogleFonts.getFont(
      fontFamily,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: lineHeight,
      letterSpacing: letterSpacing,
      decoration: decoration,
      decorationColor: decorationColor,
    ).copyWith(fontFamilyFallback: [khmerFallback]);
  }

  static TextStyle _style(double size, FontWeight weight) =>
      build(fontSize: size, fontWeight: weight);

  /// Splash app name.
  static final TextStyle displayLarge = _style(
    AppFontSize.value32,
    FontWeight.w700,
  );

  /// Big numbers / hero text. (not in guide — our pick)
  static final TextStyle displayMedium = _style(
    AppFontSize.value28,
    FontWeight.w700,
  );

  /// Large hero text. (not in guide — our pick)
  static final TextStyle displaySmall = _style(
    AppFontSize.value24,
    FontWeight.w700,
  );

  /// Page titles.
  static final TextStyle headlineLarge = _style(
    AppFontSize.value24,
    FontWeight.w700,
  );

  /// Section headers, card titles.
  static final TextStyle headlineMedium = _style(
    AppFontSize.value20,
    FontWeight.w600,
  );

  /// Dialog titles. (not in guide — our pick)
  static final TextStyle headlineSmall = _style(
    AppFontSize.value18,
    FontWeight.w600,
  );

  /// Large titles. (not in guide — our pick)
  static final TextStyle titleLarge = _style(
    AppFontSize.value20,
    FontWeight.w600,
  );

  /// List tile titles, tab labels.
  static final TextStyle titleMedium = _style(
    AppFontSize.value16,
    FontWeight.w600,
  );

  /// Small titles, TabBar labels. (not in guide — our pick)
  static final TextStyle titleSmall = _style(
    AppFontSize.value14,
    FontWeight.w600,
  );

  /// Body text; text typed in a TextField.
  static final TextStyle bodyLarge = _style(
    AppFontSize.value16,
    FontWeight.w400,
  );

  /// Secondary info, subtitles.
  static final TextStyle bodyMedium = _style(
    AppFontSize.value14,
    FontWeight.w400,
  );

  /// Timestamps, captions.
  static final TextStyle bodySmall = _style(
    AppFontSize.value12,
    FontWeight.w400,
  );

  /// Button labels.
  static final TextStyle labelLarge = _style(
    AppFontSize.value14,
    FontWeight.w600,
  );

  /// Small labels. (not in guide — our pick)
  static final TextStyle labelMedium = _style(
    AppFontSize.value12,
    FontWeight.w500,
  );

  /// Status chips, badges.
  static final TextStyle labelSmall = _style(
    AppFontSize.value11,
    FontWeight.w500,
  );
}
