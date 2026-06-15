import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:erp_mobile/core/di/service_locator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/repositories/demo_sign_in.dart';
import '../../features/auth/repositories/permissions_repository.dart';
import '../router/app_router.dart';
import '../router/permissions_snapshot.dart';
import '../network/auth_interceptor.dart';
import '../network/connectivity_checker.dart';
import '../network/connectivity_plus_checker.dart';
import '../network/dio_client.dart';
import '../network/error_interceptor.dart';
import '../network/session_signal.dart';
import '../network/token_refresher.dart';
import '../network/token_storage.dart';
import '../push/device_id_storage.dart';
import '../push/device_registrar.dart';
import '../push/devices_remote_data_source.dart';
import '../push/local_push_simulator.dart';
import '../push/push_message_router.dart';
import '../push/push_notification_service.dart';
import '../push/push_token_storage.dart';
import '../realtime/realtime_service.dart';
import '../realtime/web_socket_realtime_channel.dart';
import '../router/auth_session.dart';
import '../analytics/analytics_service.dart';
import '../analytics/noop_analytics_service.dart';
import '../error/crash_reporter.dart';
import '../error/logging_crash_reporter.dart';
import '../i18n/in_memory_locale_service.dart';
import '../i18n/locale_service.dart';
import '../utils/logger/app_logger.dart';
import '../utils/logger/console_logger.dart';
import '../../features/auth/repositories/auth_remote_data_source.dart';
import '../../features/auth/repositories/biometric_service.dart';
import '../../features/auth/repositories/biometric_settings_dao.dart';
import '../../features/auth/repositories/cached_user_dao.dart';
import '../../features/auth/repositories/dio_token_refresher.dart';
import '../../features/auth/repositories/local_auth_biometric_service.dart';
import '../../features/auth/repositories/flutter_secure_storage_secret_store.dart';
import '../../features/auth/repositories/secret_store.dart';
import '../../features/auth/repositories/oauth_flow_session.dart';
import '../../features/auth/repositories/oauth_token_data_source.dart';
import '../../features/auth/repositories/pkce_generator.dart';
import '../../features/auth/repositories/secure_token_storage.dart';
import '../../features/notifications/repositories/notifications_dao.dart';
import '../../features/notifications/repositories/notifications_repository_impl.dart';
import '../../features/notifications/repositories/notifications_repository.dart';
import '../../features/notifications/bloc/notification_inbox_bloc.dart';
import 'app_env.dart';

/// Factory methods for the third-party / value objects that don't own their
/// own construction (env config, http client, secure storage, etc.).
///
/// Previously an `@module` for `injectable`; the codegen DI framework was
/// removed, so [registerCoreDependencies] now wires these into `get_it` by
/// hand (same manual style the chat module already uses). Local persistence
/// is backed by `SharedPreferences` (the SQLite/drift database was removed).
class AppModule {
  // ── Configuration ────────────────────────────────────────────
  AppEnv get appEnv => AppEnv.defaults();

  // ── Logging ──────────────────────────────────────────────────
  AppLogger get appLogger => ConsoleLogger();

  // ── Crash reporting ──────────────────────────────────────────
  /// In-app crash sink — used by feature code that catches a non-fatal
  /// exception. The bootstrap (`runWithCrashHooks`) constructs its OWN
  /// reporter outside DI so uncaught errors are captured even if DI
  /// initialisation throws.
  CrashReporter crashReporter(AppLogger logger) =>
      LoggingCrashReporter(logger);

  // ── Analytics ────────────────────────────────────────────────
  /// Default is the no-op sink — feature code can call `track`/`screen`
  /// from day one without a vendor SDK. Replace this binding to plug in
  /// Firebase / Segment / Mixpanel later.
  AnalyticsService get analyticsService => const NoopAnalyticsService();

  // ── Localization ─────────────────────────────────────────────
  /// Process-lifetime locale holder. Module 9 (Settings) will swap in a
  /// `shared_preferences`-backed implementation that survives app restart.
  LocaleService get localeService => InMemoryLocaleService();

  // ── Local persistence (shared_preferences) ──────────────────
  // The drift/SQLite database was removed; structural data that used to
  // live in local tables (cached user, RBAC permissions, biometric flag,
  // notification inbox) now persists in SharedPreferences. The instance is
  // registered manually in `main()` before `configureDependencies()` so
  // it's available synchronously here.
  CachedUserDao cachedUserDao(SharedPreferences prefs) => CachedUserDao(prefs);

  BiometricSettingsDao biometricSettingsDao(SharedPreferences prefs) =>
      BiometricSettingsDao(prefs);

