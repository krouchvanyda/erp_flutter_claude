import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/adaptive_status_bar.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../bloc/login_form_bloc.dart';
import '../widgets/biometric_login_button.dart';
import '../widgets/email_field.dart';
import '../widgets/forgot_password_link.dart';
import '../widgets/login_button.dart';
import '../widgets/password_field.dart';

/// Screen 1.1 — Login (modernised).
///
/// **Layout** (top → bottom):
/// ```
///                ╭───────────────────────╮
///                │   ◜ soft gradient blob │  ← decorative,
///                │     ┌────┐             │     low-opacity
///                │     │ 🔒 │             │
///                │     └────┘             │
///                │   Welcome back         │
///                │   Sign in to continue  │
///                │                        │
///                │  ┌───── card ─────┐    │
///                │  │  Email          │   │
///                │  │  Password       │   │
///                │  │      Forgot? →  │   │
///                │  │  [ Sign in    ] │   │
///                │  │  ── or ──       │   │  (only if biometric)
///                │  │  [ Biometric  ] │   │
///                │  └────────────────┘    │
///                │                        │
///                │   Terms · Privacy      │
///                ╰───────────────────────╯
/// ```
///
/// **Two scoped BLoCs**:
///   - [LoginFormBloc] — field-level validation, keystroke-frequent
///   - [AuthBloc]      — sign-in submission, request-frequent
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<LoginFormBloc>(
          create: (_) => LoginFormBloc(),
        ),
        BlocProvider<AuthBloc>(
          create: (_) => GetIt.I<AuthBloc>(),
        ),
      ],
      child: const _LoginView(),
    );
  }
}

class _LoginView extends StatelessWidget {
  const _LoginView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final primary = theme.colorScheme.primary;

    return AdaptiveStatusBar(
      // Page surface is `neutral50` (very light) → dark icons on the
      // status + nav bars so the OS chrome stays readable. Explicit
      // override (not theme-following) because this page renders the
      // same way regardless of the app theme.
      surfaceBrightness: Brightness.light,
      child: Scaffold(
        // Scaffold background draws first; the gradient blobs paint on
        // top so the form card "lifts" off the soft surface.
        backgroundColor: AppColors.neutral50,
        body: BlocListener<AuthBloc, AuthState>(
        listenWhen: (a, b) => a.runtimeType != b.runtimeType,
        listener: _onAuthStateChanged,
        child: Stack(
          children: [
            // ── Decorative gradient blobs ──────────────────────
            Positioned(
              top: -120,
              right: -80,
              child: _Blob(color: primary.withValues(alpha: 0.18), size: 320),
            ),
            Positioned(
              bottom: -160,
              left: -100,
              child: _Blob(
                color: primary.withValues(alpha: 0.10),
                size: 360,
              ),
            ),

            // ── Foreground content ─────────────────────────────
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 24,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Brand mark — bigger, with subtle ring + glow.
                        Center(
                          child: Container(
                            width: 84,
                            height: 84,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  primary,
                                  Color.alphaBlend(
                                    Colors.white.withValues(alpha: 0.18),
                                    primary,
                                  ),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: [
                                BoxShadow(
                                  color: primary.withValues(alpha: 0.30),
                                  blurRadius: 22,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.lock_outline_rounded,
                              size: 38,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Headline.
                        Text(
                          'Welcome back',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: AppColors.neutral900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Sign in to ${l10n.appName}',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: AppColors.neutral600,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // ── Form card ──────────────────────────
                        Container(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                          decoration: BoxDecoration(
                            color: AppColors.neutral0,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const _AuthErrorBanner(),
                              BlocBuilder<AuthBloc, AuthState>(
                                buildWhen: (a, b) =>
                                    (a is AuthLoading) != (b is AuthLoading),
                                builder: (context, state) {
                                  final loading = state is AuthLoading;
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      EmailField(enabled: !loading),
                                      const SizedBox(height: 14),
                                      PasswordField(
                                        enabled: !loading,
                                        onSubmitted: () => _submit(context),
                                      ),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: ForgotPasswordLink(
                                          enabled: !loading,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      LoginButton(
                                        onPressed: () => _submit(context),
                                      ),
                                      BiometricLoginButton(
                                        enabled: !loading,
                                        onPressed: () => context
                                            .read<AuthBloc>()
                                            .add(
                                              const BiometricLoginSubmitted(),
                                            ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Terms — muted footer.
                        RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.neutral600,
                            ),
                            children: [
                              const TextSpan(
                                  text: 'By signing in you agree to our '),
                              TextSpan(
                                text: 'Terms',
                                style: TextStyle(
                                  color: primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const TextSpan(text: ' and '),
                              TextSpan(
                                text: 'Privacy Policy',
                                style: TextStyle(
                                  color: primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const TextSpan(text: '.'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  void _submit(BuildContext context) {
    final form = context.read<LoginFormBloc>().state;
    if (!form.isValid) return;
    context.read<AuthBloc>().add(LoginSubmitted(
          email: form.email.trim(),
          password: form.password,
        ));
  }

  void _onAuthStateChanged(BuildContext context, AuthState state) {
    switch (state) {
      case AuthInitial():
      case AuthLoading():
      case AuthFailure():
        return; // banner handles failure; stay on page
      case AuthSuccess():
        context.goNamed(RoutePaths.dashboardName);
      case AuthMfaRequired():
        context.goNamed(RoutePaths.otpName);
    }
  }
}

/// Soft-edged decorative blob — pure paint, no gestures, no semantics.
///
/// Drawn via a radial gradient inside a fixed-size box so it stays
/// crisp at any scale. We use it as background ambience behind the
/// form card.
class _Blob extends StatelessWidget {
  const _Blob({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
            stops: const [0.0, 1.0],
          ),
        ),
      ),
    );
  }
}

/// Inline failure banner shown inside the form card when [AuthBloc] is
/// in [AuthFailure]. Modernised: rounded-12, danger tint, subtle
/// border, dismiss icon stays compact.
class _AuthErrorBanner extends StatelessWidget {
  const _AuthErrorBanner();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      buildWhen: (a, b) =>
          a is AuthFailure ||
          b is AuthFailure ||
          a.runtimeType != b.runtimeType,
      builder: (context, state) {
        if (state is! AuthFailure) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.danger.withValues(alpha: 0.20),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.danger,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    state.message,
                    style: const TextStyle(
                      color: AppColors.danger,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  iconSize: 18,
                  icon: const Icon(Icons.close_rounded),
                  color: AppColors.danger,
                  onPressed: () => context
                      .read<AuthBloc>()
                      .add(const AuthFailureCleared()),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
