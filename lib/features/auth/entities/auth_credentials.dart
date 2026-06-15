/// Email + password pair submitted to the sign-in use case.
///
/// Domain-layer guards (`isValid`, `validate`) catch the obvious shape
/// errors so the use case can fail fast. Plain immutable value type (was
/// `freezed`; the codegen was removed).
class AuthCredentials {
  const AuthCredentials({
    required this.email,
    required this.password,
  });

  /// Empty pair — useful as the initial state in form holders.
  factory AuthCredentials.empty() =>
      const AuthCredentials(email: '', password: '');

  final String email;
  final String password;

  /// Coarse-grained "could plausibly be a credential pair" check.
  bool get isValid =>
      _isPlausibleEmail(email.trim()) && password.length >= _minPasswordLength;

  /// Returns the first invariant the credentials violate, or null when
  /// they pass.
  CredentialIssue? validate() {
    if (email.trim().isEmpty) return CredentialIssue.emailMissing;
    if (!_isPlausibleEmail(email.trim())) return CredentialIssue.emailMalformed;
    if (password.isEmpty) return CredentialIssue.passwordMissing;
    if (password.length < _minPasswordLength) {
      return CredentialIssue.passwordTooShort;
    }
    return null;
  }

  AuthCredentials copyWith({String? email, String? password}) =>
      AuthCredentials(
        email: email ?? this.email,
        password: password ?? this.password,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AuthCredentials &&
          other.email == email &&
          other.password == password);

  @override
  int get hashCode => Object.hash(email, password);
}

/// Reason a [AuthCredentials.validate] check failed.
enum CredentialIssue {
  emailMissing,
  emailMalformed,
  passwordMissing,
  passwordTooShort,
}

const int _minPasswordLength = 8;

// Deliberately permissive — anything with `local@domain.tld` shape passes.
final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
bool _isPlausibleEmail(String s) => _emailPattern.hasMatch(s);
