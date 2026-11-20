import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/flavor.dart';
import '../network/app_service.dart';
import '../network/auth_interceptor.dart';
import '../network/dio_factory.dart';
import '../network/token_storage.dart';
import '../router/auth_session.dart';
import '../storage/user_cache.dart';
import 'service_locator.dart';

/// Fills the box with CORE services. Called by `configureAppDependencies()`
/// (lib/app/app_di.dart), which then adds each feature module — `core/` never
/// imports `features/`.
///
/// Order matters: register a thing before anything that needs it.
///
/// ```
/// configureDependencies()
///   ├── _registerCore()        SharedPreferences  (Step 1.3)
///   │                          AuthSession         (Step 1.4)
///   │                          Dio, AppService     (Step 2.1)
///   │                          TokenStorage, AuthInterceptor (Step 2.2)
///   │                          UserCache           (Step 4.1)
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

  // Tokens live in the secure vault (Keychain / Keystore).
  getIt.registerLazySingleton<FlutterSecureStorage>(
    () => TokenStorage.secureStorage,
  );
  getIt.registerLazySingleton<TokenStorage>(
    () => TokenStorage(getIt<FlutterSecureStorage>()),
  );

  // The logged-in user (not secret) → shared_preferences.
  getIt.registerLazySingleton<UserCache>(
    () => UserCache(getIt<SharedPreferences>()),
  );

  // ONE app Dio, with the auth interceptor. AppService wraps it.
  getIt.registerLazySingleton<Dio>(
    () => createDio(
      Flavor.current,
      interceptors: [
        AuthInterceptor(
          tokenStorage: getIt<TokenStorage>(),
          // separate Dio WITHOUT the interceptor → refresh can't loop
          refreshDio: createDio(Flavor.current),
          // session really over → forget the user, AuthGate shows Login
          onSessionExpired: () {
            getIt<UserCache>().clear();
            getIt<AuthSession>().markLoggedOut();
          },
        ),
      ],
    ),
  );
  getIt.registerLazySingleton<AppService>(() => AppService(getIt<Dio>()));
}
