import '../entities/api_environment.dart';
import '../entities/managed_user.dart';

/// Slice 9.2.1 — admin user management.
abstract class ManagedUsersRepository {
  Future<List<ManagedUser>> getAll();
  Stream<List<ManagedUser>> watchAll();
  Future<ManagedUser?> findById(String id);
  Future<ManagedUser> create(ManagedUser user);
  Future<ManagedUser> update(ManagedUser user);
}

/// Slice 9.2.2 — role + permission scope editor.
abstract class RolesRepository {
  Future<List<Role>> getAll();
  Stream<List<Role>> watchAll();
  Future<Role?> findById(String id);
  Future<Role> create(Role role);
  Future<Role> update(Role role);
  Future<void> delete(String roleId);
}

/// Slice 9.2.3 — API endpoint config (multi-tenant / multi-env).
abstract class ApiEnvironmentsRepository {
  Future<List<ApiEnvironment>> getAll();
  Stream<List<ApiEnvironment>> watchAll();
  Future<String> getCurrentId();
  Stream<String> watchCurrentId();
  Future<void> setCurrent(String environmentId);
  Future<ApiEnvironment> create(ApiEnvironment env);
  Future<void> delete(String environmentId);
}
