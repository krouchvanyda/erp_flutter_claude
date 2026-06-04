import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:erp_mobile/core/di/app_dependencies.dart';
import 'package:erp_mobile/core/theme/app_font_size.dart';
import 'package:erp_mobile/core/theme/app_label.dart';
import 'package:erp_mobile/core/widgets/dynamic_status_bar.dart';
import 'package:erp_mobile/l10n/app_localizations.dart';
import 'package:erp_mobile/features/authentication/view_models/biometric_unlock_view_model.dart';

class BiometricUnlockScreen extends StatelessWidget {
  const BiometricUnlockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => BiometricUnlockViewModel(
        demoSignIn: AppDependencies.I.demoSignInService,
        authSession: AppDependencies.I.authSession,
      ),
      child: BlocListener<BiometricUnlockViewModel, BiometricUnlockState>(
        listenWhen: (previous, current) =>
            previous.status != current.status,
        listener: (context, state) {
          // Pop this page (pushed on top of LoginScreen). The Cubit's
          // simulateSignIn fired the router's refreshListenable, so the
          // auth-redirect policy bounces the now-revealed `/login` to
          // `/dashboard`. Calling `goNamed(dashboard)` directly is a
          // no-op here because go_router still thinks we're on `/login`.
          if (state.isAuthenticated && Navigator.canPop(context)) {
            Navigator.pop(context);
          }
        },
        child: const _BiometricUnlockView(),
      ),
    );
  }
}

class _BiometricUnlockView extends StatelessWidget {
  const _BiometricUnlockView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isAuthenticating =
        context.watch<BiometricUnlockViewModel>().state.isAuthenticating;

    return Scaffold(
      body: DynamicStatusBar(
        child: Stack(
          children: [
            // Background Gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                    theme.colorScheme.surface,
                  ],
                ),
              ),
            ),
            
            SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Animated Biometric Icon
                      Container(
                        padding: const EdgeInsets.all(40),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.colorScheme.primary.withValues(alpha: 0.2),
                            width: 2,
                          ),
                        ),
                        child: isAuthenticating 
                          ? const SizedBox(
                              width: 100,
                              height: 100,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              Icons.fingerprint_rounded,
                              size: 100,
                              color: theme.colorScheme.primary,
                            ),
                      )
                          .animate(onPlay: (controller) => controller.repeat(reverse: true))
                          .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 2000.ms, curve: Curves.easeInOut)
                          .animate()
                          .fadeIn(duration: 800.ms),
                      
                      const SizedBox(height: 48),
                      
                      AppLabel(
                        text: isAuthenticating ? l10n.biometricAuthenticatingTitle : l10n.biometricPageTitle,
                        fontSize: AppFontSize.value22,
                        fontWeight: FontWeight.bold,
                      ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2, end: 0),

                      const SizedBox(height: 16),

                      AppLabel(
                        text: isAuthenticating
                          ? l10n.biometricHoldFingerSubtitle
                          : l10n.biometricUseFingerprintSubtitle,
                        fontSize: AppFontSize.value16,
                        color: theme.colorScheme.onSurfaceVariant,
                        textAlign: TextAlign.center,
                      ).animate().fadeIn(delay: 600.ms),
                      
                      const SizedBox(height: 64),
                      
                      // Action Buttons
                      if (!isAuthenticating)
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 300),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              FilledButton(
                                onPressed: () => context
                                    .read<BiometricUnlockViewModel>()
                                    .authenticate(),
                                child: Text(l10n.biometricUnlockNowAction),
                              ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.5, end: 0),

                              const SizedBox(height: 16),

                              TextButton(
                                // This page is pushed onto the root
                                // Navigator from LoginScreen via
                                // ConfigRouter; go_router's location
                                // is still `/login`, so `goNamed(login)`
                                // is a no-op. Pop instead — reveals
                                // the LoginScreen that pushed us here.
                                onPressed: () => Navigator.pop(context),
                                child: Text(l10n.biometricUsePasswordInsteadAction),
                              ).animate().fadeIn(delay: 1000.ms),
                            ],
                          ),
                        ).animate().fadeIn(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
