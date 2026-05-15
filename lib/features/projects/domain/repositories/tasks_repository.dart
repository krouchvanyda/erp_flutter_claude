import '../entities/task.dart';

abstract class TasksRepository {
  Future<List<ProjectTask>> getForProject(String projectId);
  Stream<List<ProjectTask>> watchForProject(String projectId);
  Future<ProjectTask?> findById(String taskId);

  /// Slice 8.1.2 — Kanban move. The state machine guard lives in the
  /// [`moveTask`] use case; this repo replaces the row in-place.
  Future<ProjectTask> update(ProjectTask task);

  Future<ProjectTask> create(ProjectTask task);
}

abstract class TaskCommentsRepository {
  Future<List<TaskComment>> getForTask(String taskId);
  Stream<List<TaskComment>> watchForTask(String taskId);

  /// Slice 8.1.3 — append a comment. Repo assigns the id when blank.
  Future<TaskComment> create(TaskComment comment);
}
