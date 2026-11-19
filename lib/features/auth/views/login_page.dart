import 'package:flutter/material.dart';

import '../../../core/router/auth_session.dart';
import '../../../core/theme/app_font_size.dart';
import '../../../core/theme/app_label.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';

/// PLACEHOLDER login (Screen 1.1). Step 3 replaces the button with a real
/// form + LoginBloc + API call.
///
/// Notice: the button does NOT navigate. It flips the session, and
/// `AuthGate` swaps Login → Home.
class LoginPage extends StatelessWidget {
  const LoginPage({super.key, required this.session});

  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(Icons.forum_rounded, color: colors.primary),
              ),
              const SizedBox(height: AppSpacing.lg),
              const AppLabel(
                text: 'Welcome back',
                fontSize: AppFontSize.value24,
                fontWeight: FontWeight.w700,
              ),
              AppLabel(
                text: 'Sign in to your account',
                fontSize: AppFontSize.value14,
                color: colors.onSurfaceVariant,
              ),
              const SizedBox(height: AppSpacing.xxl),
              FilledButton(
                onPressed: session.markAuthenticated,
                child: const AppLabel(
                  text: 'Sign in (demo)',
                  fontSize: AppFontSize.value14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
