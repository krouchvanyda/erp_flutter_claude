/// The token pair the backend gives on login / register / refresh
/// (`AuthResponse` in API_LIST_BACKEND.md).
///
/// - accessToken: short-lived, sent on EVERY request.
/// - refreshToken: long-lived, used ONLY to get a new pair. Rotated: every
///   refresh returns a NEW refresh token, the old one stops working.
class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    this.accessTokenExpiresAt,
    this.refreshTokenExpiresAt,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime? accessTokenExpiresAt;
  final DateTime? refreshTokenExpiresAt;

  factory AuthTokens.fromJson(Map<String, dynamic> json) => AuthTokens(
    accessToken: json['accessToken'] as String,
    refreshToken: json['refreshToken'] as String,
    accessTokenExpiresAt: DateTime.tryParse(
      json['accessTokenExpiresAt'] as String? ?? '',
    ),
    refreshTokenExpiresAt: DateTime.tryParse(
      json['refreshTokenExpiresAt'] as String? ?? '',
    ),
  );

  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'accessTokenExpiresAt': accessTokenExpiresAt?.toIso8601String(),
    'refreshTokenExpiresAt': refreshTokenExpiresAt?.toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      other is AuthTokens &&
      other.accessToken == accessToken &&
      other.refreshToken == refreshToken &&
      other.accessTokenExpiresAt == accessTokenExpiresAt &&
      other.refreshTokenExpiresAt == refreshTokenExpiresAt;

  @override
  int get hashCode => Object.hash(
    accessToken,
    refreshToken,
    accessTokenExpiresAt,
    refreshTokenExpiresAt,
  );

  /// Never print real tokens (logs end up in screenshots and chats).
  @override
  String toString() => 'AuthTokens(access: ***, refresh: ***)';
}
