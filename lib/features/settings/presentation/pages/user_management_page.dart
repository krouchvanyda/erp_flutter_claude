import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/widgets/dynamic_app_bar.dart';
import '../../../../core/widgets/dynamic_status_bar.dart';
import '../../data/repositories/admin_repositories.dart';
import '../../entities/managed_user.dart';

/// Slice 9.2.1 — admin-only user management.
class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key, this.currentUserId = 'user-demo'});
  final String currentUserId;

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  ManagedUserStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final usersRepo = GetIt.I<ManagedUsersRepository>();
    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const DynamicAppBar(
        title: 'User Managements',
        centerTitle: true,
      ),
      body: DynamicStatusBar(
        child: Stack(
          children: [
            // Background Canvas
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [
                    theme.colorScheme.primaryContainer.withValues(alpha: 0.12),
                    theme.colorScheme.surface,
                    theme.colorScheme.secondaryContainer.withValues(alpha: 0.04),
                  ],
                ),
              ),
            ),
            Column(
              children: [
                SizedBox(height: context.dynamicAppBarPadding + 55),
                // Custom Filter Row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(AppRadii.lg),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _filterTab('All', null),
                          _filterTab('Active', ManagedUserStatus.active),
                          _filterTab('Invited', ManagedUserStatus.invited),
                          _filterTab('Suspended', ManagedUserStatus.suspended),
                        ],
                      ),
                    ),
                  ),
                ).animate().fadeIn().slideY(begin: -0.05, end: 0, duration: 300.ms),
                const SizedBox(height: 12),
                // Users List
                Expanded(
                  child: StreamBuilder<List<ManagedUser>>(
                    stream: usersRepo.watchAll(),
                    builder: (context, snap) {
                      if (!snap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final users = snap.data!
                          .where((u) => _filter == null || u.status == _filter)
                          .toList();
                      if (users.isEmpty) {
                        return const Center(
                          child: Text(
                            'No users match the selected status.',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 80),
                        itemCount: users.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, idx) => _UserRow(
                          user: users[idx],
                          currentUserId: widget.currentUserId,
                        ).animate().fadeIn(delay: (idx * 60).clamp(0, 300).ms).slideY(
                              begin: 0.04,
                              end: 0,
                              duration: 300.ms,
                            ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showInviteSheet,
        elevation: 4,
        icon: const Icon(Icons.person_add),
        label: const Text('Invite User', style: TextStyle(fontWeight: FontWeight.bold)),
      ).animate().scale(delay: 200.ms, duration: 250.ms),
    );
  }

  Widget _filterTab(String label, ManagedUserStatus? value) {
    final theme = Theme.of(context);
    final isSelected = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.md),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Future<void> _showInviteSheet() async {
    final emailCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    Set<String> selectedRoles = {};
    String? errorMsg;
    final rolesRepo = GetIt.I<RolesRepository>();
    final allRoles = await rolesRepo.getAll();
    final theme = Theme.of(context);

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Invite a new user',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailCtrl,
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
                  prefixIcon: const Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
                  prefixIcon: const Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Assign Roles',
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final r in allRoles)
                    FilterChip(
                      label: Text(r.name),
                      selected: selectedRoles.contains(r.id),
                      checkmarkColor: theme.colorScheme.primary,
                      selectedColor: theme.colorScheme.primaryContainer,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                        side: BorderSide(
                          color: selectedRoles.contains(r.id)
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outlineVariant,
                        ),
                      ),
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
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                  child: Text(
                    errorMsg!,
                    style: TextStyle(
                      color: theme.colorScheme.onErrorContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    try {
                      await GetIt.I<ManagedUsersRepository>().invite(
                        email: emailCtrl.text,
                        name: nameCtrl.text,
                        roleIds: selectedRoles.toList(),
                        now: DateTime.now(),
                      );
                      if (sheetCtx.mounted) {
                        Navigator.pop(sheetCtx);
                      }
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Invited ${emailCtrl.text.trim()}'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    } on ValidationFailure catch (f) {
                      setSheet(() => errorMsg = f.fieldErrors.entries
                          .map((e) => '${e.key}: ${e.value.join(', ')}')
                          .join('\n'));
                    }
                  },
                  child: const Text('Send Invitation', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
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
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Styled Initials Avatar
          CircleAvatar(
            radius: 22,
            backgroundColor: _avatarColor(user.status, theme),
            child: Text(
              user.name.isEmpty ? '?' : user.name[0].toUpperCase(),
              style: TextStyle(
                color: _textColor(user.status, theme),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        user.name.isEmpty ? 'New User' : user.name,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isMe)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                        ),
                        child: Text(
                          'You',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 9,
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    else
                      _statusBadge(user.status, theme),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  user.email,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  children: [
                    for (final role in user.roleIds)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(AppRadii.xs),
                        ),
                        child: Text(
                          role.replaceAll('role-', '').toUpperCase(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            onSelected: (action) => _runAction(context, action),
            itemBuilder: (_) => [
              if (user.status != ManagedUserStatus.active)
                const PopupMenuItem(
                  value: 'activate',
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline, size: 18, color: Colors.green),
                      SizedBox(width: 8),
                      Text('Activate User'),
                    ],
                  ),
                ),
              if (user.status == ManagedUserStatus.active)
                const PopupMenuItem(
                  value: 'suspend',
                  child: Row(
                    children: [
                      Icon(Icons.block_flipped, size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Suspend User'),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _runAction(BuildContext context, String action) async {
    final repo = GetIt.I<ManagedUsersRepository>();
    try {
      final next = await repo.changeStatus(
        user: user,
        newStatus: action == 'suspend'
            ? ManagedUserStatus.suspended
            : ManagedUserStatus.active,
        currentUserId: currentUserId,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status set to ${next.status.name}.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on ConflictFailure catch (f) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(f.message ?? 'Cannot apply.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Color _avatarColor(ManagedUserStatus s, ThemeData theme) {
    switch (s) {
      case ManagedUserStatus.active:
        return Colors.green.withValues(alpha: 0.1);
      case ManagedUserStatus.invited:
        return Colors.blue.withValues(alpha: 0.1);
      case ManagedUserStatus.suspended:
        return Colors.red.withValues(alpha: 0.1);
    }
  }

  Color _textColor(ManagedUserStatus s, ThemeData theme) {
    switch (s) {
      case ManagedUserStatus.active:
        return Colors.green.shade700;
      case ManagedUserStatus.invited:
        return Colors.blue.shade700;
      case ManagedUserStatus.suspended:
        return Colors.red.shade700;
    }
  }

  Widget _statusBadge(ManagedUserStatus s, ThemeData theme) {
    final bg = _avatarColor(s, theme);
    final text = _textColor(s, theme);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        s.name.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          fontSize: 9,
          color: text,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
