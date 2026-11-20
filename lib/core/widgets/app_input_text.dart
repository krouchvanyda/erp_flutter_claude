import 'package:flutter/material.dart';

import '../theme/app_font_size.dart';
import '../theme/app_label.dart';
import '../theme/app_spacing.dart';

/// Text field with our look (from the MVVM template's `AppInputText`).
///
/// Colors / borders come from `AppTheme.inputDecorationTheme` (filled, 2px
/// primary border on focus) — NOT hard-coded like the template's
/// `Colors.white` / `Colors.grey`, so dark mode works.
class AppInputText extends StatelessWidget {
  const AppInputText({
    super.key,
    required this.controller,
    this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.onChanged,
    this.onFieldSubmitted,
    this.keyboardType = TextInputType.text,
    this.textInputAction,
    this.obscureText = false,
    this.validator,
    this.errorText,
    this.enabled = true,
    this.autofillHints,
    this.label,
    this.minLines,
    this.maxLines = 1,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String? hintText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final TextInputType keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;

  /// Checks done ON THE PHONE (empty, bad email…), see `FormValidators`.
  final String? Function(String?)? validator;

  /// An error FROM THE SERVER for this field (`ServerError.fieldErrors`).
  /// Shown even when [validator] passes.
  final String? errorText;

  final bool enabled;
  final Iterable<String>? autofillHints;

  /// Optional label ABOVE the field ("Email"). Stays visible while typing —
  /// clearer than a hint that disappears.
  final String? label;

  /// Multi-line (chat composer): `minLines: 1, maxLines: 5` grows with the
  /// text, then scrolls. Default: one line.
  final int? minLines;
  final int? maxLines;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    final field = _field();
    if (label == null) return field;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppLabel(
          text: label!,
          fontSize: AppFontSize.value14,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: AppSpacing.xs + 2),
        field,
      ],
    );
  }

  Widget _field() {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
      validator: validator,
      forceErrorText: errorText,
      autofillHints: autofillHints,
      minLines: minLines,
      maxLines: maxLines,
      textCapitalization: textCapitalization,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
      ),
    );
  }
}
