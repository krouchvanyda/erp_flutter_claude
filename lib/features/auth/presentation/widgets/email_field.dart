import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../bloc/login_form_bloc.dart';
import '../bloc/login_form_event.dart';
import '../bloc/login_form_state.dart';

/// Screen 1.1 — email input (modernised).
///
/// Filled style with no hard outline at rest. The default border is
/// invisible; only the focused / error border draws so the resting
/// state reads as a soft pill rather than a boxed table cell.
class EmailField extends StatefulWidget {
  const EmailField({super.key, this.enabled = true});
  final bool enabled;

  @override
  State<EmailField> createState() => _EmailFieldState();
}

class _EmailFieldState extends State<EmailField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _resolveError(String? code) {
    switch (code) {
      case 'required':
        return 'Email is required';
      case 'invalid_email':
        return 'Enter a valid email address';
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocBuilder<LoginFormBloc, LoginFormState>(
      buildWhen: (a, b) =>
          a.emailError != b.emailError || a.touched != b.touched,
      builder: (context, state) {
        final error = state.touched ? _resolveError(state.emailError) : null;
        return TextField(
          controller: _controller,
          enabled: widget.enabled,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          textInputAction: TextInputAction.next,
          autocorrect: false,
          enableSuggestions: false,
          style: const TextStyle(fontSize: 15),
          onChanged: (v) =>
              context.read<LoginFormBloc>().add(LoginEmailChanged(v)),
          decoration: InputDecoration(
            labelText: 'Email',
            hintText: 'name@company.com',
            prefixIcon: const Icon(
              Icons.alternate_email_rounded,
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
            errorBorder:
                _border(color: theme.colorScheme.error, width: 1.4),
            focusedErrorBorder:
                _border(color: theme.colorScheme.error, width: 1.6),
            errorText: error,
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
