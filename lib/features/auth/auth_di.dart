import '../../core/di/service_locator.dart';
import '../../core/network/app_service.dart';
import '../../core/network/token_storage.dart';
import '../../core/router/auth_session.dart';
import '../../core/storage/user_cache.dart';
import 'repository/auth_repository.dart';
import 'viewmodel/login_view_model_bloc.dart';
import 'viewmodel/splash_view_model_bloc.dart';

/// Registers the auth feature. Called from `configureDependencies()`.
void registerAuthModule(ServiceLocator getIt) {
  getIt
    // one repository for the whole app
    ..registerLazySingleton<AuthRepository>(
      () => AuthRepository(
        appService: getIt<AppService>(),
        tokenStorage: getIt<TokenStorage>(),
        userCache: getIt<UserCache>(),
        session: getIt<AuthSession>(),
      ),
    )
    // a FRESH bloc each time the login page opens
    ..registerFactory<LoginViewModelBloc>(
      () => LoginViewModelBloc(getIt<AuthRepository>()),
    )
    // a FRESH bloc each cold start (auto-login check)
    ..registerFactory<SplashViewModelBloc>(
      () => SplashViewModelBloc(getIt<AuthRepository>()),
    );
}
