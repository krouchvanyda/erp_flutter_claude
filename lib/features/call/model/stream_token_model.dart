/// A Stream Video login for the phone (backend `StreamTokenDto`).
///
/// `GET /chats/calls/stream-token` → `{token, apiKey, userId, expiresAt}`.
/// Short-lived (the backend's `token-ttl-minutes`, 60 by default). Our server
/// signs it with the Stream SECRET — that secret never reaches the phone.
class StreamTokenModel {
  const StreamTokenModel({
    required this.token,
    required this.apiKey,
    required this.userId,
    this.expiresAt,
  });

  final String token;
  final String apiKey;
  final String userId;
  final DateTime? expiresAt;

  bool get isUsable =>
      token.isNotEmpty && apiKey.isNotEmpty && userId.isNotEmpty;

  factory StreamTokenModel.fromJson(Map<String, dynamic> json) =>
      StreamTokenModel(
        token: json['token'] as String? ?? '',
        apiKey: json['apiKey'] as String? ?? '',
        userId: '${json['userId'] ?? ''}',
        expiresAt: DateTime.tryParse(
          json['expiresAt'] as String? ?? '',
        )?.toLocal(),
      );

  @override
  bool operator ==(Object other) =>
      other is StreamTokenModel &&
      other.token == token &&
      other.apiKey == apiKey &&
      other.userId == userId &&
      other.expiresAt == expiresAt;

  @override
  int get hashCode => Object.hash(token, apiKey, userId, expiresAt);

  /// Never print the token.
  @override
  String toString() => 'StreamTokenModel(user: $userId)';
}
