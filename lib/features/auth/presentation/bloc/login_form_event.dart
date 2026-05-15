/// Inputs to [LoginFormBloc] (Screen 1.1).
sealed class LoginFormEvent {
  const LoginFormEvent();
}

class LoginEmailChanged extends LoginFormEvent {
  const LoginEmailChanged(this.email);
  final String email;
}

class LoginPasswordChanged extends LoginFormEvent {
  const LoginPasswordChanged(this.password);
  final String password;
}

class LoginPasswordVisibilityToggled extends LoginFormEvent {
  const LoginPasswordVisibilityToggled();
}
