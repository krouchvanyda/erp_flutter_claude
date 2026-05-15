import '../../../../core/error/failure.dart';
import '../entities/task.dart';

/// Slice 8.1.2 — Kanban move with a state machine guard.
///
/// **Allowed transitions** (the rest throw [ConflictFailure]):
/// ```
/// todo        ↔ inProgress
/// inProgress  ↔ inReview
/// inReview    ↔ done
/// any non-done ↔ any other non-done   (drag freedom inside the active stages)
/// done        → inProgress             (re-open path; no jump straight back to todo)
/// ```
///
/// **Why this shape**: lets a developer drag a card freely between the
/// three working columns (todo/inProgress/inReview) without policy
/// drama, but keeps "done → todo" off the table — re-opening is rare
/// enough that it should be a deliberate "back to active" move.
ProjectTask moveTask({
  required ProjectTask task,
  required TaskStatus toStatus,
}) {
  if (task.status == toStatus) return task;

  final from = task.status;
  final to = toStatus;

  bool active(TaskStatus s) =>
      s == TaskStatus.todo ||
      s == TaskStatus.inProgress ||
      s == TaskStatus.inReview;

  // Free movement between active stages.
  if (active(from) && active(to)) return task.copyWith(status: to);

  // Active → done (close).
  if (active(from) && to == TaskStatus.done) return task.copyWith(status: to);

  // Done → inProgress (re-open).
  if (from == TaskStatus.done && to == TaskStatus.inProgress) {
    return task.copyWith(status: to);
  }

  throw ConflictFailure(
    message: 'Illegal transition: ${from.name} → ${to.name}',
  );
}

/// Bucketed view for the Kanban columns (Slice 8.1.2).
///
/// Returns a map keyed by [TaskStatus]. Each column is sorted by
/// priority desc then dueDate asc so the most urgent items float to
/// the top — same heuristic Asana / Linear default to.
Map<TaskStatus, List<ProjectTask>> groupTasksByStatus(
    List<ProjectTask> tasks) {
  final out = <TaskStatus, List<ProjectTask>>{
    for (final s in TaskStatus.values) s: <ProjectTask>[],
  };
  for (final t in tasks) {
    out[t.status]!.add(t);
  }
  for (final list in out.values) {
    list.sort((a, b) {
      // Priority desc — urgent first.
      final byPrio = b.priority.index.compareTo(a.priority.index);
      if (byPrio != 0) return byPrio;
      // Then due date asc — soonest first; nulls last.
      if (a.dueDate == null && b.dueDate == null) return 0;
      if (a.dueDate == null) return 1;
      if (b.dueDate == null) return -1;
      return a.dueDate!.compareTo(b.dueDate!);
    });
  }
  return out;
}
