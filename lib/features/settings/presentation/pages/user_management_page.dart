import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/managed_user.dart';
import '../../domain/repositories/admin_repositories.dart';
import '../../domain/usecases/manage_users.dart';

/// Slice 9.2.1 — admin-only user management.
///
/// **RBAC** is enforced at the route layer (the catalog tile + route
/// guard); this page assumes the caller already passed the `admin`
/// permission gate.
class UserManagementPage extends StatefulWidget {
  const UserManagementPage({this.currentUserId = 'user-demo'});
  final String currentUserId;

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  ManagedUserStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final usersRepo = GetIt.I<ManagedUsersRepository>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('User management'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Wrap(
              spacing: 6,
              children: [
                _filterChip('All', null),
                _filterChip('Active', ManagedUserStatus.active),
                _filterChip('Invited', ManagedUserStatus.invited),
                _filterChip('Suspended', ManagedUserStatus.suspended),
              ],
            ),
          ),
        ),
      ),
      body: StreamBuilder<List<ManagedUser>>(
        stream: usersRepo.watchAll(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final users = snap.data!
              .where((u) => _filter == null || u.status == _filter)
              .toList();
          if (users.isEmpty) {
            return const Center(child: Text('No users match.'));
          }
          return ListView.separated(
            itemCount: users.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, idx) => _UserRow(
              user: users[idx],
              currentUserId: widget.currentUserId,
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showInviteSheet,
        icon: const Icon(Icons.person_add),
        label: const Text('Invite'),
      ),
    );
  }

  Widget _filterChip(String label, ManagedUserStatus? value) {
    return ChoiceChip(
      label: Text(label),
      selected: _filter == value,
      onSelected: (_) => setState(() => _filter = value),
    );
  }

  Future<void> _showInviteSheet() async {
    final emailCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    Set<String> selectedRoles = {};
    String? errorMsg;
    final rolesRepo = GetIt.I<RolesRepository>();
    final allRoles = await rolesRepo.getAll();

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Invite a user',
                style: Theme.of(sheetCtx).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Roles',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [
                  for (final r in allRoles)
                    FilterChip(
                      label: Text(r.name),
                      selected: selectedRoles.contains(r.id),
                      onSelected: (sel) => setSheet(() {
                        if (sel) {
                          selectedRoles.add(r.id);
                        } else {
                          selectedRoles.remove(r.id);
                        }
                      }),
                    ),
                ],
              ),
              if (errorMsg != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.red.shade100,
                  child: Text(errorMsg!,
                      style: TextStyle(color: Colors.red.shade900)),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  try {
                    final draft = inviteUser(
                      email: emailCtrl.text,
                      name: nameCtrl.text,
                      roleIds: selectedRoles.toList(),
                      now: DateTime.now(),
                    );
                    await GetIt.I<ManagedUsersRepository>().create(draft);
                    if (sheetCtx.mounted) {
                      Navigator.pop(sheetCtx);
                    }
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(
                                'Invited ${emailCtrl.text.trim()}')),
                      );
                    }
                  } on ValidationFailure catch (f) {
                    setSheet(() => errorMsg = f.fieldErrors.entries
                        .map((e) => '${e.key}: ${e.value.join(', ')}')
                        .join('\n'));
                  }
                },
                child: const Text('Send invite'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow({required this.user, required this.currentUserId});
  final ManagedUser user;
  final String currentUserId;

  @override
  Widget build(BuildContext context) {
    final isMe = user.id == currentUserId;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _statusColor(user.status),
        child: Text(user.name.isEmpty ? '?' : user.name[0]),
      ),
      title: Row(
        children: [
          Expanded(child: Text(user.name)),
          if (isMe)
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Chip(
                label: Text('You'),
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
      subtitle: Text('${user.email} • ${user.roleIds.join(', ')}'),
      trailing: PopupMenuButton<String>(
        onSelected: (action) => _runAction(context, action),
        itemBuilder: (_) => [
          if (user.status != ManagedUserStatus.active)
            const PopupMenuItem(value: 'activate', child: Text('Activate')),
          if (user.status == ManagedUserStatus.active)
            const PopupMenuItem(value: 'suspend', child: Text('Suspend')),
        ],
      ),
    );
  }

  Future<void> _runAction(BuildContext context, String action) async {
    final repo = GetIt.I<ManagedUsersRepository>();
    try {
      final next = setUserStatus(
        user: user,
        newStatus: action == 'suspend'
            ? ManagedUserStatus.suspended
            : ManagedUserStatus.active,
        currentUserId: currentUserId,
      );
      await repo.update(next);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Status set to ${next.status.name}.')),
        );
      }
    } on ConflictFailure catch (f) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(f.message ?? 'Cannot apply.')),
        );
      }
    }
  }

  Color _statusColor(ManagedUserStatus s) {
    switch (s) {
      case ManagedUserStatus.active:
        return Colors.green.shade100;
      case ManagedUserStatus.invited:
        return Colors.blue.shade100;
      case ManagedUserStatus.suspended:
        return Colors.red.shade100;
    }
  }
}
