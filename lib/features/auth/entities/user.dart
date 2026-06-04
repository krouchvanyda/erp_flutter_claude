import 'package:equatable/equatable.dart';

/// Authenticated user — the domain-layer view of "who is signed in".
///
/// Pure Dart, framework-free. The data layer maps `UserModel` (the
/// API/JSON shape, defined in `data/models/`) onto this entity so the
/// domain never deals with serialisation concerns.
///
/// Roles are an unordered set of opaque permission tokens (e.g.
/// `'finance.invoice.create'`, `'admin'`). Higher-level RBAC checks
/// belong in domain use cases, not here.
class User extends Equatable {
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
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      roles: roles ?? this.roles,
    );
  }

  @override
  List<Object?> get props => [id, email, displayName, roles];
}
