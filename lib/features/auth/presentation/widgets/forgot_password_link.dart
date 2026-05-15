import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_paths.dart';

/// Screen 1.1 — link to Screen 1.4 (Forgot Password).
///
/// Modernised: tight hit area + primary-tinted, weighted-up text. Lives
/// right-aligned under the password field — close enough to read as
/// "if you've forgotten this one", muted enough to not compete with
/// the primary Sign-in action.
class ForgotPasswordLink extends StatelessWidget {
  const ForgotPasswordLink({super.key, this.enabled = true});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextButton(
      onPressed: enabled
          ? () => context.pushNamed(RoutePaths.forgotPasswordName)
          : null,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: theme.colorScheme.primary,
      ),
      child: const Text(
        'Forgot password?',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
