import 'dart:async';

import 'package:erp_mobile/shared/firebase_option/firebase_options.dart';
import 'package:erp_mobile/shared/firebase_services/firebase_notification_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:injectable/injectable.dart';

import 'app.dart';
import 'core/di/injection.dart';
import 'core/error/crash_hooks.dart';
import 'core/error/logging_crash_reporter.dart';
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
      await Firebase.initializeApp(options: DefaultFirebaseOptions().currentPlatform);
      FirebaseNotificationProvider().requestNotificationPermissions();
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
