import 'package:flutter_bloc/flutter_bloc.dart';

import 'app_env.dart';
import 'injection.dart';
import '../network/token_storage.dart';
import '../push/push_message_router.dart';
import '../push/push_notification_service.dart';
import '../realtime/realtime_service.dart';
import '../router/app_router.dart';
import '../router/auth_session.dart';
import '../router/permissions_snapshot.dart';
import '../../features/auth/repositories/auth_repository.dart';
import '../../features/auth/repositories/cached_user_dao.dart';
import '../../features/auth/repositories/demo_sign_in.dart';
import '../../features/auth/repositories/otp_repository.dart';
import '../../features/chat/repositories/call_log_repository.dart';
import '../../features/chat/repositories/call_signaling_service.dart';
import '../../features/chat/repositories/chat_settings.dart';
import '../../features/chat/repositories/chat_transport.dart';
import '../../features/chat/repositories/chats_remote_data_source.dart';
import '../../features/chat/repositories/conversations_repository.dart';
import '../../features/chat/repositories/messages_repository.dart';
import '../../features/chat/repositories/presence_repository.dart';
import '../../features/chat/repositories/stream_call_engine.dart';
import '../../features/notifications/repositories/notifications_repository.dart';
import '../../features/settings/repositories/admin_repositories.dart';
import '../../features/settings/repositories/my_profile_repository.dart';
import '../../features/settings/repositories/preferences_repository.dart';
import '../../features/settings/repositories/roles_remote_data_source.dart';
import '../../features/settings/repositories/security_repositories.dart';
import '../../features/settings/repositories/users_remote_data_source.dart';

/// Every dependency the **widget tree** reads, exposed via `RepositoryProvider`
/// so views/widgets resolve them with `context.read<T>()` instead of `getIt`.
///
/// `getIt` is intentionally NOT removed from the app — it stays as the single
/// construction source here (`create: (_) => getIt<T>()`, lazy) and remains
/// the only option in context-free code (the FCM background isolate / killed-
/// app call handler, where there is no `BuildContext`). This list is the
/// bridge: getIt builds, the tree distributes.
///
/// Mounted once at the app root (see `ErpMobileApp.build`).
List<RepositoryProvider> buildUiRepositoryProviders() => [
      // ── Core ────────────────────────────────────────────────
      RepositoryProvider<AppEnv>(create: (_) => getIt<AppEnv>()),
      RepositoryProvider<AppRouter>(create: (_) => getIt<AppRouter>()),
      RepositoryProvider<AuthSession>(create: (_) => getIt<AuthSession>()),
      RepositoryProvider<PermissionsSnapshot>(
          create: (_) => getIt<PermissionsSnapshot>()),
      RepositoryProvider<TokenStorage>(create: (_) => getIt<TokenStorage>()),
      RepositoryProvider<RealtimeService>(
          create: (_) => getIt<RealtimeService>()),
      RepositoryProvider<PushMessageRouter>(
          create: (_) => getIt<PushMessageRouter>()),
      RepositoryProvider<PushNotificationService>(
          create: (_) => getIt<PushNotificationService>()),
      // ── Auth ────────────────────────────────────────────────
      RepositoryProvider<AuthRepository>(
          create: (_) => getIt<AuthRepository>()),
      RepositoryProvider<OtpRepository>(create: (_) => getIt<OtpRepository>()),
      RepositoryProvider<CachedUserDao>(create: (_) => getIt<CachedUserDao>()),
      RepositoryProvider<DemoSignInService>(
          create: (_) => getIt<DemoSignInService>()),
      // ── Notifications ───────────────────────────────────────
      RepositoryProvider<NotificationsRepository>(
          create: (_) => getIt<NotificationsRepository>()),
      // ── Settings ────────────────────────────────────────────
      RepositoryProvider<PreferencesRepository>(
          create: (_) => getIt<PreferencesRepository>()),
      RepositoryProvider<MyProfileRepository>(
          create: (_) => getIt<MyProfileRepository>()),
      RepositoryProvider<RolesRepository>(
          create: (_) => getIt<RolesRepository>()),
      RepositoryProvider<ManagedUsersRepository>(
          create: (_) => getIt<ManagedUsersRepository>()),
      RepositoryProvider<ApiEnvironmentsRepository>(
          create: (_) => getIt<ApiEnvironmentsRepository>()),
      RepositoryProvider<DeviceSessionsRepository>(
          create: (_) => getIt<DeviceSessionsRepository>()),
      RepositoryProvider<AuditLogRepository>(
          create: (_) => getIt<AuditLogRepository>()),
      RepositoryProvider<AppLockSettingsRepository>(
          create: (_) => getIt<AppLockSettingsRepository>()),
      RepositoryProvider<InMemoryPinSecretStore>(
          create: (_) => getIt<InMemoryPinSecretStore>()),
      RepositoryProvider<UsersRemoteDataSource>(
          create: (_) => getIt<UsersRemoteDataSource>()),
      RepositoryProvider<RolesRemoteDataSource>(
          create: (_) => getIt<RolesRemoteDataSource>()),
      // ── Chat ────────────────────────────────────────────────
      RepositoryProvider<ChatSettings>(create: (_) => getIt<ChatSettings>()),
      RepositoryProvider<ConversationsRepository>(
          create: (_) => getIt<ConversationsRepository>()),
      RepositoryProvider<MessagesRepository>(
          create: (_) => getIt<MessagesRepository>()),
      RepositoryProvider<PresenceRepository>(
          create: (_) => getIt<PresenceRepository>()),
      RepositoryProvider<CallLogRepository>(
          create: (_) => getIt<CallLogRepository>()),
      RepositoryProvider<CallSignalingService>(
          create: (_) => getIt<CallSignalingService>()),
      RepositoryProvider<StreamCallEngine>(
          create: (_) => getIt<StreamCallEngine>()),
      RepositoryProvider<ChatTransport>(create: (_) => getIt<ChatTransport>()),
      RepositoryProvider<ChatsRemoteDataSource>(
          create: (_) => getIt<ChatsRemoteDataSource>()),
    ];
