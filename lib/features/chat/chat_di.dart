import '../../core/di/service_locator.dart';
import '../../core/network/app_service.dart';
import '../../core/network/token_storage.dart';
import '../../core/realtime/realtime_service.dart';
import 'repository/chat_repository.dart';
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
    // a FRESH bloc each time the inbox opens
    ..registerFactory<InboxViewModelBloc>(
      () => InboxViewModelBloc(getIt<ChatRepository>()),
    );
}
