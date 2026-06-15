import 'permission.dart';

/// A named bundle of permissions — e.g. `accountant`, `warehouse_manager`,
/// `admin`.
///
/// The server is the canonical source of role definitions; the client
/// receives a flattened permission list at sign-in (already
/// role-expanded). This type exists so the UI can show role badges and
/// reason about role-shaped policies. Plain immutable value type (was
/// `freezed`; the codegen was removed).
class Role {
  const Role({
    required this.name,
    this.permissions = const <Permission>{},
  });

  final String name;
  final Set<Permission> permissions;

  /// `true` when *any* of this role's permissions satisfies [required],
  /// honouring the same wildcard semantics as [Permission.grants].
  bool grants(Permission required) => permissions.grant(required);

  Role copyWith({String? name, Set<Permission>? permissions}) => Role(
        name: name ?? this.name,
        permissions: permissions ?? this.permissions,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Role &&
          other.name == name &&
          other.permissions.length == permissions.length &&
          other.permissions.containsAll(permissions));

  @override
  int get hashCode => Object.hash(name, Object.hashAllUnordered(permissions));

  @override
  String toString() => 'Role(name: $name, permissions: $permissions)';
}
