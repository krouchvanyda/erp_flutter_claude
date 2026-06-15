/// Pair of OAuth-style access + refresh tokens persisted by [TokenStorage]
/// and rotated by [TokenRefresher].
///
/// Plain immutable value type (was `freezed`; the codegen was removed).
class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    this.accessExpiresAt,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime? accessExpiresAt;

  AuthTokens copyWith({
    String? accessToken,
    String? refreshToken,
    DateTime? accessExpiresAt,
  }) =>
      AuthTokens(
        accessToken: accessToken ?? this.accessToken,
        refreshToken: refreshToken ?? this.refreshToken,
        accessExpiresAt: accessExpiresAt ?? this.accessExpiresAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AuthTokens &&
          other.accessToken == accessToken &&
          other.refreshToken == refreshToken &&
          other.accessExpiresAt == accessExpiresAt);

  @override
  int get hashCode => Object.hash(accessToken, refreshToken, accessExpiresAt);
}
