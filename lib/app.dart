import 'package:flutter/material.dart';

import 'core/di/injection.dart';
import 'core/i18n/locale_service.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/settings/domain/entities/user_preferences.dart' as pref_entities;
import 'features/settings/domain/repositories/preferences_repository.dart';
import 'l10n/app_localizations.dart';

/// Root application widget.
///
/// Pulls the resolved [AppRouter] from DI, applies the global [AppTheme]
/// dynamically watching [PreferencesRepository] to switch theme modes (light, dark, system),
/// and rebuilds whenever preferences emit language or theme changes.
class ErpMobileApp extends StatelessWidget {
  const ErpMobileApp({
    super.key,
    AppRouter? router,
    LocaleService? localeService,
  })  : _injectedRouter = router,
        _injectedLocaleService = localeService;

  /// Test seams — production code constructs without these and lets DI
  /// supply both.
  final AppRouter? _injectedRouter;
  final LocaleService? _injectedLocaleService;

  @override
  Widget build(BuildContext context) {
    final router = _injectedRouter ?? getIt<AppRouter>();
    final prefRepo = getIt<PreferencesRepository>();

    return StreamBuilder<pref_entities.UserPreferences>(
      stream: prefRepo.watch(),
      initialData: pref_entities.UserPreferences.initial,
      builder: (context, snapshot) {
        final prefs = snapshot.data ?? pref_entities.UserPreferences.initial;
        
        // Map settings AppThemeMode to Flutter's ThemeMode
        final themeMode = _mapThemeMode(prefs.themeMode);
        
        // Map settings AppLanguage to language code
        final langCode = prefs.language == pref_entities.AppLanguage.en ? 'en' : 'km';

        return MaterialApp.router(
          onGenerateTitle: (ctx) => AppLocalizations.of(ctx).appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: themeMode,
          locale: Locale(langCode),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router.config,
        );
      },
    );
  }

  ThemeMode _mapThemeMode(pref_entities.AppThemeMode mode) {
    switch (mode) {
      case pref_entities.AppThemeMode.light:
        return ThemeMode.light;
      case pref_entities.AppThemeMode.dark:
        return ThemeMode.dark;
      case pref_entities.AppThemeMode.system:
        return ThemeMode.system;
    }
  }
}
