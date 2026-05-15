import 'package:bloc/bloc.dart';

import '../../../../shared/validators/validators.dart';
import 'login_form_event.dart';
import 'login_form_state.dart';

/// Field-level validation bloc for the Screen 1.1 login form.
///
/// Re-runs the validator on every keystroke so the LoginButton can
/// reactively enable/disable; the page only shows error messages once
/// the field has been touched (state.touched) to avoid yelling at a
/// user who hasn't typed anything yet.
class LoginFormBloc extends Bloc<LoginFormEvent, LoginFormState> {
  LoginFormBloc() : super(const LoginFormState()) {
    on<LoginEmailChanged>(_onEmailChanged);
    on<LoginPasswordChanged>(_onPasswordChanged);
    on<LoginPasswordVisibilityToggled>(_onTogglePasswordVisibility);
  }

  void _onEmailChanged(
    LoginEmailChanged event,
    Emitter<LoginFormState> emit,
  ) {
    emit(state.copyWith(
      email: event.email,
      emailError: Validators.email(event.email),
      touched: true,
    ));
  }

  void _onPasswordChanged(
    LoginPasswordChanged event,
    Emitter<LoginFormState> emit,
  ) {
    emit(state.copyWith(
      password: event.password,
      passwordError: Validators.loginPassword(event.password),
      touched: true,
    ));
  }

  void _onTogglePasswordVisibility(
    LoginPasswordVisibilityToggled event,
    Emitter<LoginFormState> emit,
  ) {
    emit(state.copyWith(passwordVisible: !state.passwordVisible));
  }
}
