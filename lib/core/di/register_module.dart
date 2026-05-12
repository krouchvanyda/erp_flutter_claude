import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

import '../database/app_database.dart';
import '../database/app_metadata_dao.dart';
import '../database/cache_freshness_dao.dart';
import '../database/connection.dart';
import '../database/sync_queue_dao.dart';
import '../network/auth_interceptor.dart';
import '../network/connectivity_checker.dart';
import '../network/connectivity_plus_checker.dart';
import '../network/dio_client.dart';
import '../network/error_interceptor.dart';
import '../network/session_signal.dart';
import '../network/token_refresher.dart';
import '../network/token_storage.dart';
import '../router/auth_session.dart';
import '../sync/conflict_policy.dart';
import '../sync/conflict_policy_registry.dart';
import '../sync/sync_bloc.dart';
import '../sync/sync_engine.dart';
import '../sync/sync_op_executor.dart';
import '../analytics/analytics_service.dart';
import '../analytics/noop_analytics_service.dart';
import '../error/crash_reporter.dart';
import '../error/logging_crash_reporter.dart';
import '../i18n/in_memory_locale_service.dart';
import '../i18n/locale_service.dart';
import '../utils/logger/app_logger.dart';
import '../utils/logger/console_logger.dart';
import '../../features/auth/data/datasources/auth_remote_data_source.dart';
import '../../features/auth/data/datasources/cached_user_dao.dart';
import '../../features/auth/data/datasources/dio_token_refresher.dart';
import '../../features/auth/data/datasources/flutter_secure_storage_secret_store.dart';
import '../../features/auth/data/datasources/secret_store.dart';
import '../../features/auth/data/datasources/oauth_flow_session.dart';
import '../../features/auth/data/datasources/oauth_token_data_source.dart';
import '../../features/auth/data/datasources/pkce_generator.dart';
import '../../features/auth/data/datasources/secure_token_storage.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/data/repositories/stub_otp_repository.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/repositories/otp_repository.dart';
import '../../features/auth/domain/usecases/exchange_authorization_code.dart';
import '../../features/auth/domain/usecases/sign_out.dart';
import '../../features/auth/domain/usecases/verify_otp.dart';
import '../../features/auth/presentation/bloc/otp_bloc.dart';
import 'app_env.dart';

/// Centralizes registration of third-party / value objects that don't own
/// their own `@injectable` annotation (env config, http client, drift db,
/// secure storage, etc.).
///
/// Each getter / annotated method becomes a registration in the generated
/// `injection.config.dart`. Add new providers here as later slices come
/// online (0.3.1 will add the drift `AppDatabase`, etc.).
@module
abstract class AppModule {
  // ── Configuration ────────────────────────────────────────────
  @lazySingleton
  AppEnv get appEnv => AppEnv.defaults();

  // ── Logging ──────────────────────────────────────────────────
  @lazySingleton
  AppLogger get appLogger => ConsoleLogger();

  // ── Crash reporting ──────────────────────────────────────────
  /// In-app crash sink — used by feature code that catches a non-fatal
  /// exception. The bootstrap (`runWithCrashHooks`) constructs its OWN
  /// reporter outside DI so uncaught errors are captured even if DI
  /// initialisation throws.
  @lazySingleton
  CrashReporter crashReporter(AppLogger logger) =>
      LoggingCrashReporter(logger);

  // ── Analytics ────────────────────────────────────────────────
  /// Default is the no-op sink — feature code can call `track`/`screen`
  /// from day one without a vendor SDK. Replace this binding to plug in
  /// Firebase / Segment / Mixpanel later.
  @lazySingleton
  AnalyticsService get analyticsService => const NoopAnalyticsService();

  // ── Localization ─────────────────────────────────────────────
  /// Process-lifetime locale holder. Module 9 (Settings) will swap in a
  /// `shared_preferences`-backed implementation that survives app restart.
  @lazySingleton
  LocaleService get localeService => InMemoryLocaleService();

  // ── Local database ───────────────────────────────────────────
  @lazySingleton
  AppDatabase appDatabase() => AppDatabase(openAppDatabase());

  @lazySingleton
  AppMetadataDao appMetadataDao(AppDatabase db) => db.appMetadataDao;

  @lazySingleton
  CacheFreshnessDao cacheFreshnessDao(AppDatabase db) => db.cacheFreshnessDao;

  @lazySingleton
  SyncQueueDao syncQueueDao(AppDatabase db) => db.syncQueueDao;

  @lazySingleton
  CachedUserDao cachedUserDao(AppDatabase db) => db.cachedUserDao;

  // ── Sync conflict resolution ────────────────────────────────
  /// The framework-wide default. Feature modules can swap this out by
  /// providing a richer [ConflictPolicyRegistry] (with per-entity overrides)
  /// once their sync flow needs more than server-wins.
  @lazySingleton
  ConflictPolicy get defaultConflictPolicy => const ServerWinsPolicy();

  @lazySingleton
  ConflictPolicyRegistry conflictPolicyRegistry(ConflictPolicy defaultPolicy) =>
      ConflictPolicyRegistry(defaultPolicy: defaultPolicy);

  // ── Sync engine ─────────────────────────────────────────────
  @lazySingleton
  SyncOpExecutor syncOpExecutor(Dio dio) => DioSyncOpExecutor(dio);

