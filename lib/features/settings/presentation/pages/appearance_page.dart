import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../domain/entities/user_preferences.dart';
import '../../domain/repositories/preferences_repository.dart';

/// Slice 9.1.1 — light / dark / system toggle.
class AppearancePage extends StatelessWidget {
  const AppearancePage();

  @override
  Widget build(BuildContext context) {
    final repo = GetIt.I<PreferencesRepository>();
    return Scaffold(
      appBar: AppBar(title: const Text('Appearance')),
      body: StreamBuilder<UserPreferences>(
        stream: repo.watch(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final mode = snap.data!.themeMode;
          return RadioGroup<AppThemeMode>(
            groupValue: mode,
            onChanged: (v) async {
              if (v != null) await repo.setThemeMode(v);
            },
            child: ListView(
              children: [
                for (final m in AppThemeMode.values)
                  RadioListTile<AppThemeMode>(
                    title: Text(_label(m)),
                    subtitle: Text(_subtitle(m)),
                    value: m,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _label(AppThemeMode m) {
    switch (m) {
      case AppThemeMode.system:
        return 'System default';
      case AppThemeMode.light:
        return 'Light';
      case AppThemeMode.dark:
        return 'Dark';
    }
  }

  String _subtitle(AppThemeMode m) {
    switch (m) {
      case AppThemeMode.system:
        return 'Follow the OS appearance setting';
      case AppThemeMode.light:
        return 'Always use the light palette';
      case AppThemeMode.dark:
        return 'Always use the dark palette';
    }
  }
}
