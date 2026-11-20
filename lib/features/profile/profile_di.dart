import '../../core/di/service_locator.dart';
import '../../core/network/app_service.dart';
import '../../core/storage/user_cache.dart';
import 'repository/profile_repository.dart';
import 'viewmodel/profile_view_model_bloc.dart';

/// Registers the profile feature. Called from `configureAppDependencies()`.
void registerProfileModule(ServiceLocator getIt) {
  getIt
    // one repository for the whole app
    ..registerLazySingleton<ProfileRepository>(
      () => ProfileRepository(
        appService: getIt<AppService>(),
        userCache: getIt<UserCache>(),
      ),
    )
    // a FRESH bloc each time the profile page opens
    ..registerFactory<ProfileViewModelBloc>(
      () => ProfileViewModelBloc(getIt<ProfileRepository>()),
    );
}