  @lazySingleton
  SyncEngine syncEngine(
    SyncQueueDao queue,
    SyncOpExecutor executor,
    ConnectivityChecker connectivity,
  ) =>
      SyncEngine(
        queue: queue,
        executor: executor,
        connectivity: connectivity,
      );

  /// UI-facing sync state holder. The bloc takes plain streams + a thunk so
  /// it stays Flutter-free; the wiring here narrows the engine and queue
  /// down to just the surfaces it actually uses.
  @lazySingleton
  SyncBloc syncBloc(SyncEngine engine, SyncQueueDao queue) => SyncBloc(
        triggerSync: engine.triggerSync,
        engineEvents: engine.events,
        pendingCounts: queue.watchPendingCount(),
      );

  // ── Connectivity ─────────────────────────────────────────────
  @lazySingleton
  Connectivity get connectivity => Connectivity();

  @lazySingleton
  ConnectivityChecker connectivityChecker(Connectivity c) =>
      ConnectivityPlusChecker(c);

  // ── Auth-token plumbing ──────────────────────────────────────
  /// Platform-encrypted secret store. Tokens (Slice 1.1.2) and any future
  /// auth secret (biometric crypto material, vendor API keys) live here
  /// and **only** here — never in drift, sqlite, shared_preferences, or
  /// app_metadata.
  @lazySingleton
  SecretStore get secretStore => FlutterSecureStorageSecretStore();

  @lazySingleton
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
  @lazySingleton
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

  // ── Auth feature (Slice 1.1.4 sign-out) ──────────────────────
  /// Dedicated Dio (no auth/error interceptors) — revoke calls follow
  /// RFC 7009 (refresh token in body, no Bearer required) and must not
  /// trigger a refresh dance during the user's sign-out flow.
  @lazySingleton
  AuthRemoteDataSource authRemoteDataSource(AppEnv env) =>
      DioAuthRemoteDataSource(dio: buildDio(env));

  @lazySingleton
  AuthRepository authRepository(
    TokenStorage tokenStorage,
    AuthRemoteDataSource remote,
    CachedUserDao cachedUserDao,
    AppLogger logger,
    CrashReporter crashReporter,
  ) =>
      AuthRepositoryImpl(
        tokenStorage: tokenStorage,
        remote: remote,
        cachedUserDao: cachedUserDao,
        logger: logger,
        crashReporter: crashReporter,
      );

  @lazySingleton
  SignOutUseCase signOutUseCase(
    AuthRepository authRepository,
    SessionSignal sessionSignal,
    AnalyticsService analytics,
  ) =>
      SignOutUseCase(
        authRepository: authRepository,
        sessionSignal: sessionSignal,
        analytics: analytics,
      );

  // ── MFA / OTP (Slice 1.2.1) ──────────────────────────────────
  /// Stub verifier — accepts the dev code `123456`. Replace this binding
  /// when the real MFA backend comes online; nothing else changes.
  @lazySingleton
  OtpRepository get otpRepository => const StubOtpRepository();

  @lazySingleton
  VerifyOtpUseCase verifyOtpUseCase(OtpRepository repository) =>
      VerifyOtpUseCase(repository: repository);

  /// `@injectable` (factory) so each `OtpEntryPage` mount gets a fresh
  /// bloc with `code = ''`. Memory-only contract: nothing about the
  /// typed code survives the bloc's `close()`.
  @injectable
  OtpBloc otpBloc(VerifyOtpUseCase verifyOtp) =>
      OtpBloc(verifyOtp: verifyOtp);

  // ── OAuth2 PKCE (Slice 1.2.2) ───────────────────────────────
  /// Pure crypto — no platform deps, safe as a singleton. The internal
  /// `Random.secure()` is reseeded on every `generate()` from the OS RNG.
  @lazySingleton
  PkceGenerator get pkceGenerator => PkceGenerator();

  /// In-memory holder for the in-flight authorization request. Memory
  /// only — verifier never lands in drift / secure-storage / prefs.
  /// Singleton because there's at most one OAuth flow at a time.
  @lazySingleton
  OAuthFlowSession get oauthFlowSession => OAuthFlowSession();

  /// Dedicated Dio for the token endpoint (no shared interceptors —
  /// see `DioTokenRefresher` for the rationale; same cycle-break +
  /// no-recursive-refresh story).
  @lazySingleton
  OAuthTokenDataSource oauthTokenDataSource(AppEnv env) =>
      DioOAuthTokenDataSource(dio: buildDio(env));

  @lazySingleton
  ExchangeAuthorizationCodeUseCase exchangeAuthorizationCodeUseCase(
    OAuthFlowSession session,
    OAuthTokenDataSource dataSource,
    TokenStorage tokenStorage,
    AppEnv env,
  ) =>
      ExchangeAuthorizationCodeUseCase(
        session: session,
        dataSource: dataSource,
        tokenStorage: tokenStorage,
        env: env,
      );

  /// Bridges the network-layer [SessionSignal] to the router-layer
  /// [AuthSession] without leaking Flutter into `core/network/`.
  @lazySingleton
  SessionSignal sessionSignal(AuthSession session) =>
      _AuthSessionInvalidator(session);

  @lazySingleton
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

  @lazySingleton
  ErrorInterceptor get errorInterceptor => const ErrorInterceptor();

  // ── Dio (with interceptors attached) ─────────────────────────
  // Order matters: auth runs first so 401s get a refresh attempt before the
  // error interceptor maps them to Failure.unauthorized.
  @lazySingleton
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
