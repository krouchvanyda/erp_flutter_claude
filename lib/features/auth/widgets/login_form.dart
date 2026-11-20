import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/validators/form_validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_input_text.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../viewmodel/login_view_model_bloc.dart';

/// Email + password + Sign in. Talks to [LoginViewModelBloc]:
/// - builder  → loading + field errors under the fields
/// - listener → other errors in an [AppSnackBar] (one-time action)
class LoginForm extends StatefulWidget {
  const LoginForm({super.key});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
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
