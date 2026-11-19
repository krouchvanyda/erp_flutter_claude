import 'package:collection/collection.dart';

/// The signed-in user (`UserDto` on the backend).
///
/// Parsing is tolerant: `id` may be a number or a string, the name may come
/// as `fullName` / `name` / `displayName` (learned from the old app).
class UserModel {
  const UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    this.phone,
    this.roles = const [],
    this.permissions = const [],
  });

  final String id;
  final String email;
  final String fullName;
  final String? phone;
  final List<String> roles;
  final List<String> permissions;

  /// Fallback for the UI: never show an empty name.
  String get displayName => fullName.trim().isEmpty ? email : fullName;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    List<String> strings(String key) => switch (json[key]) {
      final List<dynamic> list => [
        for (final e in list)
          // roles may be "ADMIN" or {"code": "ADMIN", ...}
          if (e is Map) '${e['code'] ?? e['name'] ?? ''}' else '$e',
      ],
      _ => const [],
    };

    return UserModel(
      id: '${json['id'] ?? ''}',
      email: json['email'] as String? ?? '',
      fullName:
          (json['fullName'] ?? json['name'] ?? json['displayName'] ?? '')
              as String,
      phone: json['phone'] as String?,
      roles: strings('roles'),
      permissions: strings('permissions'),
    );
  }

  static const _list = ListEquality<String>();

  @override
  bool operator ==(Object other) =>
      other is UserModel &&
      other.id == id &&
      other.email == email &&
      other.fullName == fullName &&
      other.phone == phone &&
      _list.equals(other.roles, roles) &&
      _list.equals(other.permissions, permissions);

  @override
  int get hashCode => Object.hash(
    id,
    email,
    fullName,
    phone,
    _list.hash(roles),
    _list.hash(permissions),
  );

  @override
  String toString() => 'UserModel($id, $email)';
}
