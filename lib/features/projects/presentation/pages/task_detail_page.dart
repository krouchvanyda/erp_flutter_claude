import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../domain/entities/task.dart';
import '../../domain/repositories/tasks_repository.dart';

/// Slice 8.1.3 — task detail + comment thread.
class TaskDetailPage extends StatefulWidget {
  const TaskDetailPage({required this.taskId, this.currentUserId = 'emp-001'});
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
    return Scaffold(
      appBar: AppBar(title: const Text('Task')),
      body: FutureBuilder<ProjectTask?>(
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
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              task.title,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                Chip(
                                  label: Text(task.status.name),
                                  visualDensity: VisualDensity.compact,
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _priorityColor(task.priority),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    task.priority.name,
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 12),
                                  ),
                                ),
                                if (task.assigneeName != null)
                                  Chip(
                                    avatar: CircleAvatar(
                                      backgroundColor:
                                          Colors.blueGrey.shade100,
                                      child: Text(
                                          task.assigneeName![0]),
                                    ),
                                    label: Text(task.assigneeName!),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                if (task.dueDate != null)
                                  Chip(
                                    avatar: const Icon(Icons.calendar_today,
                                        size: 14),
                                    label: Text(
                                      task.dueDate!
                                          .toIso8601String()
                                          .split('T')
                                          .first,
                                    ),
                                    backgroundColor: task.isOverdue
                                        ? Colors.red.shade100
                                        : null,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                if (task.estimatedHours != null)
                                  Chip(
                                    avatar:
                                        const Icon(Icons.timer, size: 14),
                                    label: Text('${task.estimatedHours}h'),
                                    visualDensity: VisualDensity.compact,
                                  ),
                              ],
                            ),
                            if (task.description.isNotEmpty) ...[
                              const Divider(height: 24),
                              Text(task.description),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Comments',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    StreamBuilder<List<TaskComment>>(
                      stream: GetIt.I<TaskCommentsRepository>()
                          .watchForTask(widget.taskId),
                      builder: (context, cSnap) {
                        final comments =
                            cSnap.data ?? const <TaskComment>[];
                        if (comments.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(12),
                            child: Text('No comments yet.'),
                          );
                        }
                        return Column(
                          children:
                              comments.map(_CommentTile.new).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentCtrl,
                          minLines: 1,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            hintText: 'Add a comment…',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: _isPosting ? null : _post,
                        icon: const Icon(Icons.send),
                        label: const Text('Post'),
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
}

class _CommentTile extends StatelessWidget {
  const _CommentTile(this.comment);
  final TaskComment comment;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.blueGrey.shade100,
                  child: Text(
                    comment.authorName.isEmpty ? '?' : comment.authorName[0],
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  comment.authorName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Text(
                  comment.postedAt
                      .toIso8601String()
                      .split('.')
                      .first
                      .replaceFirst('T', ' '),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(comment.body),
          ],
        ),
      ),
    );
  }
}
