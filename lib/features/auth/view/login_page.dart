import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/config/flavor.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_font_size.dart';
import '../../../core/theme/app_label.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/validators/form_validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_input_text.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../viewmodel/login_view_model_bloc.dart';

/// Screen 1.1 — Login (design guide): calm, single column, no card on phone.
///
/// Responsive:
/// - narrow (< [_wideBreakpoint]) → one column
/// - wide (tablet / landscape)    → brand panel left, form right
/// The form column is never wider than [_formMaxWidth].
///
/// The page never navigates: on success the repository opens the session and
/// `AuthGate` swaps Login → Home.
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  static const double _wideBreakpoint = 720;
  static const double _formMaxWidth = 420;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      // an "edge": may take from the DI box (a fresh bloc — registerFactory)
      create: (_) => getIt<LoginViewModelBloc>(),
      child: Scaffold(
        body: GestureDetector(
          // tap anywhere outside a field → hide the keyboard
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.opaque,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= _wideBreakpoint;
              final form = _FormColumn(showBrandHeader: !wide);
              if (!wide) return SafeArea(child: form);
              return Row(
                children: [
                  const Expanded(flex: 5, child: _BrandPanel()),
                  Expanded(flex: 6, child: SafeArea(child: form)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The form, centered, max 420 wide, scrollable (keyboard), with an entry
/// animation and the flavor badge in the corner.
class _FormColumn extends StatelessWidget {
  const _FormColumn({required this.showBrandHeader});

  /// On phones the brand sits above the form; on wide screens it's the
  /// left panel instead.
  final bool showBrandHeader;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: LoginPage._formMaxWidth,
              ),
              child: _FadeSlideIn(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (showBrandHeader) ...[
                      const _BrandRow(),
                      const SizedBox(height: AppSpacing.xl),
                    ],
                    const _Titles(),
                    const SizedBox(height: AppSpacing.xl),
                    const _LoginForm(),
                    const SizedBox(height: AppSpacing.xl),
                    const _SecureNote(),
                  ],
                ),
              ),
            ),
          ),
        ),
        const Positioned(
          top: AppSpacing.md,
          right: AppSpacing.md,
          child: _FlavorBadge(),
        ),
      ],
    );
  }
}

class _LoginForm extends StatefulWidget {
  const _LoginForm();

  @override
  State<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<_LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  /// UI-only state (not business): is the password visible?
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus(); // hide the keyboard
    AppSnackBar.hide(); // trying again → old error goes away
    if (!_formKey.currentState!.validate()) return; // phone-side checks
    context.read<LoginViewModelBloc>().add(
      OnLoginSubmittedEvent(email: _email.text, password: _password.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LoginViewModelBloc, LoginViewModelState>(
      // LISTENER = one-time actions (snackbar). Field errors are shown
      // under the fields instead, so no snackbar for them.
      listenWhen: (previous, current) =>
          current is LoginErrorState && current.fieldErrors.isEmpty,
      listener: (context, state) {
        if (state is LoginErrorState) {
          AppSnackBar.error(
            context,
            title: state.error.title,
            message: state.error.description,
          );
        }
      },
      // BUILDER = what the form looks like (loading, field errors).
      buildWhen: (previous, current) => current is! LoginSuccessState,
      builder: (context, state) {
        final loading = state is LoginLoadingState;
        final fieldErrors = state is LoginErrorState
            ? state.fieldErrors
            : const <String, String>{};

        return Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppInputText(
                  label: 'Email',
                  controller: _email,
                  hintText: 'you@company.com',
                  prefixIcon: const Icon(Icons.email_outlined),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  enabled: !loading,
                  validator: FormValidators.loginEmail,
                  errorText: fieldErrors['email'],
                ),
                const SizedBox(height: AppSpacing.md),
                AppInputText(
                  label: 'Password',
                  controller: _password,
                  hintText: 'At least 6 characters',
                  prefixIcon: const Icon(Icons.lock_outline),
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  enabled: !loading,
                  validator: FormValidators.loginPassword,
                  errorText: fieldErrors['password'],
                  onFieldSubmitted: (_) => _submit(),
                  suffixIcon: IconButton(
                    tooltip: _obscure ? 'Show password' : 'Hide password',
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  text: 'Sign in',
                  isLoading: loading,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────── small pieces ───────────────────────────

/// Phone: app icon + app name in one row.
class _BrandRow extends StatelessWidget {
  const _BrandRow();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Icon(Icons.forum_rounded, color: colors.primary, size: 28),
        ),
        const SizedBox(width: AppSpacing.md),
        AppLabel(
          text: Flavor.current.appName,
          fontSize: AppFontSize.value20,
          fontWeight: FontWeight.w700,
        ),
      ],
    );
  }
}

class _Titles extends StatelessWidget {
  const _Titles();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppLabel(
          text: 'Welcome back',
          fontSize: AppFontSize.value28,
          fontWeight: FontWeight.w700,
        ),
        const SizedBox(height: AppSpacing.xs),
        AppLabel(
          text: 'Sign in to your account',
          fontSize: AppFontSize.value16,
          color: colors.onSurfaceVariant,
        ),
      ],
    );
  }
}

/// Wide screens: a calm brand panel in the primary colour.
class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.primary,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: colors.onPrimary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                ),
                child: Icon(
                  Icons.forum_rounded,
                  color: colors.onPrimary,
                  size: 40,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppLabel(
                text: Flavor.current.appName,
                fontSize: AppFontSize.value32,
                fontWeight: FontWeight.w700,
                color: colors.onPrimary,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppLabel(
                text: 'Chat, voice and video calls —\nyour team, in one place.',
                fontSize: AppFontSize.value16,
                color: colors.onPrimary.withValues(alpha: 0.85),
                lineHeight: 1.5,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A quiet reassurance line under the form.
class _SecureNote extends StatelessWidget {
  const _SecureNote();

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.verified_user_outlined, size: 16, color: muted),
        const SizedBox(width: AppSpacing.xs),
        AppLabel(
          text: 'Secured connection',
          fontSize: AppFontSize.value12,
          color: muted,
        ),
      ],
    );
  }
}

/// "DEV" / "UAT" pill so testers know which server they use. Hidden in prod.
class _FlavorBadge extends StatelessWidget {
  const _FlavorBadge();

  @override
  Widget build(BuildContext context) {
    final flavor = Flavor.current;
    if (flavor == Flavor.prod) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: AppLabel(
        text: flavor.name.toUpperCase(),
        fontSize: AppFontSize.value11,
        fontWeight: FontWeight.w600,
        color: colors.onPrimaryContainer,
        letterSpacing: 0.8,
      ),
    );
  }
}

/// Fade + small slide up, once, when the page appears (300 ms, calm).
class _FadeSlideIn extends StatelessWidget {
  const _FadeSlideIn({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      child: child, // built once, not on every animation frame
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - t)),
          child: child,
        ),
      ),
    );
  }
}
