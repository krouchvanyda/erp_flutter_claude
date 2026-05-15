import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/api_environment.dart';
import '../../domain/repositories/admin_repositories.dart';
import '../../domain/usecases/manage_environments.dart';

/// Slice 9.2.3 — API environment / tenant switcher.
class ApiConfigPage extends StatelessWidget {
  const ApiConfigPage();

  @override
  Widget build(BuildContext context) {
    final repo = GetIt.I<ApiEnvironmentsRepository>();
    return Scaffold(
      appBar: AppBar(title: const Text('API configuration')),
      body: StreamBuilder<List<ApiEnvironment>>(
        stream: repo.watchAll(),
        builder: (context, envSnap) {
          if (!envSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return StreamBuilder<String>(
            stream: repo.watchCurrentId(),
            builder: (context, currentSnap) {
              final currentId = currentSnap.data ?? '';
              final envs = envSnap.data!;
              return RadioGroup<String>(
                groupValue: currentId,
                onChanged: (id) async {
                  if (id != null) await repo.setCurrent(id);
                },
                child: ListView(
                  children: [
                    const _Banner(),
                    for (final env in envs)
                      _EnvTile(env: env, currentId: currentId),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
    );
  }

  Future<void> _showAddSheet(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    Map<String, List<String>> errors = const {};

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
                'Add custom environment',
                style: Theme.of(sheetCtx).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Name',
                  border: const OutlineInputBorder(),
                  errorText: errors['name']?.firstOrNull,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: urlCtrl,
                decoration: InputDecoration(
                  labelText: 'Base URL',
                  hintText: 'https://api.tenant.example',
                  border: const OutlineInputBorder(),
                  errorText: errors['baseUrl']?.firstOrNull,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  try {
                    final draft = validateApiEnvironment(
                      name: nameCtrl.text,
                      baseUrl: urlCtrl.text,
                    );
                    await GetIt.I<ApiEnvironmentsRepository>().create(draft);
                    if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                  } on ValidationFailure catch (f) {
                    setSheet(() => errors = f.fieldErrors);
                  }
                },
                child: const Text('Add'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: Colors.amber),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Switching environments signs you out of the current tenant.',
            ),
          ),
        ],
      ),
    );
  }
}

class _EnvTile extends StatelessWidget {
  const _EnvTile({required this.env, required this.currentId});
  final ApiEnvironment env;
  final String currentId;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: RadioListTile<String>(
        value: env.id,
        title: Row(
          children: [
            Expanded(child: Text(env.name)),
            if (env.isBuiltIn)
              const Chip(
                label: Text('Built-in'),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
        subtitle: Text(env.baseUrl),
        secondary: env.isBuiltIn
            ? null
            : IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  try {
                    ensureEnvironmentIsDeletable(
                      env: env,
                      currentEnvironmentId: currentId,
                    );
                    await GetIt.I<ApiEnvironmentsRepository>()
                        .delete(env.id);
                  } on ConflictFailure catch (f) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content:
                                Text(f.message ?? 'Cannot delete.')),
                      );
                    }
                  }
                },
              ),
      ),
    );
  }
}
