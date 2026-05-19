import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/widgets/dynamic_app_bar.dart';
import '../../../../core/widgets/dynamic_status_bar.dart';
import '../../domain/entities/project.dart';
import '../../domain/entities/task.dart';
import '../../domain/repositories/projects_repository.dart';
import '../../domain/repositories/tasks_repository.dart';
import '../../domain/usecases/move_task.dart';

class ProjectDetailPage extends StatelessWidget {
  const ProjectDetailPage({super.key, required this.projectId});
  final String projectId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: DynamicAppBar(
        title: 'Project Details',
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Open Board',
            icon: const Icon(Icons.view_kanban_outlined),
            onPressed: () => context.pushNamed(
              RoutePaths.projectBoardName,
              pathParameters: {RoutePaths.projectDetailIdParam: projectId},
            ),
          ),
        ],
      ),
      body: DynamicStatusBar(
        child: Stack(
          children: [
            // Background Gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [
                    theme.colorScheme.primaryContainer.withValues(alpha: 0.15),
                    theme.colorScheme.surface,
                    theme.colorScheme.secondaryContainer.withValues(alpha: 0.05),
                  ],
                ),
              ),
            ),
            FutureBuilder<Project?>(
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
                  padding: EdgeInsets.only(
                    top: context.dynamicAppBarPadding + 16,
                    left: 16,
                    right: 16,
                    bottom: 80,
                  ),
                  children: [
                    // Premium Project Header Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(AppRadii.lg),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(AppRadii.md),
                                  color: _projectColor(project.color).withValues(alpha: 0.1),
                                  border: Border.all(
                                    color: _projectColor(project.color).withValues(alpha: 0.3),
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  project.code.split('-').first.substring(
                                      0, project.code.split('-').first.length.clamp(0, 3)),
                                  style: TextStyle(
                                    color: _projectColor(project.color),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      project.name,
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Project ID: ${project.code}',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _statusColor(project.status).withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(AppRadii.pill),
                                  border: Border.all(color: _statusColor(project.status).withValues(alpha: 0.15)),
                                ),
                                child: Text(
                                  project.status.name.toUpperCase(),
                                  style: TextStyle(
                                    color: _statusColor(project.status),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 32, thickness: 0.5),
                          _row(theme, 'Owner', project.ownerName, Icons.person_outline_rounded),
                          _row(theme, 'Start Date', project.startDate.toIso8601String().split('T').first, Icons.calendar_today_rounded),
                          _row(theme, 'End Date', project.endDate.toIso8601String().split('T').first, Icons.event_busy_rounded),
                          _row(theme, 'Duration', '${project.totalDays} Days', Icons.timelapse_rounded),
                          _row(theme, 'Budget', project.budget, Icons.monetization_on_outlined),
                          const SizedBox(height: 16),
                          Text(
                            'DESCRIPTION',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            project.description,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn().slideY(begin: 0.05, end: 0, duration: 300.ms),
                    const SizedBox(height: 24),
                    Text(
                      'PROJECT TASKS',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    StreamBuilder<List<ProjectTask>>(
                      stream: GetIt.I<TasksRepository>()
                          .watchForProject(projectId),
                      builder: (context, taskSnap) {
                        final tasks = taskSnap.data ?? const <ProjectTask>[];
                        if (tasks.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.all(24),
                            child: Center(
                              child: Text(
                                'No tasks assigned yet.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.outline,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
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
          ],
        ),
      ),
    );
  }

  Widget _row(ThemeData theme, String label, String value, IconData icon) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 16, color: theme.colorScheme.outline),
            const SizedBox(width: 8),
            SizedBox(
              width: 100,
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
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
        return Colors.blue;
      case ProjectStatus.active:
        return Colors.green;
      case ProjectStatus.onHold:
        return Colors.orange;
      case ProjectStatus.completed:
        return Colors.teal;
      case ProjectStatus.archived:
        return Colors.grey;
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
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _statusColor(status),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _statusText(status),
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${tasks.length}',
                    style: TextStyle(
                      color: _statusColor(status),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          for (final task in tasks)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(AppRadii.lg),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.015),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.lg),
                child: Material(
                  color: Colors.transparent,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    title: Text(
                      task.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      task.assigneeName ?? 'Unassigned',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: theme.colorScheme.primary,
                    ),
                    onTap: () => context.pushNamed(
                      RoutePaths.taskDetailName,
                      pathParameters: {
                        RoutePaths.projectDetailIdParam: projectId,
                        RoutePaths.taskDetailTaskIdParam: task.id,
                      },
                    ),
                  ),
                ),
              ),
            ).animate().fadeIn().slideY(begin: 0.05, end: 0, duration: 250.ms),
        ],
      ),
    );
  }

  String _statusText(TaskStatus s) {
    switch (s) {
      case TaskStatus.todo:
        return 'TO DO';
      case TaskStatus.inProgress:
        return 'IN PROGRESS';
      case TaskStatus.inReview:
        return 'IN REVIEW';
      case TaskStatus.done:
        return 'DONE';
    }
  }

  Color _statusColor(TaskStatus s) {
    switch (s) {
      case TaskStatus.todo:
        return Colors.blue;
      case TaskStatus.inProgress:
        return Colors.amber;
      case TaskStatus.inReview:
        return Colors.purple;
      case TaskStatus.done:
        return Colors.green;
    }
  }
}
