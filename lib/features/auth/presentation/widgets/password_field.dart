import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../bloc/login_form_bloc.dart';
import '../bloc/login_form_event.dart';
import '../bloc/login_form_state.dart';

/// Screen 1.1 — password input with toggleable obscure/visible.
///
/// Modernised: filled style, soft pill at rest, focus reveals the
/// primary border. Visibility toggle still lives in the form bloc so
/// state survives rebuilds (bottom sheet, biometric prompt, …).
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    this.enabled = true,
    this.onSubmitted,
  });

  final bool enabled;
  final VoidCallback? onSubmitted;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _resolveError(String? code) {
    switch (code) {
      case 'required':
        return 'Password is required';
      case 'too_short':
        return 'Password is too short';
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocBuilder<LoginFormBloc, LoginFormState>(
      buildWhen: (a, b) =>
          a.passwordError != b.passwordError ||
          a.passwordVisible != b.passwordVisible ||
          a.touched != b.touched,
      builder: (context, state) {
        final error =
            state.touched ? _resolveError(state.passwordError) : null;
        return TextField(
          controller: _controller,
          enabled: widget.enabled,
          obscureText: !state.passwordVisible,
          autofillHints: const [AutofillHints.password],
          textInputAction: TextInputAction.done,
          style: const TextStyle(fontSize: 15, letterSpacing: 0.4),
          onSubmitted: (_) => widget.onSubmitted?.call(),
          onChanged: (v) =>
              context.read<LoginFormBloc>().add(LoginPasswordChanged(v)),
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: const Icon(
              Icons.lock_outline_rounded,
              color: AppColors.neutral400,
            ),
            filled: true,
            fillColor: AppColors.neutral50,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: _border(),
            enabledBorder: _border(),
            disabledBorder: _border(),
            focusedBorder:
                _border(color: theme.colorScheme.primary, width: 1.6),
            errorBorder: _border(color: theme.colorScheme.error, width: 1.4),
            focusedErrorBorder:
                _border(color: theme.colorScheme.error, width: 1.6),
            errorText: error,
            suffixIcon: IconButton(
              tooltip: state.passwordVisible
                  ? 'Hide password'
                  : 'Show password',
              icon: Icon(
                state.passwordVisible
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AppColors.neutral400,
              ),
              onPressed: () => context
                  .read<LoginFormBloc>()
                  .add(const LoginPasswordVisibilityToggled()),
            ),
          ),
        );
      },
    );
  }

  OutlineInputBorder _border({Color? color, double width = 1.0}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(
        color: color ?? Colors.transparent,
        width: width,
      ),
    );
  }
}
