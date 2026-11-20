import '../../core/di/service_locator.dart';
import '../../core/network/app_service.dart';
import '../../core/network/token_storage.dart';
import '../../core/realtime/realtime_service.dart';
import '../../core/router/auth_session.dart';
import 'repository/chat_repository.dart';
import 'repository/presence_store.dart';
import 'viewmodel/inbox/inbox_view_model_bloc.dart';

/// Registers the chat feature. Called from `configureAppDependencies()`.
void registerChatModule(ServiceLocator getIt) {
  getIt
    // one repository for the whole app
    ..registerLazySingleton<ChatRepository>(
      () => ChatRepository(
        appService: getIt<AppService>(),
        tokenStorage: getIt<TokenStorage>(),
        realtime: getIt<RealtimeService>(),
      ),
    )
    // who is online — ONE store for the app (5.6)
    ..registerLazySingleton<PresenceStore>(
      () =>
          PresenceStore(getIt<ChatRepository>(), session: getIt<AuthSession>()),
    )
    // a FRESH bloc each time the inbox opens
    ..registerFactory<InboxViewModelBloc>(
      () => InboxViewModelBloc(
        getIt<ChatRepository>(),
        presence: getIt<PresenceStore>(),
      ),
    );
}
