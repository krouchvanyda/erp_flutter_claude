import 'package:erp_mobile/core/error/failure.dart';
import 'package:erp_mobile/features/settings/domain/entities/managed_user.dart';
import 'package:erp_mobile/features/settings/domain/usecases/manage_roles.dart';
import 'package:test/test.dart';

Role _role({
  String id = 'r',
  bool isSystem = false,
  List<String> tokens = const ['finance.read'],
}) =>
    Role(
      id: id,
      name: 'Test',
      description: 'd',
      permissionTokens: tokens,
      isSystem: isSystem,
    );

ManagedUser _user({
  String id = 'u',
  List<String> roleIds = const [],
}) =>
    ManagedUser(
      id: id,
      email: '$id@erp.example',
      name: id,
      status: ManagedUserStatus.active,
      roleIds: roleIds,
      createdAt: DateTime.utc(2026, 1, 1),
    );

void main() {
  group('createRole', () {
    test('accepts well-formed input', () {
      final r = createRole(
        name: '  Finance Manager  ',
        description: 'd',
        permissionTokens: ['finance.*'],
      );
      expect(r.name, 'Finance Manager');
      expect(r.permissionTokens, ['finance.*']);
      expect(r.isSystem, isFalse);
    });

    test('rejects empty name', () {
      expect(
        () => createRole(
          name: '',
          description: 'd',
          permissionTokens: ['finance.*'],
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('rejects empty permission set', () {
      expect(
        () => createRole(
          name: 'X',
          description: 'd',
          permissionTokens: const [],
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });
  });

  group('updateRolePermissions', () {
    test('refuses to mutate built-in roles', () {
      expect(
        () => updateRolePermissions(
          role: _role(isSystem: true),
          permissionTokens: ['admin'],
        ),
        throwsA(isA<ConflictFailure>()),
      );
    });

    test('refuses empty permission set on update', () {
      expect(
        () => updateRolePermissions(
          role: _role(),
          permissionTokens: const [],
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('returns updated role on success', () {
      final out = updateRolePermissions(
        role: _role(),
        permissionTokens: ['inventory.read', 'sales.read'],
      );
      expect(out.permissionTokens, ['inventory.read', 'sales.read']);
    });
  });

  group('ensureRoleIsDeletable', () {
    test('refuses built-in', () {
      expect(
        () => ensureRoleIsDeletable(
          role: _role(isSystem: true),
          currentUsers: const [],
        ),
        throwsA(isA<ConflictFailure>()),
      );
    });

    test('refuses if any user holds the role', () {
      expect(
        () => ensureRoleIsDeletable(
          role: _role(id: 'role-x'),
          currentUsers: [_user(id: 'u1', roleIds: ['role-x'])],
        ),
        throwsA(isA<ConflictFailure>()),
      );
    });

    test('passes when role is unused and not built-in', () {
      ensureRoleIsDeletable(
        role: _role(id: 'role-x'),
        currentUsers: [_user(id: 'u1', roleIds: ['role-y'])],
      );
    });
  });
}
