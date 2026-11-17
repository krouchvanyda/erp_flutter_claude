import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:erp_mobile/shared/widgets/app_background_gradient.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart' show Trans;

import '../../../core/theme/app_font_size.dart';
import '../../../core/theme/app_label.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/widgets/dynamic_app_bar.dart';
import '../../../core/widgets/dynamic_status_bar.dart';
import '../../../core/i18n/locale_cubit.dart';
import '../models/user_preferences.dart';

/// Slice 9.1.2 — language selector. Switching goes through [LocaleCubit],
/// which saves the choice and redraws every screen immediately.
class LanguagePage extends StatelessWidget {
  const LanguagePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: DynamicAppBar(
        title: 'languagePageTitle'.tr,
        centerTitle: true,
      ),
      body: DynamicStatusBar(
        child: Stack(
          children: [
            // Background Canvas
            AppBackgroundGradient(),
            BlocBuilder<LocaleCubit, Locale>(
              builder: (context, locale) {
                return ListView(
                  padding: EdgeInsets.only(
                    top: context.dynamicAppBarPadding,
                    left: 16,
                    right: 16,
                    bottom: 40,
                  ),
                  children: [
                    AppLabel(
                      text: 'languageSelectPreferredHeading'.tr,
                      fontSize: AppFontSize.value11,
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                    const SizedBox(height: 12),
                    for (final l in AppLanguage.values) ...[
                      _LanguageCard(
                        lang: l,
                        // Enum names double as language codes ('en'/'km').
                        isSelected: locale.languageCode == l.name,
                        onTap: () => context
                            .read<LocaleCubit>()
                            .changeLanguage(l.name),
                      ).animate().fadeIn().slideY(begin: 0.05, end: 0, duration: 300.ms),
                      const SizedBox(height: 16),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  const _LanguageCard({
    required this.lang,
    required this.isSelected,
    required this.onTap,
  });

  final AppLanguage lang;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.01),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            // Flag Circle
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: AppLabel(
                text: _flag(lang),
                fontSize: AppFontSize.value24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppLabel(
                    text: _label(lang),
                    fontSize: AppFontSize.value14,
                    fontWeight: FontWeight.bold,
                  ),
                  const SizedBox(height: 2),
                  AppLabel(
                    text: _nativeLabel(lang),
                    fontSize: AppFontSize.value12,
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? theme.colorScheme.primary
                    : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Icon(
                      Icons.check,
                      color: theme.colorScheme.onPrimary,
                      size: 14,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  String _flag(AppLanguage l) {
    switch (l) {
      case AppLanguage.en:
        return '🇬🇧';
      case AppLanguage.km:
        return '🇰🇭';
    }
  }

  String _label(AppLanguage l) {
    switch (l) {
      case AppLanguage.en:
        return 'languageEnglishLabel'.tr;
      case AppLanguage.km:
        return 'languageKhmerLabel'.tr;
    }
  }

  String _nativeLabel(AppLanguage l) {
    switch (l) {
      case AppLanguage.en:
        return 'languageEnglishNative'.tr;
      case AppLanguage.km:
        return 'languageKhmerNative'.tr;
    }
  }
}
