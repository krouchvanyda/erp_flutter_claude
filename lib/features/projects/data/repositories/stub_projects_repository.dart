import 'dart:async';

import '../../domain/entities/project.dart';
import '../../domain/repositories/projects_repository.dart';
import '../projects_seed.dart';

class StubProjectsRepository implements ProjectsRepository {
  StubProjectsRepository();

  static final List<Project> _seed = List<Project>.of(ProjectsSeed.projects);

  final StreamController<List<Project>> _changes =
      StreamController<List<Project>>.broadcast();

  @override
  Future<List<Project>> getAll() async => List.unmodifiable(_seed);

  @override
  Stream<List<Project>> watchAll() async* {
    yield List.unmodifiable(_seed);
    yield* _changes.stream;
  }

  @override
  Future<Project?> findById(String id) async {
    for (final p in _seed) {
      if (p.id == id) return p;
    }
    return null;
  }
}
