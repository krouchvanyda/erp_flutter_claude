import 'package:flutter/material.dart';

import 'app_text_style.dart';

/// Reusable text widget: `Text` + our font, Khmer fallback and defaults.
///
/// ```dart
/// AppLabel(
///   text: 'Welcome back',
///   fontSize: AppFontSize.value24,
///   fontWeight: FontWeight.w700,
/// )
/// ```
///
/// [color] is optional: when null, `Text` takes the colour from its parent
/// (page text colour, white inside a FilledButton, blue inside an
/// OutlinedButton…), so it works in light AND dark mode. Pass a colour only
/// for special cases, e.g. `Theme.of(context).colorScheme.onSurfaceVariant`.
class AppLabel extends StatelessWidget {
  const AppLabel({
    super.key,
    required this.text,
    required this.fontSize,
    this.color,
    this.fontWeight = FontWeight.normal,
    this.lineHeight = 1.3,
    this.textAlign = TextAlign.start,
    this.textDecoration = TextDecoration.none,
    this.decorationColor,
    this.overflow = TextOverflow.fade,
    this.maxLines,
    this.fontFamily = AppTextStyle.defaultFontFamily,
    this.letterSpacing,
    this.softWrap = true,
  });

  final String text;
  final String fontFamily;
  final double fontSize;
  final Color? color;
  final FontWeight fontWeight;
  final double lineHeight;
  final TextAlign textAlign;
  final TextDecoration textDecoration;
  final Color? decorationColor;
  final TextOverflow overflow;
  final int? maxLines;
  final double? letterSpacing;
  final bool? softWrap;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      softWrap: softWrap,
      // AppTextStyle.build = google_fonts (really loads Inter) + Khmer
      // fallback. `color: null` → inherit from the parent widget.
      style: AppTextStyle.build(
        fontSize: fontSize,
        fontFamily: fontFamily,
        fontWeight: fontWeight,
        color: color,
        lineHeight: lineHeight,
        letterSpacing: letterSpacing,
        decoration: textDecoration,
        decorationColor: decorationColor,
      ),
    );
  }
}
