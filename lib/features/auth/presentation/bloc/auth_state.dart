/// State machine for [AuthBloc] (Screen 1.1).
///
/// `AuthInitial → AuthLoading → AuthSuccess / AuthMfaRequired /
/// AuthFailure`.
///
/// **Why a separate `AuthMfaRequired` state**: server can accept the
/// password but ask for OTP. Folding that into `AuthSuccess` would
/// route the user to /dashboard before they're really signed in;
/// folding it into `AuthFailure` would surface a scary "login failed"
/// banner for what is really a normal next step.
sealed class AuthState {
  const AuthState();
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthSuccess extends AuthState {
  const AuthSuccess();
}

class AuthMfaRequired extends AuthState {
  const AuthMfaRequired();
}

class AuthFailure extends AuthState {
  const AuthFailure(this.message);
  final String message;
}
