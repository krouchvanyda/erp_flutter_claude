import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';

import '../analytics/analytics_service.dart';
import '../analytics/noop_analytics_service.dart';
import '../error/crash_reporter.dart';
import '../error/logging_crash_reporter.dart';
import '../i18n/in_memory_locale_service.dart';
import '../i18n/locale_service.dart';
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
import '../router/app_router.dart';
import '../router/auth_session.dart';
import '../router/permissions_snapshot.dart';
import '../utils/logger/app_logger.dart';
import '../utils/logger/console_logger.dart';

import '../../features/auth/data/datasources/auth_remote_data_source.dart';
import '../../features/auth/data/datasources/biometric_service.dart';
import '../../features/auth/data/datasources/biometric_settings_dao.dart';
import '../../features/auth/data/datasources/cached_user_dao.dart';
import '../../features/auth/data/datasources/dio_token_refresher.dart';
import '../../features/auth/data/datasources/flutter_secure_storage_secret_store.dart';
import '../../features/auth/data/datasources/local_auth_biometric_service.dart';
import '../../features/auth/data/datasources/oauth_flow_session.dart';
import '../../features/auth/data/datasources/oauth_token_data_source.dart';
import '../../features/auth/data/datasources/pkce_generator.dart';
import '../../features/auth/data/datasources/secret_store.dart';
import '../../features/auth/data/datasources/secure_token_storage.dart';
import '../../features/auth/data/demo_sign_in.dart';
import '../../features/auth/data/repositories/auth_repository.dart';
import '../../features/auth/data/repositories/otp_repository.dart';
import '../../features/auth/data/repositories/permissions_repository.dart';

import '../../features/notifications/data/datasources/notifications_dao.dart';
import '../../features/notifications/data/repositories/notifications_repository_impl.dart';
import '../../features/notifications/domain/repositories/notifications_repository.dart';

import '../../features/employees/data/datasources/employees_remote_data_source.dart';
import '../../features/settings/data/datasources/roles_remote_data_source.dart';
import '../../features/settings/data/datasources/users_remote_data_source.dart';
import '../../features/settings/data/repositories/admin_repositories.dart';
import '../../features/settings/data/repositories/my_profile_repository.dart';
import '../../features/settings/data/repositories/preferences_repository.dart';
import '../../features/settings/data/repositories/security_repositories.dart';

import '../../features/chat/data/call_signaling_service.dart';
import '../../features/chat/data/chat_settings.dart';
import '../../features/chat/data/chat_transport.dart';
import '../../features/chat/data/chats_remote_data_source.dart';
import '../../features/chat/data/repositories/call_log_repository.dart';
import '../../features/chat/data/repositories/conversations_repository.dart';
import '../../features/chat/data/repositories/messages_repository.dart';
import '../../features/chat/data/repositories/presence_repository.dart';
import '../../features/chat/data/stream_call_engine.dart';

import 'app_env.dart';

/// Hand-written composition root — the single place every long-lived
/// service / repository / data source is constructed.
///
/// **Replaces** `get_it` + `injectable` (and the generated
/// `injection.config.dart` + the four `register*Module` helpers). There
/// is no service locator and no codegen anymore: dependencies are plain
/// fields wired together in dependency order in [AppDependencies._build].
///
/// Two access paths, by design (see the DI decision recorded for this
/// session):
///   * **Widgets / BLoCs** read repositories through the normal
///     constructor / `BlocProvider` / `RepositoryProvider` flow.
///   * **Non-widget callers** that have no `BuildContext` — `main()`,
///     the FCM background isolate, the native call handlers
///     (`CallkitEventHandler`, `CallNotificationRouter`),
///     `IncomingCallOverlay`, and the splash auto-login — reach the same
///     singletons through [AppDependencies.I]. This is the ONE retained
///     global, and it is a concrete typed object, not a reflective
///     registry.
///
/// Call [AppDependencies.bootstrap] exactly once, before `runApp`.
class AppDependencies {
  AppDependencies._();

