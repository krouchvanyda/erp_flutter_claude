import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/router/route_paths.dart';
import '../../domain/entities/task.dart';
import '../../domain/repositories/tasks_repository.dart';
import '../../domain/usecases/move_task.dart';

/// Slice 8.1.2 — Kanban board with drag-and-drop between columns.
///
/// Uses Flutter's built-in [Draggable] + [DragTarget] (no third-party
/// reorderable package needed for this layout). The drop handler hands
/// the task off to [moveTask] for the state-machine guard before
/// persisting.
class ProjectBoardPage extends StatefulWidget {
  const ProjectBoardPage({required this.projectId});
  final String projectId;

  @override
  State<ProjectBoardPage> createState() => _ProjectBoardPageState();
}

class _ProjectBoardPageState extends State<ProjectBoardPage> {
  String? _flashMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Board'),
      ),
      body: StreamBuilder<List<ProjectTask>>(
        stream:
            GetIt.I<TasksRepository>().watchForProject(widget.projectId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final tasks = snap.data ?? const <ProjectTask>[];
          final groups = groupTasksByStatus(tasks);
          return Column(
            children: [
              if (_flashMessage != null)
                Container(
                  width: double.infinity,
                  color: Colors.red.shade100,
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    _flashMessage!,
                    style: TextStyle(color: Colors.red.shade900),
                  ),
                ),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final status in TaskStatus.values)
                        _Column(
                          status: status,
                          tasks: groups[status] ?? const [],
                          onAccept: (task) => _move(task, status),
                          onTapTask: _openTask,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _move(ProjectTask task, TaskStatus to) async {
    try {
      final updated = moveTask(task: task, toStatus: to);
      await GetIt.I<TasksRepository>().update(updated);
      if (mounted) setState(() => _flashMessage = null);
    } on ConflictFailure catch (f) {
      setState(() => _flashMessage = f.message ?? 'Illegal transition');
    }
  }

  void _openTask(ProjectTask task) {
    context.pushNamed(
      RoutePaths.taskDetailName,
      pathParameters: {
        RoutePaths.projectDetailIdParam: widget.projectId,
        RoutePaths.taskDetailTaskIdParam: task.id,
      },
    );
  }
}

class _Column extends StatelessWidget {
  const _Column({
    required this.status,
    required this.tasks,
    required this.onAccept,
    required this.onTapTask,
  });

  final TaskStatus status;
  final List<ProjectTask> tasks;
  final void Function(ProjectTask task) onAccept;
  final void Function(ProjectTask task) onTapTask;

  @override
  Widget build(BuildContext context) {
    return DragTarget<ProjectTask>(
      onWillAcceptWithDetails: (d) => d.data.status != status,
      onAcceptWithDetails: (d) => onAccept(d.data),
      builder: (context, candidate, _) {
        final highlight = candidate.isNotEmpty;
        return Container(
          width: 280,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: highlight
                ? Colors.indigo.shade50
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: highlight ? Colors.indigo : Colors.grey.shade300,
              width: highlight ? 2 : 1,
            ),
          ),
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _columnTitle(status),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Chip(
                    label: Text('${tasks.length}'),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (tasks.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Drop tasks here',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                )
              else
                for (final task in tasks)
                  _TaskCard(task: task, onTap: () => onTapTask(task)),
            ],
          ),
        );
      },
    );
  }

  String _columnTitle(TaskStatus s) {
    switch (s) {
      case TaskStatus.todo:
        return 'To do';
      case TaskStatus.inProgress:
        return 'In progress';
      case TaskStatus.inReview:
        return 'In review';
      case TaskStatus.done:
        return 'Done';
    }
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task, required this.onTap});
  final ProjectTask task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final card = Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                task.title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _priorityColor(task.priority),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      task.priority.name,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 11),
                    ),
                  ),
                  if (task.assigneeName != null)
                    Text(
                      task.assigneeName!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  if (task.dueDate != null)
                    Text(
                      task.isOverdue
                          ? '⚠ ${_fmt(task.dueDate!)}'
                          : 'Due ${_fmt(task.dueDate!)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: task.isOverdue
                            ? Colors.red.shade700
                            : Colors.grey.shade700,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return LongPressDraggable<ProjectTask>(
      data: task,
      delay: const Duration(milliseconds: 200),
      feedback: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(width: 260, child: card),
      ),
      childWhenDragging: Opacity(opacity: 0.4, child: card),
      child: card,
    );
  }

  Color _priorityColor(TaskPriority p) {
    switch (p) {
      case TaskPriority.low:
        return Colors.grey.shade500;
      case TaskPriority.medium:
        return Colors.blue.shade500;
      case TaskPriority.high:
        return Colors.orange.shade600;
      case TaskPriority.urgent:
        return Colors.red.shade600;
    }
  }

  String _fmt(DateTime d) => d.toIso8601String().split('T').first;
}
