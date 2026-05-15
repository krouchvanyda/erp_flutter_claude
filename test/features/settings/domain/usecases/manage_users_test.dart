import 'package:erp_mobile/core/error/failure.dart';
import 'package:erp_mobile/features/settings/domain/entities/managed_user.dart';
import 'package:erp_mobile/features/settings/domain/usecases/manage_users.dart';
import 'package:test/test.dart';

ManagedUser _u({
  String id = 'u',
  ManagedUserStatus status = ManagedUserStatus.active,
  List<String> roleIds = const ['role-viewer'],
}) =>
    ManagedUser(
      id: id,
      email: 'u@erp.example',
      name: 'U',
      status: status,
      roleIds: roleIds,
      createdAt: DateTime.utc(2026, 1, 1),
    );

void main() {
  group('inviteUser', () {
    final now = DateTime.utc(2026, 5, 15);

    test('accepts a well-formed invite', () {
      final u = inviteUser(
        email: '  Foo@Bar.com ',
        name: '  Foo  ',
        roleIds: ['role-viewer'],
        now: now,
      );
      // Email lowercased + trimmed.
      expect(u.email, 'foo@bar.com');
      expect(u.name, 'Foo');
      expect(u.status, ManagedUserStatus.invited);
      expect(u.id, isEmpty);
    });

    test('rejects malformed email', () {
      expect(
        () => inviteUser(
          email: 'no-at-sign',
          name: 'X',
          roleIds: ['role-viewer'],
          now: now,
        ),
        throwsA(isA<ValidationFailure>().having(
          (f) => f.fieldErrors,
          'fieldErrors',
          containsPair('email', isNotEmpty),
        )),
      );
    });

    test('rejects empty name and missing roles', () {
      expect(
        () => inviteUser(
          email: 'ok@ok.com',
          name: '   ',
          roleIds: const [],
          now: now,
        ),
        throwsA(isA<ValidationFailure>().having(
          (f) => f.fieldErrors,
          'fieldErrors',
          allOf(
            containsPair('name', isNotEmpty),
            containsPair('roleIds', isNotEmpty),
          ),
        )),
      );
    });
  });

  group('setUserStatus', () {
    test('flips status when not self', () {
      final out = setUserStatus(
        user: _u(id: 'other'),
        newStatus: ManagedUserStatus.suspended,
        currentUserId: 'me',
      );
      expect(out.status, ManagedUserStatus.suspended);
    });

    test('refuses to suspend self', () {
      expect(
        () => setUserStatus(
          user: _u(id: 'me'),
          newStatus: ManagedUserStatus.suspended,
          currentUserId: 'me',
        ),
        throwsA(isA<ConflictFailure>()),
      );
    });

    test('no-op when status unchanged', () {
      final u = _u(id: 'other', status: ManagedUserStatus.active);
      final out = setUserStatus(
        user: u,
        newStatus: ManagedUserStatus.active,
        currentUserId: 'me',
      );
      expect(out, same(u));
    });
  });

  group('updateUserRoles', () {
    test('refuses to remove every role from self', () {
      expect(
        () => updateUserRoles(
          user: _u(id: 'me'),
          roleIds: const [],
          currentUserId: 'me',
        ),
        throwsA(isA<ConflictFailure>()),
      );
    });

    test('allows removing all roles from another user', () {
      final out = updateUserRoles(
        user: _u(id: 'other'),
        roleIds: const [],
        currentUserId: 'me',
      );
      expect(out.roleIds, isEmpty);
    });
  });
}
