import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_paths.dart';
import '../../../../l10n/app_localizations.dart';

/// Placeholder login screen used by Slice 0.1.3 to exercise the auth guard.
/// Real form, validation, and OAuth flow ship in Module 1.
class LoginPage extends StatelessWidget {
  const LoginPage({super.key, this.onSimulatedLogin});

  /// Hook the placeholder "Sign in" button into something the host slice
  /// can wire up (typically a `StubAuthSession.setAuthenticated(value: true)`
  /// followed by `context.goNamed(RoutePaths.dashboardName)`).
  final VoidCallback? onSimulatedLogin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.loginAppBarTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.appName,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: onSimulatedLogin,
                  child: Text(l10n.loginButton),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => context.goNamed(RoutePaths.otpName),
                  child: Text(l10n.loginOtpDemoLink),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
