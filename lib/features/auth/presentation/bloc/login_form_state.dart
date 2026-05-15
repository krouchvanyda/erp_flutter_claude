/// Field-level form state for the Screen 1.1 login form.
///
/// **Why a dedicated form state alongside [AuthBloc]**: the form state
/// is keystroke-frequency (every char re-runs the email regex). Mixing
/// that with the auth-side state machine (`AuthInitial → AuthLoading →
/// AuthSuccess/AuthFailure`) would conflate "the user is typing" with
/// "the server returned 401". Two blocs, one screen.
///
/// `emailError` / `passwordError` are validator codes (from
/// [Validators]) — the page maps them to localized copy.
class LoginFormState {
  const LoginFormState({
    this.email = '',
    this.password = '',
    this.emailError,
    this.passwordError,
    this.passwordVisible = false,
    this.touched = false,
  });

  final String email;
  final String password;
  final String? emailError;
  final String? passwordError;
  final bool passwordVisible;

  /// True once either field has been edited at least once. Used to
  /// suppress validation chrome on the *initial* render so the user
  /// doesn't see "required" before they've had a chance to type.
  final bool touched;

  /// True when both fields parse without errors AND non-empty. The
  /// LoginButton uses this to enable / disable.
  bool get isValid =>
      emailError == null &&
      passwordError == null &&
      email.isNotEmpty &&
      password.isNotEmpty;

  LoginFormState copyWith({
    String? email,
    String? password,
    Object? emailError = _sentinel,
    Object? passwordError = _sentinel,
    bool? passwordVisible,
    bool? touched,
  }) {
    return LoginFormState(
      email: email ?? this.email,
      password: password ?? this.password,
      emailError: identical(emailError, _sentinel)
          ? this.emailError
          : emailError as String?,
      passwordError: identical(passwordError, _sentinel)
          ? this.passwordError
          : passwordError as String?,
      passwordVisible: passwordVisible ?? this.passwordVisible,
      touched: touched ?? this.touched,
    );
  }

  static const _sentinel = Object();
}
