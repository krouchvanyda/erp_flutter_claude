import 'package:flutter/material.dart';

import '../../../core/theme/app_font_size.dart';
import '../../../core/theme/app_label.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../model/profile_model.dart';
import 'profile_avatar.dart';

/// Design guide 9.9 "ProfileHeroCard": avatar · name · email ·
/// position + department chips, on a soft brand background.
class ProfileHeroCard extends StatelessWidget {
  const ProfileHeroCard({
    super.key,
    required this.profile,
    this.avatarBusy = false,
  });

  final ProfileModel profile;

  /// Step 4.2: avatar upload running → spinner on the avatar.
  final bool avatarBusy;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final employee = profile.employee;
    final chips = [
      ?employee?.position,
      ?employee?.department,
    ].where((text) => text.trim().isNotEmpty);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        children: [
          ProfileAvatar(profile: profile, busy: avatarBusy),
          const SizedBox(height: AppSpacing.md),
          AppLabel(
            text: profile.displayName,
            fontSize: AppFontSize.value24,
            fontWeight: FontWeight.w700,
            color: colors.onPrimaryContainer,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          AppLabel(
            text: profile.email,
            fontSize: AppFontSize.value14,
            color: colors.onPrimaryContainer.withValues(alpha: 0.75),
            textAlign: TextAlign.center,
          ),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [for (final text in chips) _Chip(text: text)],
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: AppLabel(
        text: text,
        fontSize: AppFontSize.value12,
        fontWeight: FontWeight.w600,
        color: colors.primary,
      ),
    );
  }
}
