import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';

import 'app.dart';
import 'core/di/injection.dart';
import 'core/error/crash_hooks.dart';
import 'core/error/logging_crash_reporter.dart';
import 'core/sync/sync_engine.dart';
import 'core/utils/logger/console_logger.dart';
import 'features/hr/hr_di.dart';
import 'features/inventory/inventory_di.dart';
import 'features/procurement/procurement_di.dart';
import 'features/projects/projects_di.dart';
import 'features/sales/sales_di.dart';
import 'features/settings/settings_di.dart';

void main() {
  // Build the bootstrap reporter outside DI so uncaught errors during
  // `configureDependencies()` are still captured.
  final reporter = LoggingCrashReporter(ConsoleLogger());

  runWithCrashHooks(
    reporter: reporter,
    body: () {
      WidgetsFlutterBinding.ensureInitialized();
      configureDependencies(environment: Environment.prod);
      registerProcurementModule(getIt);
      registerInventoryModule(getIt);
      registerSalesModule(getIt);
      registerHrModule(getIt);
      registerProjectsModule(getIt);
      registerSettingsModule(getIt);
      // Start listening to connectivity transitions so the queue drains
      // automatically when the device comes back online.
      getIt<SyncEngine>().start();
      runApp(const ErpMobileApp());
    },
  );
}
