import 'package:erp_mobile/features/auth/domain/entities/permission.dart';
import 'package:erp_mobile/features/auth/domain/repositories/permissions_repository.dart';
import 'package:erp_mobile/features/auth/domain/usecases/check_permission.dart';
import 'package:test/test.dart';

class _RecordingRepo implements PermissionsRepository {
  _RecordingRepo({this.result = false});
  bool result;
  final calls = <({String userId, Permission required})>[];

  @override
  Future<bool> hasPermission(String userId, Permission required) async {
    calls.add((userId: userId, required: required));
    return result;
  }

  @override
  Future<Set<Permission>> getPermissions(String userId) async => const {};

  @override
  Stream<Set<Permission>> watchPermissions(String userId) =>
      const Stream.empty();

  @override
  Future<void> cachePermissions(
          String userId, Set<Permission> permissions) async =>
      throw UnimplementedError();
}

void main() {
  group('CheckPermissionUseCase', () {
    test('forwards arguments to repository.hasPermission and returns result',
        () async {
      final repo = _RecordingRepo(result: true);
      final useCase = CheckPermissionUseCase(repository: repo);

      const required = Permission(token: 'finance.invoice.create');
      final result = await useCase.call(userId: 'u-1', required: required);

      expect(result, isTrue);
      expect(repo.calls, hasLength(1));
      expect(repo.calls.single.userId, 'u-1');
      expect(repo.calls.single.required, required);
    });

    test('propagates a false result without coercing', () async {
      final repo = _RecordingRepo();
      final useCase = CheckPermissionUseCase(repository: repo);

      final result = await useCase.call(
        userId: 'u-1',
        required: const Permission(token: 'admin'),
      );
      expect(result, isFalse);
    });
  });
}
