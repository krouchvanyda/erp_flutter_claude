import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show appFlavor;

import 'app/app.dart';
import 'app/app_di.dart';
import 'core/config/flavor.dart';
import 'core/di/service_locator.dart';
import 'core/router/auth_session.dart';

/// Plain `flutter run`: flavor comes from `--flavor` (dev when none).
Future<void> main() => bootstrap(Flavor.current);

/// Shared start-up for every entry point (main_dev / main_uat / main_prod).
Future<void> bootstrap(Flavor flavor) async {
  // Debug-only guard: `--flavor` (native side) and the entry point (Dart
  // side) must agree, e.g. `--flavor dev -t lib/main_prod.dart` is a bug.
  // `appFlavor == null` is fine: no `--flavor` given, the entry point wins.
  assert(
    appFlavor == null || appFlavor == flavor.name,
    'Flavor mismatch: --flavor $appFlavor but entry point is ${flavor.name}',
  );
  Flavor.pin(flavor);
  WidgetsFlutterBinding.ensureInitialized(); // plugins need the bridge first
  await configureAppDependencies(); // fill the DI box: core + features

  // Edge: take services from the box, pass them in by constructor.
  runApp(App(session: getIt<AuthSession>()));
}