  /// The active instance. Set by [bootstrap]; throws if read before.
  static AppDependencies get I {
    final inst = _instance;
    if (inst == null) {
      throw StateError(
        'AppDependencies.I read before bootstrap(). Call '
        'AppDependencies.bootstrap() in main() before runApp().',
      );
    }
    return inst;
  }

  /// Nullable accessor for the few call sites that may run before
  /// bootstrap (notification isolate cold-start) and want to skip rather
  /// than throw. Mirrors the old `GetIt.I.isRegistered<T>()` guard.
  static AppDependencies? get maybeI => _instance;

  static AppDependencies? _instance;

  /// Builds the whole graph once and publishes it on [I].
  static AppDependencies bootstrap() {
    final deps = AppDependencies._().._build();
    _instance = deps;
    return deps;
  }

  // ── Configuration / cross-cutting ───────────────────────────────
  late final AppEnv appEnv;
  late final AppLogger appLogger;
  late final CrashReporter crashReporter;
  late final AnalyticsService analyticsService;
  late final LocaleService localeService;

  // ── Networking ──────────────────────────────────────────────────
  late final Connectivity connectivity;
  late final ConnectivityChecker connectivityChecker;
  late final SecretStore secretStore;
  late final TokenStorage tokenStorage;
  late final TokenRefresher tokenRefresher;
  late final SessionSignal sessionSignal;
  late final AuthInterceptor authInterceptor;
  late final ErrorInterceptor errorInterceptor;
  late final Dio dio;

  // ── Realtime ────────────────────────────────────────────────────
  late final RealtimeService realtimeService;

  // ── Auth datasources / OAuth ────────────────────────────────────
  late final AuthRemoteDataSource authRemoteDataSource;
  late final BiometricService biometricService;
  late final PkceGenerator pkceGenerator;
  late final OAuthFlowSession oauthFlowSession;
  late final OAuthTokenDataSource oauthTokenDataSource;

  // ── In-memory data stores (local persistence removed) ──────────
  late final CachedUserDao cachedUserDao;
  late final BiometricSettingsDao biometricSettingsDao;
  late final NotificationsDao notificationsDao;

  // ── Auth / session / RBAC ───────────────────────────────────────
  late final AuthSession authSession;
  late final DemoSignInService demoSignInService;
  late final PermissionsRepository permissionsRepository;
  late final PermissionsSnapshot permissionsSnapshot;
  late final AuthRepository authRepository;
  late final OtpRepository otpRepository;

  // ── Router ──────────────────────────────────────────────────────
  late final AppRouter appRouter;

  // ── Notifications ───────────────────────────────────────────────
  late final NotificationsRepository notificationsRepository;

  // ── Push / devices ──────────────────────────────────────────────
  late final PushNotificationService pushNotificationService;
  late final PushTokenStorage pushTokenStorage;
  late final DeviceIdStorage deviceIdStorage;
  late final DevicesRemoteDataSource devicesRemoteDataSource;
  late final DeviceRegistrar deviceRegistrar;
  late final PushMessageRouter pushMessageRouter;

  // ── Settings / admin ────────────────────────────────────────────
  late final PreferencesRepository preferencesRepository;
  late final EmployeesRemoteDataSource employeesRemoteDataSource;
  late final MyProfileRepository myProfileRepository;
  late final RolesRemoteDataSource rolesRemoteDataSource;
  late final UsersRemoteDataSource usersRemoteDataSource;
  late final ManagedUsersRepository managedUsersRepository;
  late final RolesRepository rolesRepository;
  late final ApiEnvironmentsRepository apiEnvironmentsRepository;
  late final DeviceSessionsRepository deviceSessionsRepository;
  late final AuditLogRepository auditLogRepository;
  late final AppLockSettingsRepository appLockSettingsRepository;
  late final InMemoryPinSecretStore inMemoryPinSecretStore;

