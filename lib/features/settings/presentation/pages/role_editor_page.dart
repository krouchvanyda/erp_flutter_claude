import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/managed_user.dart';
import '../../domain/repositories/admin_repositories.dart';
import '../../domain/usecases/manage_roles.dart';

/// Slice 9.2.2 — role + permission scope editor.
///
/// **Why a static well-known scope list**: the permission token names
/// are part of the API contract; surfacing them as a chip palette in
/// the editor keeps admins from typing free-form scopes that would
/// silently no-op when the backend evaluates them.
const _knownScopes = <String>[
  'admin',
  'finance.*',
  'finance.read',
  'finance.approve',
  'inventory.*',
  'inventory.read',
  'sales.*',
  'sales.read',
  'hr.*',
  'projects.*',
];

class RoleEditorPage extends StatelessWidget {
  const RoleEditorPage();

  @override
  Widget build(BuildContext context) {
    final repo = GetIt.I<RolesRepository>();
    return Scaffold(
      appBar: AppBar(title: const Text('Roles & permissions')),
      body: StreamBuilder<List<Role>>(
        stream: repo.watchAll(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final roles = snap.data!;
          return ListView(
            padding: const EdgeInsets.all(8),
            children: [for (final r in roles) _RoleCard(role: r)],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('New role'),
      ),
    );
  }

  Future<void> _showCreateSheet(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    Set<String> selectedScopes = {};
    String? errorMsg;

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
                'Create a role',
                style: Theme.of(sheetCtx).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Permission scopes',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final scope in _knownScopes)
                    FilterChip(
                      label: Text(scope),
                      selected: selectedScopes.contains(scope),
                      onSelected: (sel) => setSheet(() {
                        if (sel) {
                          selectedScopes.add(scope);
                        } else {
                          selectedScopes.remove(scope);
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
                    final draft = createRole(
                      name: nameCtrl.text,
                      description: descCtrl.text,
                      permissionTokens: selectedScopes.toList(),
                    );
                    await GetIt.I<RolesRepository>().create(draft);
                    if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                  } on ValidationFailure catch (f) {
                    setSheet(() => errorMsg = f.fieldErrors.entries
                        .map((e) => '${e.key}: ${e.value.join(', ')}')
                        .join('\n'));
                  }
                },
                child: const Text('Create'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.role});
  final Role role;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        leading: Icon(
          role.isSystem ? Icons.lock_outline : Icons.shield_outlined,
        ),
        title: Row(
          children: [
            Expanded(child: Text(role.name)),
            if (role.isSystem)
              const Chip(
                label: Text('Built-in'),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
        subtitle: Text(role.description),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Scopes',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final scope in _knownScopes)
                      FilterChip(
                        label: Text(scope),
                        selected:
                            role.permissionTokens.contains(scope),
                        onSelected: role.isSystem
                            ? null
                            : (sel) async {
                                final next =
                                    Set<String>.of(role.permissionTokens);
                                if (sel) {
                                  next.add(scope);
                                } else {
                                  next.remove(scope);
                                }
                                try {
                                  final updated = updateRolePermissions(
                                    role: role,
                                    permissionTokens: next.toList(),
                                  );
                                  await GetIt.I<RolesRepository>()
                                      .update(updated);
                                } on Failure catch (f) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      SnackBar(
                                          content:
                                              Text('Cannot update: $f')),
                                    );
                                  }
                                }
                              },
                      ),
                  ],
                ),
                if (!role.isSystem) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                          foregroundColor: Colors.red),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete role'),
                      onPressed: () => _confirmDelete(context),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final users = await GetIt.I<ManagedUsersRepository>().getAll();
    try {
      ensureRoleIsDeletable(role: role, currentUsers: users);
    } on ConflictFailure catch (f) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(f.message ?? 'Cannot delete.')),
        );
      }
      return;
    }
    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('Delete "${role.name}"?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await GetIt.I<RolesRepository>().delete(role.id);
    }
  }
}
