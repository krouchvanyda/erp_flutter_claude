import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/theme/app_radii.dart';
import '../../../../core/widgets/dynamic_app_bar.dart';
import '../../../../core/widgets/dynamic_status_bar.dart';
import '../../../../shared/widgets/app_background_gradient.dart';
import '../../domain/entities/task.dart';
import '../../domain/repositories/tasks_repository.dart';

/// Slice 8.1.3 — task detail + comment thread.
class TaskDetailPage extends StatefulWidget {
  const TaskDetailPage({
    super.key,
    required this.taskId,
    this.currentUserId = 'emp-001',
  });

  final String taskId;
  final String currentUserId;

  @override
  State<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends State<TaskDetailPage> {
  final _commentCtrl = TextEditingController();
  bool _isPosting = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    final body = _commentCtrl.text.trim();
    if (body.isEmpty) return;
    setState(() => _isPosting = true);
    try {
      await GetIt.I<TaskCommentsRepository>().create(
        TaskComment(
          id: '',
          taskId: widget.taskId,
          authorId: widget.currentUserId,
          authorName: 'Demo Approver',
          body: body,
          postedAt: DateTime.now(),
        ),
      );
      _commentCtrl.clear();
      if (!mounted) return;
      FocusScope.of(context).unfocus();
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const DynamicAppBar(
        title: 'Task Details',
        centerTitle: true,
      ),
      body: DynamicStatusBar(
        child: Stack(
          children: [
            const AppBackgroundGradient(),
            FutureBuilder<ProjectTask?>(
              future: GetIt.I<TasksRepository>().findById(widget.taskId),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final task = snap.data;
                if (task == null) {
                  return Center(
                    child: Text('No task with id "${widget.taskId}".'),
                  );
                }
                return Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.only(
                          top: context.dynamicAppBarPadding + 16,
                          left: 16,
                          right: 16,
                          bottom: 24,
                        ),
                        children: [
                          // Task Primary Details Card
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
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  task.title,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _statusColor(task.status).withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(AppRadii.pill),
                                        border: Border.all(color: _statusColor(task.status).withValues(alpha: 0.15)),
                                      ),
                                      child: Text(
                                        task.status.name.toUpperCase(),
                                        style: TextStyle(
                                          color: _statusColor(task.status),
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _priorityColor(task.priority).withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(AppRadii.pill),
                                        border: Border.all(color: _priorityColor(task.priority).withValues(alpha: 0.15)),
                                      ),
                                      child: Text(
                                        task.priority.name.toUpperCase(),
                                        style: TextStyle(
                                          color: _priorityColor(task.priority),
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                    if (task.assigneeName != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.4),
                                          borderRadius: BorderRadius.circular(AppRadii.md),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            CircleAvatar(
                                              radius: 8,
                                              backgroundColor: theme.colorScheme.primary,
                                              child: Text(
                                                task.assigneeName![0].toUpperCase(),
                                                style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              task.assigneeName!,
                                              style: theme.textTheme.bodySmall?.copyWith(
                                                fontWeight: FontWeight.w700,
                                                color: theme.colorScheme.onSecondaryContainer,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    if (task.dueDate != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: task.isOverdue
                                              ? theme.colorScheme.errorContainer.withValues(alpha: 0.5)
                                              : theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                                          borderRadius: BorderRadius.circular(AppRadii.md),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.calendar_today_rounded,
                                              size: 11,
                                              color: task.isOverdue ? theme.colorScheme.error : theme.colorScheme.primary,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              task.dueDate!.toIso8601String().split('T').first,
                                              style: theme.textTheme.bodySmall?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: task.isOverdue ? theme.colorScheme.error : theme.colorScheme.primary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    if (task.estimatedHours != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.4),
                                          borderRadius: BorderRadius.circular(AppRadii.md),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.timer_outlined,
                                              size: 11,
                                              color: theme.colorScheme.onTertiaryContainer,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              '${task.estimatedHours}h',
                                              style: theme.textTheme.bodySmall?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: theme.colorScheme.onTertiaryContainer,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                                if (task.description.isNotEmpty) ...[
                                  const Divider(height: 32, thickness: 0.5),
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
                                    task.description,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ).animate().fadeIn().slideY(begin: 0.05, end: 0, duration: 300.ms),
                          const SizedBox(height: 24),
                          Text(
                            'COMMENTS',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          StreamBuilder<List<TaskComment>>(
                            stream: GetIt.I<TaskCommentsRepository>()
                                .watchForTask(widget.taskId),
                            builder: (context, cSnap) {
                              final comments =
                                  cSnap.data ?? const <TaskComment>[];
                              if (comments.isEmpty) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 24),
                                  child: Center(
                                    child: Text(
                                      'No comments yet.',
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: theme.colorScheme.outline,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                );
                              }
                              return Column(
                                children: [
                                  for (var i = 0; i < comments.length; i++)
                                    _CommentTile(comment: comments[i])
                                        .animate()
                                        .fadeIn(delay: (i * 50).ms)
                                        .slideY(begin: 0.05, end: 0, duration: 250.ms),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    // Bottom comment textbox
                    SafeArea(
                      top: false,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          border: Border(
                            top: BorderSide(
                              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _commentCtrl,
                                minLines: 1,
                                maxLines: 4,
                                decoration: InputDecoration(
                                  hintText: 'Add a comment…',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(AppRadii.lg),
                                    borderSide: BorderSide(
                                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(AppRadii.lg),
                                    borderSide: BorderSide(
                                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(AppRadii.lg),
                                    borderSide: BorderSide(
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              height: 38,
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(AppRadii.lg),
                                  ),
                                ),
                                onPressed: _isPosting ? null : _post,
                                child: _isPosting
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Icon(Icons.send_rounded, size: 18),
                              ),
                            ),
                          ],
                        ),
                      ),
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

  Color _priorityColor(TaskPriority p) {
    switch (p) {
      case TaskPriority.low:
        return Colors.grey;
      case TaskPriority.medium:
        return Colors.blue;
      case TaskPriority.high:
        return Colors.orange.shade700;
      case TaskPriority.urgent:
        return Colors.red.shade700;
    }
  }

  Color _statusColor(TaskStatus s) {
    switch (s) {
      case TaskStatus.todo:
        return Colors.blue;
      case TaskStatus.inProgress:
        return Colors.amber.shade700;
      case TaskStatus.inReview:
        return Colors.purple;
      case TaskStatus.done:
        return Colors.green;
    }
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment});
  final TaskComment comment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                child: Text(
                  comment.authorName.isEmpty ? '?' : comment.authorName[0].toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                comment.authorName,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                comment.postedAt
                    .toIso8601String()
                    .split('.')
                    .first
                    .replaceFirst('T', ' '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            comment.body,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