  // ── Chat (Module 10) ────────────────────────────────────────────
  late final ConversationsRepository conversationsRepository;
  late final MessagesRepository messagesRepository;
  late final CallLogRepository callLogRepository;
  late final PresenceRepository presenceRepository;
  late final ChatSettings chatSettings;
  late final ChatsRemoteDataSource chatsRemoteDataSource;
  late final ChatTransport chatTransport;
  late final StreamCallEngine streamCallEngine;
  late final CallSignalingService callSignalingService;

  /// Constructs everything in dependency order. Each assignment may only
  /// reference fields assigned above it.
  void _build() {
    // ── Configuration / cross-cutting ──────────────────────────────
    appEnv = AppEnv.defaults();
    appLogger = ConsoleLogger();
    crashReporter = LoggingCrashReporter(appLogger);
    analyticsService = const NoopAnalyticsService();
    localeService = InMemoryLocaleService();

    // ── Connectivity ───────────────────────────────────────────────
    connectivity = Connectivity();
    connectivityChecker = ConnectivityPlusChecker(connectivity);

    // ── Auth-token plumbing ────────────────────────────────────────
    // Tokens (and any future auth secret) live ONLY in the platform
    // secret store — never in any database / prefs.
    secretStore = FlutterSecureStorageSecretStore();
    tokenStorage = SecureTokenStorage(secretStore);

    // ── In-memory data stores ──────────────────────────────────────
    cachedUserDao = CachedUserDao();
    biometricSettingsDao = BiometricSettingsDao();
    notificationsDao = NotificationsDao();

    // ── Dedicated-Dio datasources (no shared interceptors) ─────────
    // Token refresher + auth/oauth datasources each build their own Dio
    // to break the Dio → AuthInterceptor → TokenRefresher → Dio cycle
    // and keep refresh/revoke calls out of the interceptor chain.
    tokenRefresher = DioTokenRefresher(
      dio: buildDio(appEnv),
      cachedUserDao: cachedUserDao,
      logger: appLogger,
      crashReporter: crashReporter,
    );
    authRemoteDataSource = DioAuthRemoteDataSource(dio: buildDio(appEnv));
    oauthTokenDataSource = DioOAuthTokenDataSource(dio: buildDio(appEnv));

    // ── OAuth / biometric ──────────────────────────────────────────
    biometricService = LocalAuthBiometricService();
    pkceGenerator = PkceGenerator();
    oauthFlowSession = OAuthFlowSession();

    // ── Realtime ───────────────────────────────────────────────────
    realtimeService = RealtimeService(
      url: Uri.parse(appEnv.realtimeUrl),
      channelFactory: WebSocketRealtimeChannel.connect,
      logger: appLogger.child('realtime'),
    );

    // ── Session / RBAC / router ────────────────────────────────────
    authSession = StubAuthSession();
    demoSignInService = DemoSignInService(cachedUserDao);
    permissionsRepository = PermissionsRepository(cachedUserDao: cachedUserDao);
    permissionsSnapshot = PermissionsSnapshot(
      cachedUserDao: cachedUserDao,
      permissionsRepository: permissionsRepository,
    );
    appRouter = AppRouter(authSession, permissionsSnapshot);

    // ── Notifications ──────────────────────────────────────────────
    notificationsRepository = NotificationsRepositoryImpl(dao: notificationsDao);

    // ── Push / devices ─────────────────────────────────────────────
    pushNotificationService = LocalPushSimulator();
    pushTokenStorage = SecretStorePushTokenStorage(secrets: secretStore);
    deviceIdStorage = SecretStoreDeviceIdStorage(secrets: secretStore);
    pushMessageRouter = PushMessageRouter(
      service: pushNotificationService,
      notifications: notificationsRepository,
      tokenStorage: pushTokenStorage,
      logger: appLogger.child('push'),
    );

    // ── Network session signal + interceptors + shared Dio ─────────
    sessionSignal = _AuthSessionInvalidator(authSession);
    errorInterceptor = const ErrorInterceptor();
    authInterceptor = AuthInterceptor(
      tokenStorage: tokenStorage,
      tokenRefresher: tokenRefresher,
      sessionSignal: sessionSignal,
    );
    // Order matters: auth runs first so 401s get a refresh attempt
    // before the error interceptor maps them to Failure.unauthorized.
    final sharedDio = buildDio(appEnv);
    authInterceptor.dio = sharedDio;
    sharedDio.interceptors
      ..add(authInterceptor)
      ..add(errorInterceptor);
    dio = sharedDio;

    // ── Devices that ride the shared Dio ───────────────────────────
    devicesRemoteDataSource = DioDevicesRemoteDataSource(dio: dio);
    deviceRegistrar = DeviceRegistrar(
      remote: devicesRemoteDataSource,
      push: pushNotificationService,
      tokenStorage: pushTokenStorage,
      deviceIdStorage: deviceIdStorage,
      logger: appLogger.child('devices'),
    );

    // ── Auth orchestration ─────────────────────────────────────────
    authRepository = AuthRepository(
      tokenStorage: tokenStorage,
      remote: authRemoteDataSource,
      cachedUserDao: cachedUserDao,
      biometricSettingsDao: biometricSettingsDao,
      biometricService: biometricService,
      oauthFlowSession: oauthFlowSession,
      oauthTokenDataSource: oauthTokenDataSource,
      env: appEnv,
      sessionSignal: sessionSignal,
      analytics: analyticsService,
      logger: appLogger,
      crashReporter: crashReporter,
      deviceRegistrar: deviceRegistrar,
    );
    otpRepository = OtpRepository();

    // ── Settings / admin ───────────────────────────────────────────
    preferencesRepository = PreferencesRepository();
    employeesRemoteDataSource = DioEmployeesRemoteDataSource(dio: dio);
    myProfileRepository = MyProfileRepository(
      employees: employeesRemoteDataSource,
      tokens: tokenStorage,
    );
    rolesRemoteDataSource = DioRolesRemoteDataSource(dio: dio);
    usersRemoteDataSource = DioUsersRemoteDataSource(dio: dio);
    managedUsersRepository = ManagedUsersRepository();
    rolesRepository = RolesRepository();
    apiEnvironmentsRepository = ApiEnvironmentsRepository();
    deviceSessionsRepository = DeviceSessionsRepository();
    auditLogRepository = AuditLogRepository();
    appLockSettingsRepository = AppLockSettingsRepository();
    inMemoryPinSecretStore = InMemoryPinSecretStore();

    // ── Chat (Module 10) ───────────────────────────────────────────
    conversationsRepository = ConversationsRepository();
    messagesRepository = MessagesRepository();
    callLogRepository = CallLogRepository();
    chatsRemoteDataSource = DioChatsRemoteDataSource(dio: dio);
    presenceRepository = PresenceRepository(remote: chatsRemoteDataSource);
    chatSettings = ChatSettings.instance;
    chatTransport = ChatTransport(
      remote: chatsRemoteDataSource,
      tokens: tokenStorage,
    );
    streamCallEngine = StreamCallEngine(remote: chatsRemoteDataSource);
    callSignalingService = CallSignalingService(
      transport: chatTransport,
      settings: chatSettings,
      conversations: conversationsRepository,
      callLog: callLogRepository,
      remote: chatsRemoteDataSource,
      streamEngine: streamCallEngine,
    );
  }
}

/// Bridges the network-layer [SessionSignal] to the router-layer
/// [AuthSession] without leaking Flutter into `core/network/`.
class _AuthSessionInvalidator implements SessionSignal {
  _AuthSessionInvalidator(this._session);
  final AuthSession _session;

  @override
  Future<void> invalidate() => _session.signOut();
}