  NotificationsDao notificationsDao(SharedPreferences prefs) =>
      NotificationsDao(prefs);

  // ── Connectivity ─────────────────────────────────────────────
  Connectivity get connectivity => Connectivity();

  ConnectivityChecker connectivityChecker(Connectivity c) =>
      ConnectivityPlusChecker(c);

  // ── Realtime (Slice 2.2.4) ───────────────────────────────────
  /// App-scoped: one shared connection feeds the dashboard's KPI /
  /// chart slots. Lifecycle is bracketed by `connect()` / `disconnect()`
  /// from the dashboard mount; teardown happens via `getIt.reset()` at
  /// app shutdown.
  ///
  /// The channel factory is wired inline — it's a static reference, not
  /// something injectable can reflect on (function typedefs aren't class
  /// elements), so going through DI for the factory itself adds nothing
  /// but ceremony.
  RealtimeService realtimeService(AppEnv env, AppLogger logger) =>
      RealtimeService(
        url: Uri.parse(env.realtimeUrl),
        channelFactory: WebSocketRealtimeChannel.connect,
        logger: logger.child('realtime'),
      );

  // ── Auth-token plumbing ──────────────────────────────────────
  /// Platform-encrypted secret store. Tokens (Slice 1.1.2) and any future
  /// auth secret (biometric crypto material, vendor API keys) live here
  /// and **only** here — never in drift, sqlite, shared_preferences, or
  /// app_metadata.
  SecretStore get secretStore => FlutterSecureStorageSecretStore();

  TokenStorage tokenStorage(SecretStore secrets) => SecureTokenStorage(secrets);

  /// Production token-refresher (Slice 1.1.3). Hits the auth server's
  /// refresh endpoint and threads the cached `user_id` through the
  /// log/crash context for observability.
  ///
  /// **Dedicated Dio (no shared interceptors)**: building one inline with
  /// `buildDio(env)` breaks the otherwise-circular dependency
  /// `Dio → AuthInterceptor → TokenRefresher → Dio` AND keeps the refresh
  /// call out of the auth/error interceptor chain (the refresh body
  /// carries the credential, and the refresher does its own DioException
  /// handling).
  TokenRefresher tokenRefresher(
    AppEnv env,
    CachedUserDao cachedUserDao,
    AppLogger logger,
    CrashReporter crashReporter,
  ) =>
      DioTokenRefresher(
        dio: buildDio(env),
        cachedUserDao: cachedUserDao,
        logger: logger,
        crashReporter: crashReporter,
      );

  // ── Auth datasources (Slices 1.1.x / 1.2.x) ─────────────────
  /// Dedicated Dio (no auth/error interceptors) — revoke calls follow
  /// RFC 7009 (refresh token in body, no Bearer required) and must not
  /// trigger a refresh dance during the user's sign-out flow.
  ///
  /// Higher-level auth bindings (repositories + bloc) are wired manually
  /// from `features/auth/auth_di.dart` so the module stays self-contained
  /// (same pattern as Modules 4–9).
  AuthRemoteDataSource authRemoteDataSource(AppEnv env) =>
      DioAuthRemoteDataSource(dio: buildDio(env));

  // ── Biometric unlock (Slice 1.2.3) ───────────────────────────
  /// `local_auth` wrapper. The only file that imports `package:local_auth`
  /// — feature code goes through the `BiometricService` interface so
  /// tests can fake it without dragging Flutter in.
  BiometricService get biometricService => LocalAuthBiometricService();

  // ── Notifications (Slice 2.3.1) ──────────────────────────────
  NotificationsRepository notificationsRepository(NotificationsDao dao) =>
      NotificationsRepositoryImpl(dao: dao);

  /// `@injectable` (factory) so each `NotificationInboxPage` mount gets
  /// a fresh bloc — ties the watch subscription's lifetime to the
  /// page's lifetime.
  NotificationInboxBloc notificationInboxBloc(
    NotificationsRepository repo,
  ) =>
      NotificationInboxBloc(repository: repo);

  // ── Push (Slice 2.3.2) ───────────────────────────────────────
  /// **Default binding is the dev simulator** — see
  /// [LocalPushSimulator] for the rationale (firebase_messaging needs
  /// platform config + a backing Firebase project that isn't operational
  /// yet). Swap to `FirebaseMessagingPushService` here when both land.
  ///
  /// Exposes the abstract [PushNotificationService] type. The dashboard's
  /// "[dev] Simulate push" button does an `is LocalPushSimulator`
  /// check to access `simulateNow()` — debug-only down-cast that
  /// disappears with the simulator binding when real FCM ships.
  LocalPushSimulator localPushSimulator() => LocalPushSimulator();

