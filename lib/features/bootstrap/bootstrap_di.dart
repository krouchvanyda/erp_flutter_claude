import 'package:get_it/get_it.dart';

import 'data/stub_app_init_probe.dart';
import 'domain/app_init_probe.dart';
import 'presentation/bloc/app_init_bloc.dart';

/// Manual DI registration for Module 0 (Bootstrap / Splash).
///
/// Same pattern as Modules 4–9. Registers the probe + the bloc factory
/// so the splash page can pull a fresh bloc per route activation.
void registerBootstrapModule(GetIt getIt) {
  if (!getIt.isRegistered<AppInitProbe>()) {
    getIt.registerLazySingleton<AppInitProbe>(StubAppInitProbe.new);
  }
  if (!getIt.isRegistered<AppInitBloc>()) {
    getIt.registerFactory<AppInitBloc>(
      () => AppInitBloc(probe: getIt()),
    );
  }
}
