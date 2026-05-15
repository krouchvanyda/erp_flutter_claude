import 'package:flutter/material.dart';

import '../../core/theme/app_font_sizes.dart';

/// Lightweight typography wrapper that pulls its `fontSize` from the
/// [AppFontSizes] design-token ladder.
///
/// **Why not just use [Text]?**
/// - `Text` accepts a `TextStyle` directly, which means callers
///   sprinkle raw `fontSize: 14` literals around the codebase. Once
///   that habit takes hold, changing the body-medium size means a grep
///   for `14` instead of a single edit.
/// - [AppLabel] wraps the same `Text` widget but only accepts a
///   semantic [variant] (`headlineLarge`, `bodyMedium`, `splashLogo`
///   …). The widget then resolves the font-size token internally —
///   one source of truth.
///
/// Other style axes (`color`, `fontWeight`, `letterSpacing`, …) stay
/// pass-through so it composes with [Theme] / [TextStyle] for one-off
/// emphasis without forcing a custom variant for every tweak.
enum AppLabelVariant {
  displayLarge,
  displayMedium,
  displaySmall,
  headlineLarge,
  headlineMedium,
  headlineSmall,
  titleLarge,
  titleMedium,
  titleSmall,
  bodyLarge,
  bodyMedium,
  bodySmall,
  labelLarge,
  labelMedium,
  labelSmall,
  splashLogo,
}

class AppLabel extends StatelessWidget {
  const AppLabel(
    this.text, {
    super.key,
    this.variant = AppLabelVariant.bodyMedium,
    this.color,
    this.fontWeight,
    this.letterSpacing,
    this.height,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.fontFamily,
  });

  final String text;
  final AppLabelVariant variant;
  final Color? color;
  final FontWeight? fontWeight;
  final double? letterSpacing;
  final double? height;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final String? fontFamily;

  /// Resolves the variant → font-size token from [AppFontSizes].
  double get _resolvedSize {
    switch (variant) {
      case AppLabelVariant.displayLarge:
        return AppFontSizes.displayLarge;
      case AppLabelVariant.displayMedium:
        return AppFontSizes.displayMedium;
      case AppLabelVariant.displaySmall:
        return AppFontSizes.displaySmall;
      case AppLabelVariant.headlineLarge:
        return AppFontSizes.headlineLarge;
      case AppLabelVariant.headlineMedium:
        return AppFontSizes.headlineMedium;
      case AppLabelVariant.headlineSmall:
        return AppFontSizes.headlineSmall;
      case AppLabelVariant.titleLarge:
        return AppFontSizes.titleLarge;
      case AppLabelVariant.titleMedium:
        return AppFontSizes.titleMedium;
      case AppLabelVariant.titleSmall:
        return AppFontSizes.titleSmall;
      case AppLabelVariant.bodyLarge:
        return AppFontSizes.bodyLarge;
      case AppLabelVariant.bodyMedium:
        return AppFontSizes.bodyMedium;
      case AppLabelVariant.bodySmall:
        return AppFontSizes.bodySmall;
      case AppLabelVariant.labelLarge:
        return AppFontSizes.labelLarge;
      case AppLabelVariant.labelMedium:
        return AppFontSizes.labelMedium;
      case AppLabelVariant.labelSmall:
        return AppFontSizes.labelSmall;
      case AppLabelVariant.splashLogo:
        return AppFontSizes.splashLogo;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      style: TextStyle(
        fontSize: _resolvedSize,
        color: color,
        fontWeight: fontWeight,
        letterSpacing: letterSpacing,
        height: height,
        fontFamily: fontFamily,
      ),
    );
  }
}
