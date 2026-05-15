import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/biometric_availability.dart';

/// Screen 1.1 — biometric shortcut (modernised).
///
/// "Or continue with" divider + ghost-style icon button. The divider
/// gives the secondary path a visual demotion without using a smaller
/// font, which would clash with the modernised primary button.
///
/// **Visibility rule** (per CLAUDE.md spec): hides itself when the
/// probe reports `false` so the layout collapses cleanly.
class BiometricLoginButton extends StatefulWidget {
  const BiometricLoginButton({
    super.key,
    required this.onPressed,
    this.enabled = true,
  });

  final VoidCallback onPressed;
  final bool enabled;

  @override
  State<BiometricLoginButton> createState() => _BiometricLoginButtonState();
}

class _BiometricLoginButtonState extends State<BiometricLoginButton> {
  late final Future<bool> _availability =
      GetIt.I<BiometricAvailabilityProbe>().isAvailable();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<bool>(
      future: _availability,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == false) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Divider(
                      color: AppColors.neutral200,
                      thickness: 1,
                      endIndent: 12,
                    ),
                  ),
                  Text(
                    'or',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.neutral400,
                      letterSpacing: 1.0,
                    ),
                  ),
                  Expanded(
                    child: Divider(
                      color: AppColors.neutral200,
                      thickness: 1,
                      indent: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 54,
                child: OutlinedButton.icon(
                  onPressed: widget.enabled ? widget.onPressed : null,
                  icon: Icon(
                    Icons.fingerprint,
                    size: 22,
                    color: theme.colorScheme.primary,
                  ),
                  label: Text(
                    'Continue with biometric',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: AppColors.neutral200,
                      width: 1.2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    backgroundColor: AppColors.neutral0,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
