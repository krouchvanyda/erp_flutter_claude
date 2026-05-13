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
import '../push/local_push_simulator.dart';
import '../push/push_message_router.dart';
import '../push/push_notification_service.dart';
import '../push/push_token_storage.dart';
import '../realtime/realtime_service.dart';
import '../realtime/web_socket_realtime_channel.dart';
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
import '../../features/auth/data/datasources/biometric_service.dart';
import '../../features/auth/data/datasources/biometric_settings_dao.dart';
import '../../features/auth/data/datasources/cached_user_dao.dart';
import '../../features/auth/data/datasources/dio_token_refresher.dart';
import '../../features/auth/data/datasources/local_auth_biometric_service.dart';
import '../../features/auth/data/datasources/flutter_secure_storage_secret_store.dart';
import '../../features/auth/data/datasources/secret_store.dart';
import '../../features/auth/data/datasources/oauth_flow_session.dart';
import '../../features/auth/data/datasources/oauth_token_data_source.dart';
import '../../features/auth/data/datasources/pkce_generator.dart';
import '../../features/auth/data/datasources/secure_token_storage.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/data/repositories/permissions_repository_impl.dart';
import '../../features/auth/data/repositories/stub_otp_repository.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/repositories/otp_repository.dart';
import '../../features/auth/domain/repositories/permissions_repository.dart';
import '../../features/auth/domain/usecases/check_permission.dart';
import '../../features/auth/domain/usecases/exchange_authorization_code.dart';
import '../../features/auth/domain/usecases/sign_out.dart';
import '../../features/auth/domain/usecases/unlock_with_biometric.dart';
import '../../features/auth/domain/usecases/verify_otp.dart';
import '../../features/auth/presentation/bloc/otp_bloc.dart';
import '../../features/finance/data/datasources/accounts_dao.dart';
import '../../features/finance/data/datasources/invoices_dao.dart';
import '../../features/inventory/data/datasources/items_dao.dart';
import '../../features/finance/data/repositories/drift_accounts_repository.dart';
import '../../features/finance/data/repositories/drift_invoices_repository.dart';
import '../../features/finance/data/repositories/drift_transactions_repository.dart';
import '../../features/finance/data/repositories/stub_journal_entries_repository.dart';
import '../../features/finance/data/repositories/stub_trial_balance_repository.dart';
import '../../features/finance/domain/repositories/accounts_repository.dart';
import '../../features/finance/domain/repositories/invoices_repository.dart';
import '../../features/finance/domain/repositories/journal_entries_repository.dart';
import '../../features/finance/domain/repositories/transactions_repository.dart';
import '../../features/finance/domain/repositories/trial_balance_repository.dart';
import '../../features/auth/domain/permission_gate.dart';
import '../../features/finance/domain/usecases/approve_invoice.dart';
import '../../features/finance/domain/usecases/reject_invoice.dart';
import '../../features/finance/domain/usecases/reopen_invoice.dart';
import '../../features/finance/domain/usecases/submit_invoice_for_approval.dart';
import '../../features/finance/presentation/bloc/invoice_action_bloc.dart';
import '../router/permissions_snapshot.dart';
import '../../features/finance/presentation/bloc/account_detail_bloc.dart';
import '../../features/finance/presentation/bloc/account_tree_bloc.dart';
import '../../features/finance/presentation/bloc/invoice_list_bloc.dart';
import '../../features/notifications/data/datasources/notifications_dao.dart';
import '../../features/notifications/data/repositories/notifications_repository_impl.dart';
import '../../features/notifications/domain/repositories/notifications_repository.dart';
import '../../features/notifications/presentation/bloc/notification_inbox_bloc.dart';
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

  @lazySingleton
  BiometricSettingsDao biometricSettingsDao(AppDatabase db) =>
      db.biometricSettingsDao;

  @lazySingleton
  NotificationsDao notificationsDao(AppDatabase db) => db.notificationsDao;

  @lazySingleton
  InvoicesDao invoicesDao(AppDatabase db) => db.invoicesDao;

  @lazySingleton
  ItemsDao itemsDao(AppDatabase db) => db.itemsDao;

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
  @lazySingleton
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

  // ── Biometric unlock (Slice 1.2.3) ───────────────────────────
  /// `local_auth` wrapper. The only file that imports `package:local_auth`
  /// — feature code goes through the `BiometricService` interface so
  /// tests can fake it without dragging Flutter in.
  @lazySingleton
  BiometricService get biometricService => LocalAuthBiometricService();

  // ── Finance (Slice 3.1.1 / 3.1.3) ────────────────────────────
  /// Drift DAO for the accounts + transactions cache.
  @lazySingleton
  AccountsDao accountsDao(AppDatabase db) => db.accountsDao;

  /// Drift-backed repo (Slice 3.1.3) — replaces the in-memory stub.
  /// First call lazily seeds the cache from `FinanceSeed.accounts`.
  @lazySingleton
  DriftAccountsRepository driftAccountsRepository(AccountsDao dao) =>
      DriftAccountsRepository(dao: dao);

  @lazySingleton
  AccountsRepository accountsRepository(DriftAccountsRepository impl) => impl;

  /// `@injectable` (factory) so each `ChartOfAccountsPage` mount gets
  /// a fresh bloc — ties the watch subscription's lifetime to the
  /// page's lifetime.
  @injectable
  AccountTreeBloc accountTreeBloc(
    AccountsRepository repo,
    AppLogger logger,
  ) =>
      AccountTreeBloc(
        repository: repo,
        logger: logger.child('accounts'),
      );

  // ── Transactions (Slice 3.1.2 / 3.1.3) ───────────────────────
  /// Drift-backed transactions repo. Bootstrap runs the accounts
  /// bootstrap first because the FK requires accounts to exist.
  @LazySingleton(as: TransactionsRepository)
  DriftTransactionsRepository driftTransactionsRepository(
    AccountsDao dao,
    DriftAccountsRepository accountsRepo,
  ) =>
      DriftTransactionsRepository(
        dao: dao,
        // Force the accounts seed by reading once — cheap getAll() that
        // triggers the lazy bootstrap on the accounts repo.
        bootstrapAccounts: () async {
          await accountsRepo.getAll();
        },
      );

  // ── Invoices (Phase 3.2) ─────────────────────────────────────
  /// Drift-backed [InvoicesRepository] (Slice 3.2.4) — persists the
  /// header + lines + audit columns through `cached_invoices`. Seeds
  /// on first call when the table is empty.
  @LazySingleton(as: InvoicesRepository)
  DriftInvoicesRepository driftInvoicesRepository(
    InvoicesDao dao,
    SyncQueueDao syncQueueDao,
  ) =>
      DriftInvoicesRepository(dao: dao, syncQueue: syncQueueDao);

  @injectable
  InvoiceListBloc invoiceListBloc(InvoicesRepository repo) =>
      InvoiceListBloc(repository: repo);

  // ── Slice 3.2.4 approve/reject workflow ─────────────────────
  /// Binds the abstract [PermissionGate] (consumed by domain UseCases
  /// + the action bloc) to the concrete in-memory snapshot the router
  /// listens to. Keeps domain code Flutter-free per the layering rule.
  @lazySingleton
  PermissionGate permissionGate(PermissionsSnapshot snapshot) => snapshot;

  @lazySingleton
  ApproveInvoiceUseCase approveInvoiceUseCase(
    InvoicesRepository repository,
    PermissionGate permissions,
  ) =>
      ApproveInvoiceUseCase(
        repository: repository,
        permissions: permissions,
      );

  @lazySingleton
  RejectInvoiceUseCase rejectInvoiceUseCase(
    InvoicesRepository repository,
    PermissionGate permissions,
  ) =>
      RejectInvoiceUseCase(
        repository: repository,
        permissions: permissions,
      );

  @lazySingleton
  SubmitInvoiceForApprovalUseCase submitInvoiceForApprovalUseCase(
    InvoicesRepository repository,
  ) =>
      SubmitInvoiceForApprovalUseCase(repository: repository);

  @lazySingleton
  ReopenInvoiceUseCase reopenInvoiceUseCase(
    InvoicesRepository repository,
  ) =>
      ReopenInvoiceUseCase(repository: repository);

  /// Factory — each detail page mount gets a fresh action bloc so the
  /// `Loading → Success/Failure` state isn't leaked across invoices.
  @injectable
  InvoiceActionBloc invoiceActionBloc(
    ApproveInvoiceUseCase approveInvoice,
    RejectInvoiceUseCase rejectInvoice,
    SubmitInvoiceForApprovalUseCase submitInvoice,
    ReopenInvoiceUseCase reopenInvoice,
    PermissionGate permissions,
  ) =>
      InvoiceActionBloc(
        approveInvoice: approveInvoice,
        rejectInvoice: rejectInvoice,
        submitInvoice: submitInvoice,
        reopenInvoice: reopenInvoice,
        permissions: permissions,
      );

  // ── General Ledger (Phase 3.3) ───────────────────────────────
  @LazySingleton(as: JournalEntriesRepository)
  StubJournalEntriesRepository stubJournalEntriesRepository() =>
      StubJournalEntriesRepository();

  @LazySingleton(as: TrialBalanceRepository)
  StubTrialBalanceRepository stubTrialBalanceRepository(
    AccountsRepository accounts,
  ) =>
      StubTrialBalanceRepository(accounts: accounts);

  /// `@injectable` (factory) — same rationale as the tree bloc: each
  /// `AccountDetailPage` mount gets a fresh bloc + watch subscriptions.
  @injectable
  AccountDetailBloc accountDetailBloc(
    AccountsRepository accountsRepository,
    TransactionsRepository transactionsRepository,
  ) =>
      AccountDetailBloc(
        accountsRepository: accountsRepository,
        transactionsRepository: transactionsRepository,
      );

  // ── Notifications (Slice 2.3.1) ──────────────────────────────
  @lazySingleton
  NotificationsRepository notificationsRepository(NotificationsDao dao) =>
      NotificationsRepositoryImpl(dao: dao);

  /// `@injectable` (factory) so each `NotificationInboxPage` mount gets
  /// a fresh bloc — ties the watch subscription's lifetime to the
  /// page's lifetime.
  @injectable
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
  @LazySingleton(as: PushNotificationService)
  LocalPushSimulator localPushSimulator() => LocalPushSimulator();

  @lazySingleton
  PushTokenStorage pushTokenStorage(SecretStore secrets) =>
      SecretStorePushTokenStorage(secrets: secrets);

  @lazySingleton
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

  // ── RBAC (Slice 1.3.1) ───────────────────────────────────────
  @lazySingleton
  PermissionsRepository permissionsRepository(CachedUserDao cachedUserDao) =>
      PermissionsRepositoryImpl(cachedUserDao: cachedUserDao);

  @lazySingleton
  CheckPermissionUseCase checkPermissionUseCase(
    PermissionsRepository repository,
  ) =>
      CheckPermissionUseCase(repository: repository);

  @lazySingleton
  UnlockWithBiometricUseCase unlockWithBiometricUseCase(
    CachedUserDao cachedUserDao,
    BiometricSettingsDao settingsDao,
    BiometricService biometricService,
  ) =>
      UnlockWithBiometricUseCase(
        cachedUserDao: cachedUserDao,
        settingsDao: settingsDao,
        biometricService: biometricService,
      );

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