  PushTokenStorage pushTokenStorage(SecretStore secrets) =>
      SecretStorePushTokenStorage(secrets: secrets);

  /// Stable per-install device id. Lives in the same secret store as
  /// the push token so a full app reinstall wipes both together.
  DeviceIdStorage deviceIdStorage(SecretStore secrets) =>
      SecretStoreDeviceIdStorage(secrets: secrets);

  /// REST client for `POST /me/devices` / `DELETE /me/devices/{id}`.
  /// Uses the project-wide [Dio] so the auth interceptor is already
  /// attached.
  DevicesRemoteDataSource devicesRemoteDataSource(Dio dio) =>
      DioDevicesRemoteDataSource(dio: dio);

  /// Coordinates the three-step register handshake (fetch FCM token →
  /// read-or-create stable id → POST). One call per lifecycle event,
  /// invoked from auth login/logout + the FCM token-refresh listener.
  DeviceRegistrar deviceRegistrar(
    DevicesRemoteDataSource remote,
    PushNotificationService push,
    PushTokenStorage tokenStorage,
    DeviceIdStorage deviceIdStorage,
    AppLogger logger,
  ) =>
      DeviceRegistrar(
        remote: remote,
        push: push,
        tokenStorage: tokenStorage,
        deviceIdStorage: deviceIdStorage,
        logger: logger.child('devices'),
      );

  PushMessageRouter pushMessageRouter(
    PushNotificationService service,
    NotificationsRepository notifications,
    PushTokenStorage tokenStorage,
    AppLogger logger,
  ) =>
      PushMessageRouter(
        service: service,
        notifications: notifications,
        tokenStorage: tokenStorage,
        logger: logger.child('push'),
      );

  // ── OAuth2 PKCE datasources (Slice 1.2.2) ───────────────────
  /// Pure crypto — no platform deps, safe as a singleton. The internal
  /// `Random.secure()` is reseeded on every `generate()` from the OS RNG.
  PkceGenerator get pkceGenerator => PkceGenerator();

  /// In-memory holder for the in-flight authorization request. Memory
  /// only — verifier never lands in drift / secure-storage / prefs.
  /// Singleton because there's at most one OAuth flow at a time.
  OAuthFlowSession get oauthFlowSession => OAuthFlowSession();

  /// Dedicated Dio for the token endpoint (no shared interceptors —
  /// see `DioTokenRefresher` for the rationale; same cycle-break +
  /// no-recursive-refresh story).
  OAuthTokenDataSource oauthTokenDataSource(AppEnv env) =>
      DioOAuthTokenDataSource(dio: buildDio(env));

  /// Bridges the network-layer [SessionSignal] to the router-layer
  /// [AuthSession] without leaking Flutter into `core/network/`.
  SessionSignal sessionSignal(AuthSession session) =>
      _AuthSessionInvalidator(session);

  AuthInterceptor authInterceptor(
    TokenStorage storage,
    TokenRefresher refresher,
    SessionSignal signal,
  ) =>
      AuthInterceptor(
        tokenStorage: storage,
        tokenRefresher: refresher,
        sessionSignal: signal,
      );

  ErrorInterceptor get errorInterceptor => const ErrorInterceptor();

  // ── Dio (with interceptors attached) ─────────────────────────
  // Order matters: auth runs first so 401s get a refresh attempt before the
  // error interceptor maps them to Failure.unauthorized.
  Dio dio(
    AppEnv env,
    AuthInterceptor authInterceptor,
    ErrorInterceptor errorInterceptor,
  ) {
    final dio = buildDio(env);
    authInterceptor.dio = dio;
    dio.interceptors
      ..add(authInterceptor)
      ..add(errorInterceptor);
    return dio;
  }
}

class _AuthSessionInvalidator implements SessionSignal {
  _AuthSessionInvalidator(this._session);
  final AuthSession _session;

  @override
  Future<void> invalidate() => _session.signOut();
}

