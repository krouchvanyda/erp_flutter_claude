import 'dart:async';

import 'package:erp_mobile/shared/firebase_option/firebase_options.dart';
import 'package:erp_mobile/shared/firebase_services/firebase_notification_provider.dart';
import 'package:erp_mobile/shared/firebase_services/local_notification_provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:injectable/injectable.dart';

import 'app.dart';
import 'core/di/injection.dart';
import 'core/error/crash_hooks.dart';
import 'core/error/logging_crash_reporter.dart';
import 'core/push/push_token_storage.dart';
import 'core/sync/sync_engine.dart';
import 'core/utils/logger/console_logger.dart';
import 'features/auth/auth_di.dart';
import 'features/chat/chat_di.dart';
import 'features/finance/finance_di.dart';
import 'features/hr/hr_di.dart';
import 'features/inventory/inventory_di.dart';
import 'features/procurement/procurement_di.dart';
import 'features/projects/projects_di.dart';
import 'features/sales/sales_di.dart';
import 'features/settings/settings_di.dart';
import 'package:firebase_core/firebase_core.dart';

Future <void> main() async {
  // Build the bootstrap reporter outside DI so uncaught errors during
  // `configureDependencies()` are still captured.
  final reporter = LoggingCrashReporter(ConsoleLogger());

  runWithCrashHooks(
    reporter: reporter,
    body: () async {
      WidgetsFlutterBinding.ensureInitialized();

      // ── Firebase + push stack ──────────────────────────────────
      // Order matters here:
      //   1. Firebase.initializeApp before ANY firebase_* SDK call.
      //   2. onBackgroundMessage registered BEFORE runApp so the
      //      background isolate can find the handler when a push
      //      arrives while the app is terminated.
      //   3. Local-notification plugin initialised so the Android
      //      notification channel exists before any push tries to
      //      use it (Android 8+ drops notifications targeting a
      //      non-registered channel).
      //   4. Permission prompt awaited — old code was fire-and-forget,
      //      which let downstream getToken() race the iOS dialog.
      //   5. Token persisted to PushTokenStorage (flutter_secure_storage)
      //      and a refresh listener wired so rotated tokens flow into
      //      the same secure slot. Backend sync of the token still
      //      needs an endpoint (TODO below).
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions().currentPlatform,
      );
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      await LocalNotificationProvider().initialize();
      await FirebaseNotificationProvider.instance
          .requestNotificationPermissions();
      // Note: foreground / opened / initial-message listeners are
      // attached from `ErpMobileApp.initState` (lib/app.dart) so they
      // can carry the three labelled debug callbacks. Don't duplicate
      // the attach here — the provider's `initOnMessage*` methods are
      // idempotent (cancel prior subscription on re-call) but double-
      // attaching obscures who owns the callback.

      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      );
      configureDependencies(environment: Environment.prod);
      registerAuthModule(getIt);
      registerFinanceModule(getIt);
      registerProcurementModule(getIt);
      registerInventoryModule(getIt);
      registerSalesModule(getIt);
      registerHrModule(getIt);
      registerProjectsModule(getIt);
      registerSettingsModule(getIt);
      registerChatModule(getIt);

      // ── Persist the FCM token to secure storage ───────────────
      // PushTokenStorage is registered by `register_module.dart` as
      // SecretStorePushTokenStorage (flutter_secure_storage). The
      // initial fetch runs after DI is up so the storage handle is
      // available; subsequent rotations flow through the listener
      // below so a refreshed token is persisted without restart.
      //
      // TODO(backend): once a `POST /devices` (or equivalent) endpoint
      // exists, also push the token to the server so the backend can
      // target this device. `deleteFirebaseToken()` should be called
      // from the logout flow to deactivate it.
      unawaited(_persistAndWatchPushToken(getIt<PushTokenStorage>()));

      // Boot the chat wire stack — loads persisted identity / relay
      // URL and opens the WebSocket if one is configured. Errors
      // here must never block app launch (relay may be unreachable).
      unawaited(bootChatTransport(getIt));
      // Start listening to connectivity transitions so the queue drains
      // automatically when the device comes back online.
      getIt<SyncEngine>().start();
      runApp(const ErpMobileApp());
    },
  );
}

/// One-shot token fetch + lifelong refresh listener. Pulled into a
/// helper so `main()` stays readable. Failures are swallowed in
/// release (kDebugMode logs them) because a push-token error must
/// never block app launch.
Future<void> _persistAndWatchPushToken(PushTokenStorage storage) async {
  try {
    final token = await FirebaseNotificationProvider.instance.getFirebaseToken();
    if (token != null && token.isNotEmpty) {
      await storage.saveToken(token);
    }
    FirebaseNotificationProvider.instance.onTokenRefresh.listen(
      storage.saveToken,
      onError: (Object e) {
        if (kDebugMode) debugPrint('push: token refresh error → $e');
      },
    );
  } catch (e) {
    if (kDebugMode) debugPrint('push: initial token fetch failed → $e');
  }
}
