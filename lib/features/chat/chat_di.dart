import '../../core/di/service_locator.dart';
import '../../core/network/app_service.dart';
import '../../core/network/token_storage.dart';
import 'repository/chat_repository.dart';
import 'viewmodel/inbox_view_model_bloc.dart';

/// Registers the chat feature. Called from `configureAppDependencies()`.
void registerChatModule(ServiceLocator getIt) {
  getIt
    // one repository for the whole app
    ..registerLazySingleton<ChatRepository>(
      () => ChatRepository(
        appService: getIt<AppService>(),
        tokenStorage: getIt<TokenStorage>(),
      ),
    )
    // a FRESH bloc each time the inbox opens
    ..registerFactory<InboxViewModelBloc>(
      () => InboxViewModelBloc(getIt<ChatRepository>()),
    );
}
