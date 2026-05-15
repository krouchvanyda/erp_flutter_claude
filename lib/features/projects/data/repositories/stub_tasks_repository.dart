import 'dart:async';

import '../../domain/entities/task.dart';
import '../../domain/repositories/tasks_repository.dart';
import '../projects_seed.dart';

class StubTasksRepository implements TasksRepository {
  StubTasksRepository();

  static final List<ProjectTask> _seed =
      List<ProjectTask>.of(ProjectsSeed.tasks);

  final StreamController<List<ProjectTask>> _changes =
      StreamController<List<ProjectTask>>.broadcast();

  @override
  Future<List<ProjectTask>> getForProject(String projectId) async =>
      List.unmodifiable(_seed.where((t) => t.projectId == projectId));

  @override
  Stream<List<ProjectTask>> watchForProject(String projectId) async* {
    yield await getForProject(projectId);
    yield* _changes.stream
        .map((all) => all.where((t) => t.projectId == projectId).toList());
  }

  @override
  Future<ProjectTask?> findById(String taskId) async {
    for (final t in _seed) {
      if (t.id == taskId) return t;
    }
    return null;
  }

  @override
  Future<ProjectTask> update(ProjectTask task) async {
    final idx = _seed.indexWhere((t) => t.id == task.id);
    if (idx == -1) {
      _seed.insert(0, task);
    } else {
      _seed[idx] = task;
    }
    _emit();
    return task;
  }

  @override
  Future<ProjectTask> create(ProjectTask task) async {
    final id = task.id.isEmpty
        ? 'task-${DateTime.now().microsecondsSinceEpoch}'
        : task.id;
    final stamped = task.copyWith(id: id);
    _seed.insert(0, stamped);
    _emit();
    return stamped;
  }

  void _emit() {
    if (!_changes.isClosed) _changes.add(List.unmodifiable(_seed));
  }
}

class StubTaskCommentsRepository implements TaskCommentsRepository {
  StubTaskCommentsRepository();

  static final List<TaskComment> _seed =
      List<TaskComment>.of(ProjectsSeed.comments);

  final StreamController<List<TaskComment>> _changes =
      StreamController<List<TaskComment>>.broadcast();

  @override
  Future<List<TaskComment>> getForTask(String taskId) async {
    final out = _seed.where((c) => c.taskId == taskId).toList()
      ..sort((a, b) => a.postedAt.compareTo(b.postedAt));
    return List.unmodifiable(out);
  }

  @override
  Stream<List<TaskComment>> watchForTask(String taskId) async* {
    yield await getForTask(taskId);
    yield* _changes.stream.map((all) {
      final out = all.where((c) => c.taskId == taskId).toList()
        ..sort((a, b) => a.postedAt.compareTo(b.postedAt));
      return List<TaskComment>.unmodifiable(out);
    });
  }

  @override
  Future<TaskComment> create(TaskComment comment) async {
    final id = comment.id.isEmpty
        ? 'cmt-${DateTime.now().microsecondsSinceEpoch}'
        : comment.id;
    final stamped = comment.copyWith(id: id);
    _seed.add(stamped);
    _emit();
    return stamped;
  }

  void _emit() {
    if (!_changes.isClosed) _changes.add(List.unmodifiable(_seed));
  }
}
