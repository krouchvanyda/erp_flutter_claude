import 'package:erp_mobile/shared/firebase_services/firebase_notification_provider.dart';
import 'package:flutter/material.dart';

import 'core/di/injection.dart';
import 'core/i18n/locale_service.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/chat/presentation/widgets/incoming_call_overlay.dart';
import 'features/settings/data/repositories/preferences_repository.dart';
import 'features/settings/entities/user_preferences.dart' as pref_entities;
import 'l10n/app_localizations.dart';

/// Root application widget.
///
/// Pulls the resolved [AppRouter] from DI, applies the global [AppTheme]
/// dynamically watching [PreferencesRepository] to switch theme modes (light, dark, system),
/// and rebuilds whenever preferences emit language or theme changes.
class ErpMobileApp extends StatefulWidget {
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
  State<ErpMobileApp> createState() => _ErpMobileAppState();
}

class _ErpMobileAppState extends State<ErpMobileApp> {
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    FirebaseNotificationProvider().getFirebaseToken();
    FirebaseNotificationProvider().initOnMessageListener(getData: (message){
      print("message----------------------- in App $message");
    });
    FirebaseNotificationProvider().initOnMessageOpenedApp(getData: (message){
      print("message-----------------------out app minimue $message");
    });
    FirebaseNotificationProvider().handleInitialMessage(getData: (message){
      print("message-----------------------kill app $message");
    });
  }
  @override
  Widget build(BuildContext context) {
    final router = widget._injectedRouter ?? getIt<AppRouter>();
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
          // Slice 10.2.3 — wrap every route in [IncomingCallOverlay]
          // so a peer-initiated call invite shows the full-screen
          // accept/reject sheet regardless of which page is on top.
          builder: (context, child) =>
              IncomingCallOverlay(child: child ?? const SizedBox.shrink()),
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
