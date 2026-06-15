/// Authenticated user — the domain-layer view of "who is signed in".
///
/// Pure Dart, framework-free. The data layer maps `UserModel` (the
/// API/JSON shape, defined in `data/models/`) onto this entity so the
/// domain never deals with serialisation concerns.
///
/// Roles are an unordered set of opaque permission tokens (e.g.
/// `'finance.invoice.create'`, `'admin'`). Plain immutable value type
/// (was `freezed`; the codegen was removed).
class User {
  const User({
    required this.id,
    required this.email,
    required this.displayName,
    this.roles = const <String>{},
  });

  final String id;
  final String email;
  final String displayName;
  final Set<String> roles;

  bool hasRole(String role) => roles.contains(role);
  bool hasAnyRole(Iterable<String> wanted) => wanted.any(roles.contains);
  bool hasAllRoles(Iterable<String> required) =>
      required.every(roles.contains);

  User copyWith({
    String? id,
    String? email,
    String? displayName,
    Set<String>? roles,
  }) =>
      User(
        id: id ?? this.id,
        email: email ?? this.email,
        displayName: displayName ?? this.displayName,
        roles: roles ?? this.roles,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is User &&
          other.id == id &&
          other.email == email &&
          other.displayName == displayName &&
          other.roles.length == roles.length &&
          other.roles.containsAll(roles));

  @override
  int get hashCode => Object.hash(
        id,
        email,
        displayName,
        Object.hashAllUnordered(roles),
      );

  @override
  String toString() =>
      'User(id: $id, email: $email, displayName: $displayName, roles: $roles)';
}
