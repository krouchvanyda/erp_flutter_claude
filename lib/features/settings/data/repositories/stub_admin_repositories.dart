import 'dart:async';

import '../../domain/entities/api_environment.dart';
import '../../domain/entities/managed_user.dart';
import '../../domain/repositories/admin_repositories.dart';
import '../settings_seed.dart';

class StubManagedUsersRepository implements ManagedUsersRepository {
  StubManagedUsersRepository();

  static final List<ManagedUser> _seed =
      List<ManagedUser>.of(SettingsSeed.users);

  final StreamController<List<ManagedUser>> _changes =
      StreamController<List<ManagedUser>>.broadcast();

  @override
  Future<List<ManagedUser>> getAll() async => List.unmodifiable(_seed);

  @override
  Stream<List<ManagedUser>> watchAll() async* {
    yield List.unmodifiable(_seed);
    yield* _changes.stream;
  }

  @override
  Future<ManagedUser?> findById(String id) async {
    for (final u in _seed) {
      if (u.id == id) return u;
    }
    return null;
  }

  @override
  Future<ManagedUser> create(ManagedUser user) async {
    final id = user.id.isEmpty
        ? 'user-${DateTime.now().microsecondsSinceEpoch}'
        : user.id;
    final stamped = user.copyWith(id: id);
    _seed.insert(0, stamped);
    _emit();
    return stamped;
  }

  @override
  Future<ManagedUser> update(ManagedUser user) async {
    final idx = _seed.indexWhere((u) => u.id == user.id);
    if (idx == -1) {
      _seed.insert(0, user);
    } else {
      _seed[idx] = user;
    }
    _emit();
    return user;
  }

  void _emit() {
    if (!_changes.isClosed) _changes.add(List.unmodifiable(_seed));
  }
}

class StubRolesRepository implements RolesRepository {
  StubRolesRepository();

  static final List<Role> _seed = List<Role>.of(SettingsSeed.roles);

  final StreamController<List<Role>> _changes =
      StreamController<List<Role>>.broadcast();

  @override
  Future<List<Role>> getAll() async => List.unmodifiable(_seed);

  @override
  Stream<List<Role>> watchAll() async* {
    yield List.unmodifiable(_seed);
    yield* _changes.stream;
  }

  @override
  Future<Role?> findById(String id) async {
    for (final r in _seed) {
      if (r.id == id) return r;
    }
    return null;
  }

  @override
  Future<Role> create(Role role) async {
    final id = role.id.isEmpty
        ? 'role-${DateTime.now().microsecondsSinceEpoch}'
        : role.id;
    final stamped = role.copyWith(id: id);
    _seed.insert(0, stamped);
    _emit();
    return stamped;
  }

  @override
  Future<Role> update(Role role) async {
    final idx = _seed.indexWhere((r) => r.id == role.id);
    if (idx == -1) {
      _seed.insert(0, role);
    } else {
      _seed[idx] = role;
    }
    _emit();
    return role;
  }

  @override
  Future<void> delete(String roleId) async {
    _seed.removeWhere((r) => r.id == roleId);
    _emit();
  }

  void _emit() {
    if (!_changes.isClosed) _changes.add(List.unmodifiable(_seed));
  }
}

class StubApiEnvironmentsRepository implements ApiEnvironmentsRepository {
  StubApiEnvironmentsRepository();

  static final List<ApiEnvironment> _seed =
      List<ApiEnvironment>.of(SettingsSeed.environments);

  static String _currentId = SettingsSeed.defaultEnvironmentId;

  final StreamController<List<ApiEnvironment>> _changes =
      StreamController<List<ApiEnvironment>>.broadcast();
  final StreamController<String> _currentChanges =
      StreamController<String>.broadcast();

  @override
  Future<List<ApiEnvironment>> getAll() async => List.unmodifiable(_seed);

  @override
  Stream<List<ApiEnvironment>> watchAll() async* {
    yield List.unmodifiable(_seed);
    yield* _changes.stream;
  }

  @override
  Future<String> getCurrentId() async => _currentId;

  @override
  Stream<String> watchCurrentId() async* {
    yield _currentId;
    yield* _currentChanges.stream;
  }

  @override
  Future<void> setCurrent(String environmentId) async {
    _currentId = environmentId;
    if (!_currentChanges.isClosed) _currentChanges.add(_currentId);
  }

  @override
  Future<ApiEnvironment> create(ApiEnvironment env) async {
    final id = env.id.isEmpty
        ? 'env-${DateTime.now().microsecondsSinceEpoch}'
        : env.id;
    final stamped = env.copyWith(id: id);
    _seed.add(stamped);
    if (!_changes.isClosed) _changes.add(List.unmodifiable(_seed));
    return stamped;
  }

  @override
  Future<void> delete(String environmentId) async {
    _seed.removeWhere((e) => e.id == environmentId);
    if (!_changes.isClosed) _changes.add(List.unmodifiable(_seed));
  }
}
