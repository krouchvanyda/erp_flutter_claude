import 'package:equatable/equatable.dart';

import 'permission.dart';

/// A named bundle of permissions — e.g. `accountant`, `warehouse_manager`,
/// `admin`.
///
/// The server is the canonical source of role definitions; the client
/// receives a flattened permission list at sign-in (already
/// role-expanded) and stores it. This type exists so the UI can show
/// role badges, group permissions in the Settings page, and reason about
/// role-shaped policies without re-deriving them from scattered string
/// checks.
class Role extends Equatable {
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
  List<Object?> get props => [name, permissions];
}
