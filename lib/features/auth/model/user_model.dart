/// The signed-in user, as the backend sends it in the login `user` object
/// and from `GET /api/v1/users/me`:
///
/// ```json
/// { "id": 1, "email": "user@example.com", "fullName": "Jane Doe",
///   "phone": "012345678", "avatarUrl": null }
/// ```
///
/// No `roles` / `permissions` here: the backend only sends them on the admin
/// user endpoints, which this app doesn't use.
class UserModel {
  const UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    this.phone,
    this.avatarUrl,
  });

  final String id;
  final String email;
  final String fullName;
  final String? phone;

  /// A server path like `/uploads/...` (or null). Step 4 turns it into a full
  /// URL for the avatar image.
  final String? avatarUrl;

  /// Fallback for the UI: never show an empty name.
  String get displayName => fullName.trim().isEmpty ? email : fullName;

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id: '${json['id'] ?? ''}', // the backend sends a number: 1 → "1"
    email: json['email'] as String? ?? '',
    fullName: json['fullName'] as String? ?? '',
    phone: json['phone'] as String?,
    avatarUrl: json['avatarUrl'] as String?,
  );

  /// Profile edit (Step 4) changes one field and keeps the rest.
  UserModel copyWith({String? fullName, String? phone, String? avatarUrl}) =>
      UserModel(
        id: id,
        email: email,
        fullName: fullName ?? this.fullName,
        phone: phone ?? this.phone,
        avatarUrl: avatarUrl ?? this.avatarUrl,
      );

  @override
  bool operator ==(Object other) =>
      other is UserModel &&
      other.id == id &&
      other.email == email &&
      other.fullName == fullName &&
      other.phone == phone &&
      other.avatarUrl == avatarUrl;

  @override
  int get hashCode => Object.hash(id, email, fullName, phone, avatarUrl);

  @override
  String toString() => 'UserModel($id, $email)';
}
