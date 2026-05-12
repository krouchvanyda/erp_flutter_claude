import 'package:flutter/material.dart';

import 'core/di/injection.dart';
import 'core/i18n/app_language.dart';
import 'core/i18n/locale_service.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'l10n/app_localizations.dart';

/// Root application widget.
///
/// Pulls the resolved [AppRouter] from DI, applies the global [AppTheme]
/// for both light and dark modes (system mode follows the device), and
/// rebuilds whenever [LocaleService] emits a language change.
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
    final localeService = _injectedLocaleService ?? getIt<LocaleService>();

    return StreamBuilder<AppLanguage>(
      stream: localeService.changes,
      initialData: localeService.current,
      builder: (context, snapshot) {
        final language = snapshot.data ?? AppLanguage.fallback;
        return MaterialApp.router(
          onGenerateTitle: (ctx) => AppLocalizations.of(ctx).appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: ThemeMode.system,
          locale: Locale(language.code),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router.config,
        );
      },
    );
  }
}
