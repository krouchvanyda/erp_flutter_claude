import 'package:collection/collection.dart';

import 'package:erp_mobile/features/authentication/models/permission_model.dart';

/// A named bundle of permissions — e.g. `accountant`, `warehouse_manager`,
/// `admin`.
///
/// The server is the canonical source of role definitions; the client
/// receives a flattened permission list at sign-in (already
/// role-expanded) and stores it. This type exists so the UI can show
/// role badges, group permissions in the Settings page, and reason about
/// role-shaped policies without re-deriving them from scattered string
/// checks.
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

  Role copyWith({
    String? name,
    Set<Permission>? permissions,
  }) {
    return Role(
      name: name ?? this.name,
      permissions: permissions ?? this.permissions,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Role &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          const SetEquality<Permission>().equals(permissions, other.permissions);

  @override
  int get hashCode => Object.hash(
        runtimeType,
        name,
        const SetEquality<Permission>().hash(permissions),
      );
}