/// Registers every core dependency into [getIt].
///
/// Hand-written replacement for the former generated `injection.config.dart`.
/// All registrations are lazy (or factory), so declaration order doesn't
/// matter — `SharedPreferences` must be registered by the caller first (see
/// `main()`). `PermissionsRepository` is registered by `registerAuthModule`,
/// which runs after this; the lazy `PermissionsSnapshot` binding tolerates
/// that since it's only resolved on first use.
void registerCoreDependencies(GetIt getIt) {
  final m = AppModule();
  getIt
    ..registerLazySingleton<AppEnv>(() => m.appEnv)
    ..registerLazySingleton<AppLogger>(() => m.appLogger)
    ..registerLazySingleton<AnalyticsService>(() => m.analyticsService)
    ..registerLazySingleton<LocaleService>(() => m.localeService)
    ..registerLazySingleton<Connectivity>(() => m.connectivity)
    ..registerLazySingleton<SecretStore>(() => m.secretStore)
    ..registerLazySingleton<BiometricService>(() => m.biometricService)
    ..registerLazySingleton<PkceGenerator>(() => m.pkceGenerator)
    ..registerLazySingleton<OAuthFlowSession>(() => m.oauthFlowSession)
    ..registerLazySingleton<ErrorInterceptor>(() => m.errorInterceptor)
    ..registerLazySingleton<CachedUserDao>(
        () => m.cachedUserDao(getIt<SharedPreferences>()))
    ..registerLazySingleton<BiometricSettingsDao>(
        () => m.biometricSettingsDao(getIt<SharedPreferences>()))
    ..registerLazySingleton<NotificationsDao>(
        () => m.notificationsDao(getIt<SharedPreferences>()))
    ..registerLazySingleton<AuthSession>(StubAuthSession.new)
    ..registerLazySingleton<DemoSignInService>(
        () => DemoSignInService(getIt<CachedUserDao>()))
    ..registerLazySingleton<PushNotificationService>(
        () => m.localPushSimulator())
    ..registerLazySingleton<CrashReporter>(
        () => m.crashReporter(getIt<AppLogger>()))
    ..registerLazySingleton<AuthRemoteDataSource>(
        () => m.authRemoteDataSource(getIt<AppEnv>()))
    ..registerLazySingleton<OAuthTokenDataSource>(
        () => m.oauthTokenDataSource(getIt<AppEnv>()))
    ..registerLazySingleton<ConnectivityChecker>(
        () => m.connectivityChecker(getIt<Connectivity>()))
    ..registerLazySingleton<RealtimeService>(
        () => m.realtimeService(getIt<AppEnv>(), getIt<AppLogger>()))
    ..registerLazySingleton<PermissionsSnapshot>(
        () => PermissionsSnapshot(
              cachedUserDao: getIt<CachedUserDao>(),
              permissionsRepository: getIt<PermissionsRepository>(),
            ))
    ..registerLazySingleton<TokenStorage>(
        () => m.tokenStorage(getIt<SecretStore>()))
    ..registerLazySingleton<PushTokenStorage>(
        () => m.pushTokenStorage(getIt<SecretStore>()))
    ..registerLazySingleton<DeviceIdStorage>(
        () => m.deviceIdStorage(getIt<SecretStore>()))
    ..registerLazySingleton<NotificationsRepository>(
        () => m.notificationsRepository(getIt<NotificationsDao>()))
    ..registerLazySingleton<TokenRefresher>(() => m.tokenRefresher(
          getIt<AppEnv>(),
          getIt<CachedUserDao>(),
          getIt<AppLogger>(),
          getIt<CrashReporter>(),
        ))
    ..registerFactory<NotificationInboxBloc>(
        () => m.notificationInboxBloc(getIt<NotificationsRepository>()))
    ..registerLazySingleton<SessionSignal>(
        () => m.sessionSignal(getIt<AuthSession>()))
    ..registerLazySingleton<AppRouter>(() => AppRouter(
          getIt<AuthSession>(),
          getIt<PermissionsSnapshot>(),
        ))
    ..registerLazySingleton<AuthInterceptor>(() => m.authInterceptor(
          getIt<TokenStorage>(),
          getIt<TokenRefresher>(),
          getIt<SessionSignal>(),
        ))
    ..registerLazySingleton<PushMessageRouter>(() => m.pushMessageRouter(
          getIt<PushNotificationService>(),
          getIt<NotificationsRepository>(),
          getIt<PushTokenStorage>(),
          getIt<AppLogger>(),
        ))
    ..registerLazySingleton<Dio>(() => m.dio(
          getIt<AppEnv>(),
          getIt<AuthInterceptor>(),
          getIt<ErrorInterceptor>(),
        ))
    ..registerLazySingleton<DevicesRemoteDataSource>(
        () => m.devicesRemoteDataSource(getIt<Dio>()))
    ..registerLazySingleton<DeviceRegistrar>(() => m.deviceRegistrar(
          getIt<DevicesRemoteDataSource>(),
          getIt<PushNotificationService>(),
          getIt<PushTokenStorage>(),
          getIt<DeviceIdStorage>(),
          getIt<AppLogger>(),
        ));
}
