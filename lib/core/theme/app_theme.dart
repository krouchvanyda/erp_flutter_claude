import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radius.dart';
import 'app_spacing.dart';
import 'app_status_colors.dart';
import 'app_text_style.dart';

/// Builds [ThemeData] for light and dark mode from the design tokens.
///
/// This is the ONLY file that turns raw [AppColors] into a [ColorScheme].
abstract final class AppTheme {
  static ThemeData light() => _build(_lightScheme);
  static ThemeData dark() => _build(_darkScheme);

  static const ColorScheme _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.primary,
    onPrimary: AppColors.onPrimary,
    primaryContainer: AppColors.primaryContainer,
    onPrimaryContainer: AppColors.primary,
    secondary: AppColors.info,
    onSecondary: AppColors.onPrimary,
    error: AppColors.error,
    onError: AppColors.onPrimary,
    errorContainer: AppColors.errorContainer,
    onErrorContainer: AppColors.error,
    surface: AppColors.surface,
    onSurface: AppColors.onSurface,
    onSurfaceVariant: AppColors.onSurfaceVariant,
    surfaceContainerLowest: AppColors.card,
    surfaceContainerHighest: AppColors.surfaceVariant,
    outline: AppColors.onSurfaceVariant,
    outlineVariant: AppColors.surfaceVariant,
  );

  static const ColorScheme _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AppColors.primaryDark,
    onPrimary: AppColors.onPrimaryDark,
    primaryContainer: AppColors.primaryContainerDark,
    onPrimaryContainer: AppColors.primaryContainer,
    secondary: AppColors.info,
    onSecondary: AppColors.onPrimary,
    error: AppColors.errorDark,
    onError: AppColors.onPrimaryDark,
    errorContainer: AppColors.errorContainerDark,
    onErrorContainer: AppColors.onErrorContainerDark,
    surface: AppColors.surfaceDark,
    onSurface: AppColors.onSurfaceDark,
    onSurfaceVariant: AppColors.onSurfaceVariantDark,
    surfaceContainerLowest: AppColors.cardDark,
    surfaceContainerHighest: AppColors.surfaceVariantDark,
    outline: AppColors.onSurfaceVariantDark,
    outlineVariant: AppColors.surfaceVariantDark,
  );

  static ThemeData _build(ColorScheme scheme) {
    final textTheme =
        TextTheme(
          displayLarge: AppTextStyle.displayLarge,
          displayMedium: AppTextStyle.displayMedium,
          displaySmall: AppTextStyle.displaySmall,
          headlineLarge: AppTextStyle.headlineLarge,
          headlineMedium: AppTextStyle.headlineMedium,
          headlineSmall: AppTextStyle.headlineSmall,
          titleLarge: AppTextStyle.titleLarge,
          titleMedium: AppTextStyle.titleMedium,
          titleSmall: AppTextStyle.titleSmall,
          bodyLarge: AppTextStyle.bodyLarge,
          bodyMedium: AppTextStyle.bodyMedium,
          bodySmall: AppTextStyle.bodySmall,
          labelLarge: AppTextStyle.labelLarge,
          labelMedium: AppTextStyle.labelMedium,
          labelSmall: AppTextStyle.labelSmall,
        ).apply(
          // Colour is added here, once, per brightness.
          bodyColor: scheme.onSurface,
          displayColor: scheme.onSurface,
        );

    final rounded = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      // Colours ColorScheme doesn't have (success). context.statusColors.
      extensions: [
        scheme.brightness == Brightness.dark
            ? AppStatusColors.dark
            : AppStatusColors.light,
      ],
      textTheme: textTheme,
      scaffoldBackgroundColor: scheme.surface,

      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.headlineMedium,
      ),

      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLowest,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: rounded,
          textStyle: textTheme.labelLarge,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: rounded,
          textStyle: textTheme.labelLarge,
        ),
      ),

      // Design guide "InputField": filled, no border at rest,
      // 2px primary border on focus.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.error),
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
