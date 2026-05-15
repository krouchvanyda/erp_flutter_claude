import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_paths.dart';
import '../../domain/entities/project.dart';
import '../../domain/entities/task.dart';
import '../../domain/repositories/projects_repository.dart';
import '../../domain/repositories/tasks_repository.dart';
import '../../domain/usecases/move_task.dart';

class ProjectDetailPage extends StatelessWidget {
  const ProjectDetailPage({required this.projectId});
  final String projectId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Project'),
        actions: [
          IconButton(
            tooltip: 'Open board',
            icon: const Icon(Icons.view_kanban_outlined),
            onPressed: () => context.pushNamed(
              RoutePaths.projectBoardName,
              pathParameters: {RoutePaths.projectDetailIdParam: projectId},
            ),
          ),
        ],
      ),
      body: FutureBuilder<Project?>(
        future: GetIt.I<ProjectsRepository>().findById(projectId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final project = snap.data;
          if (project == null) {
            return Center(
              child: Text('No project with id "$projectId".'),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              color: _projectColor(project.color),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  project.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge,
                                ),
                                Text(
                                  project.code,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall,
                                ),
                              ],
                            ),
                          ),
                          Chip(
                            label: Text(project.status.name),
                            backgroundColor: _statusColor(project.status),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      _row('Owner', project.ownerName),
                      _row('Start',
                          project.startDate.toIso8601String().split('T').first),
                      _row('End',
                          project.endDate.toIso8601String().split('T').first),
                      _row('Duration', '${project.totalDays} days'),
                      _row('Budget', project.budget),
                      const SizedBox(height: 12),
                      Text(
                        project.description,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Tasks',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              StreamBuilder<List<ProjectTask>>(
                stream: GetIt.I<TasksRepository>()
                    .watchForProject(projectId),
                builder: (context, taskSnap) {
                  final tasks = taskSnap.data ?? const <ProjectTask>[];
                  if (tasks.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('No tasks yet.'),
                    );
                  }
                  final groups = groupTasksByStatus(tasks);
                  return Column(
                    children: [
                      for (final status in TaskStatus.values)
                        _StatusGroup(
                          status: status,
                          tasks: groups[status] ?? const [],
                          projectId: projectId,
                        ),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.pushNamed(
          RoutePaths.projectBoardName,
          pathParameters: {RoutePaths.projectDetailIdParam: projectId},
        ),
        icon: const Icon(Icons.view_kanban_outlined),
        label: const Text('Open board'),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 100,
              child: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            Expanded(child: Text(value)),
          ],
        ),
      );

  Color _projectColor(String? hex) {
    if (hex == null || hex.length != 6) return Colors.indigo;
    return Color(int.parse('FF$hex', radix: 16));
  }

  Color _statusColor(ProjectStatus status) {
    switch (status) {
      case ProjectStatus.planning:
        return Colors.blue.shade100;
      case ProjectStatus.active:
        return Colors.green.shade100;
      case ProjectStatus.onHold:
        return Colors.orange.shade100;
      case ProjectStatus.completed:
        return Colors.grey.shade300;
      case ProjectStatus.archived:
        return Colors.grey.shade200;
    }
  }
}

class _StatusGroup extends StatelessWidget {
  const _StatusGroup({
    required this.status,
    required this.tasks,
    required this.projectId,
  });
  final TaskStatus status;
  final List<ProjectTask> tasks;
  final String projectId;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '${status.name} (${tasks.length})',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          for (final task in tasks)
            Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                title: Text(task.title),
                subtitle: Text(task.assigneeName ?? 'Unassigned'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.pushNamed(
                  RoutePaths.taskDetailName,
                  pathParameters: {
                    RoutePaths.projectDetailIdParam: projectId,
                    RoutePaths.taskDetailTaskIdParam: task.id,
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
