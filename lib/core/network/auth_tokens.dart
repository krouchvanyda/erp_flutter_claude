/// Pair of OAuth-style access + refresh tokens persisted by [TokenStorage]
/// and rotated by [TokenRefresher].
///
/// `accessExpiresAt` is optional — populated when the auth server returns an
/// `expires_in`, so future slices can do *proactive* refresh ahead of the
/// 401-driven *reactive* refresh wired in this slice.
class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    this.accessExpiresAt,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime? accessExpiresAt;

  static const Object _undefined = Object();

  AuthTokens copyWith({
    String? accessToken,
    String? refreshToken,
    Object? accessExpiresAt = _undefined,
  }) {
    return AuthTokens(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      accessExpiresAt: identical(accessExpiresAt, _undefined)
          ? this.accessExpiresAt
          : accessExpiresAt as DateTime?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthTokens &&
          runtimeType == other.runtimeType &&
          accessToken == other.accessToken &&
          refreshToken == other.refreshToken &&
          accessExpiresAt == other.accessExpiresAt;

  @override
  int get hashCode =>
      Object.hash(runtimeType, accessToken, refreshToken, accessExpiresAt);
}
