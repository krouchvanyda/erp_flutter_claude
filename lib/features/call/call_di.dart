import '../../core/di/service_locator.dart';
import '../../core/network/app_service.dart';
import '../../core/network/token_storage.dart';
import '../../core/realtime/realtime_service.dart';
import '../../core/router/auth_session.dart';
import 'repository/call_media.dart';
import 'repository/call_repository.dart';
import 'viewmodel/call/call_view_model_bloc.dart';

/// Registers the call feature. Called from `configureAppDependencies()`.
///
/// [loadPeer] comes from `app/`: it turns a call into a name + photo using
/// the chat feature (which the call feature must not import).
void registerCallModule(
  ServiceLocator getIt, {
  required CallPeerLoader loadPeer,
}) {
  getIt
    ..registerLazySingleton<CallRepository>(
      () => CallRepository(
        appService: getIt<AppService>(),
        tokenStorage: getIt<TokenStorage>(),
        realtime: getIt<RealtimeService>(),
      ),
    )
    // The sound + picture (Stream Video), with tokens from OUR server.
    ..registerLazySingleton<CallMedia>(
      () => CallMedia(
        loadToken: () async => (await getIt<CallRepository>().streamToken())
            .fold((_) => null, (token) => token),
      ),
    )
    // ONE bloc for the whole app: a call outlives every page.
    ..registerLazySingleton<CallViewModelBloc>(
      () => CallViewModelBloc(
        getIt<CallRepository>(),
        media: getIt<CallMedia>(),
        loadPeer: loadPeer,
        session: getIt<AuthSession>(),
      ),
    );
}
