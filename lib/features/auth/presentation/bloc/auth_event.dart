/// Inputs to [AuthBloc] (Screen 1.1).
///
/// Sealed so adding a new auth pathway (SSO redirect, biometric
/// unlock) becomes a compile-error switch in the bloc, not a silent
/// miss.
sealed class AuthEvent {
  const AuthEvent();
}

class LoginSubmitted extends AuthEvent {
  const LoginSubmitted({required this.email, required this.password});
  final String email;
  final String password;
}

class BiometricLoginSubmitted extends AuthEvent {
  const BiometricLoginSubmitted();
}

/// Returns the bloc to `AuthInitial` so the page can dismiss a
/// failure banner without re-mounting.
class AuthFailureCleared extends AuthEvent {
  const AuthFailureCleared();
}
