import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../domain/entities/user_preferences.dart';
import '../../domain/repositories/preferences_repository.dart';

/// Slice 9.1.2 — language selector.
///
/// `AppLanguage` enum is what binds to drift; the human label + flag
/// emoji belong to the UI only so we can add new locales without
/// touching the entity.
class LanguagePage extends StatelessWidget {
  const LanguagePage();

  @override
  Widget build(BuildContext context) {
    final repo = GetIt.I<PreferencesRepository>();
    return Scaffold(
      appBar: AppBar(title: const Text('Language')),
      body: StreamBuilder<UserPreferences>(
        stream: repo.watch(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final lang = snap.data!.language;
          return RadioGroup<AppLanguage>(
            groupValue: lang,
            onChanged: (v) async {
              if (v != null) await repo.setLanguage(v);
            },
            child: ListView(
              children: [
                for (final l in AppLanguage.values)
                  RadioListTile<AppLanguage>(
                    secondary: Text(
                      _flag(l),
                      style: const TextStyle(fontSize: 24),
                    ),
                    title: Text(_label(l)),
                    subtitle: Text(_native(l)),
                    value: l,
                  ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Language change applies on next app launch in this demo build.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _label(AppLanguage l) {
    switch (l) {
      case AppLanguage.en:
        return 'English';
      case AppLanguage.km:
        return 'Khmer';
    }
  }

  String _native(AppLanguage l) {
    switch (l) {
      case AppLanguage.en:
        return 'English';
      case AppLanguage.km:
        return 'ភាសាខ្មែរ';
    }
  }

  String _flag(AppLanguage l) {
    switch (l) {
      case AppLanguage.en:
        return '🇬🇧';
      case AppLanguage.km:
        return '🇰🇭';
    }
  }
}
