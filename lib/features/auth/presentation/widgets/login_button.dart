import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/auth_bloc.dart';
import '../bloc/auth_state.dart';
import '../bloc/login_form_bloc.dart';
import '../bloc/login_form_state.dart';

/// Screen 1.1 — primary action (modernised).
///
/// Taller pill (54 px) with a subtle two-stop gradient + soft shadow
/// when active. Disabled state collapses the gradient to a flat muted
/// fill so it reads as inactive without going washed-out grey.
///
/// Shows an inline spinner during request so the tap is acknowledged
/// before the auth round-trip completes.
class LoginButton extends StatelessWidget {
  const LoginButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        final isLoading = authState is AuthLoading;
        return BlocBuilder<LoginFormBloc, LoginFormState>(
          buildWhen: (a, b) => a.isValid != b.isValid,
          builder: (context, formState) {
            final canSubmit = formState.isValid && !isLoading;
            final primary = theme.colorScheme.primary;
            final gradientStart = primary;
            final gradientEnd = Color.alphaBlend(
              Colors.white.withValues(alpha: 0.18),
              primary,
            );

            return AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              height: 54,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: canSubmit
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [gradientStart, gradientEnd],
                      )
                    : null,
                color: canSubmit
                    ? null
                    : primary.withValues(alpha: 0.35),
                boxShadow: canSubmit
                    ? [
                        BoxShadow(
                          color: primary.withValues(alpha: 0.30),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: canSubmit ? onPressed : null,
                  borderRadius: BorderRadius.circular(16),
                  child: Center(
                    child: isLoading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white),
                            ),
                          )
                        : const Text(
                            'Sign in',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
