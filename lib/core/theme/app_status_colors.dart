import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Status colours in ONE place: success · warning · error.
///
/// Flutter's [ColorScheme] has `error` but no `success` or `warning`, so
/// they live in the theme as a [ThemeExtension]. They flip with light / dark
/// mode like every other colour. ([error] matches `colorScheme.error`.)
///
/// ```dart
/// final status = context.statusColors;
/// Container(color: status.warning, child: Icon(..., color: status.onWarning))
/// ```
///
/// Every `xxx` is a BACKGROUND colour and `onXxx` is the text / icon on it.
/// Each pair reaches at least 4.5:1 contrast (small text, WCAG AA):
///
/// ```
///            LIGHT                       DARK
/// success    #15803D + white  5.0:1      #4ADE80 + dark  10.8:1
/// warning    #B45309 + white  5.0:1      #FBBF24 + dark  11.3:1
/// error      #DC2626 + white  4.8:1      #F87171 + dark   6.8:1
/// ```
/// Light mode uses a DEEPER shade than the design tokens (#16A34A, #D97706),
/// because white text on those is only ~3.2:1.
@immutable
class AppStatusColors extends ThemeExtension<AppStatusColors> {
  const AppStatusColors({
    required this.success,
    required this.onSuccess,
    required this.warning,
    required this.onWarning,
    required this.error,
    required this.onError,
  });

  /// "It worked" (Photo updated).
  final Color success;
  final Color onSuccess;

  /// "Careful, but not broken" (weak connection, file too big…).
  final Color warning;
  final Color onWarning;

  /// "It failed" (network error, wrong password…).
  final Color error;
  final Color onError;

  static const light = AppStatusColors(
    success: AppColors.successDeep,
    onSuccess: AppColors.onPrimary,
    warning: AppColors.warningDeep,
    onWarning: AppColors.onPrimary,
    error: AppColors.error,
    onError: AppColors.onPrimary,
  );

  /// Dark: lighter colours + dark text — deep colours vanish on a dark page.
  static const dark = AppStatusColors(
    success: AppColors.successDark,
    onSuccess: AppColors.onPrimaryDark,
    warning: AppColors.warningDark,
    onWarning: AppColors.onPrimaryDark,
    error: AppColors.errorDark,
    onError: AppColors.onPrimaryDark,
  );

  @override
  AppStatusColors copyWith({
    Color? success,
    Color? onSuccess,
    Color? warning,
    Color? onWarning,
    Color? error,
    Color? onError,
  }) => AppStatusColors(
    success: success ?? this.success,
    onSuccess: onSuccess ?? this.onSuccess,
    warning: warning ?? this.warning,
    onWarning: onWarning ?? this.onWarning,
    error: error ?? this.error,
    onError: onError ?? this.onError,
  );

  /// Smooth colour change when the theme switches light ↔ dark.
  @override
  AppStatusColors lerp(AppStatusColors? other, double t) {
    if (other == null) return this;
    return AppStatusColors(
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      error: Color.lerp(error, other.error, t)!,
      onError: Color.lerp(onError, other.onError, t)!,
    );
  }
}

/// `context.statusColors` instead of
/// `Theme.of(context).extension<AppStatusColors>()!`.
extension AppStatusColorsX on BuildContext {
  AppStatusColors get statusColors =>
      Theme.of(this).extension<AppStatusColors>() ?? AppStatusColors.light;
}
