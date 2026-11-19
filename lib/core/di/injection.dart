import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/flavor.dart';
import '../network/app_service.dart';
import '../network/dio_factory.dart';
import '../router/auth_session.dart';
import 'service_locator.dart';

/// Fills the box. Called ONCE from `bootstrap()` before `runApp()`.
///
/// Order matters: register a thing before anything that needs it.
/// Each feature will add its own `registerXModule(getIt)` here later:
///
/// ```
/// configureDependencies()
///   ├── _registerCore()        SharedPreferences  (Step 1.3)
///   │                          AuthSession         (Step 1.4)
///   │                          Dio, AppService     (Step 2.1)
///   │                          TokenStorage        (Step 2.2)
///   ├── registerAuthModule()   (Step 3)
///   ├── registerProfileModule()(Step 4)
///   ├── registerChatModule()   (Step 5)
///   └── registerCallModule()   (Step 6)
/// ```
Future<void> configureDependencies() async {
  await _registerCore();
}

Future<void> _registerCore() async {
  // async setup → build it first, then registerSingleton the ready object.
  final prefs = await SharedPreferences.getInstance();
  getIt.registerSingleton<SharedPreferences>(prefs);

  // One session for the whole app: router, splash, login, logout, and
  // later the token interceptor (Step 2) all share it.
  getIt.registerLazySingleton<AuthSession>(AuthSession.new);

  // ONE Dio for the whole app; AppService wraps it for repositories.
  getIt.registerLazySingleton<Dio>(() => createDio(Flavor.current));
  getIt.registerLazySingleton<AppService>(() => AppService(getIt<Dio>()));
}
