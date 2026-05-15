import 'package:bloc/bloc.dart';

import '../../domain/app_init_probe.dart';
import 'app_init_event.dart';
import 'app_init_state.dart';

/// Splash-time bootstrap bloc (Screen 0.1).
///
/// Responsibility is narrow: delegate to [AppInitProbe], translate the
/// outcome into one of three terminal states, and let the page's
/// `BlocListener` do the navigation. Bloc itself never touches
/// `BuildContext`.
///
/// **[minSplashDuration]** is the floor on the time the splash stays
/// visible — the probe finishing in 80ms shouldn't flash the splash
/// off-screen; we wait for the animation to read.
class AppInitBloc extends Bloc<AppInitEvent, AppInitState> {
  AppInitBloc({
    required AppInitProbe probe,
    Duration minSplashDuration = const Duration(milliseconds: 1000),
  })  : _probe = probe,
        _minSplash = minSplashDuration,
        super(const AppInitLoading()) {
    on<AppStarted>(_onStarted);
  }

  final AppInitProbe _probe;
  final Duration _minSplash;

  Future<void> _onStarted(
    AppStarted event,
    Emitter<AppInitState> emit,
  ) async {
    emit(const AppInitLoading());
    try {
      // Run the probe and the minimum-splash timer in parallel so the
      // splash stays at least `minSplashDuration` even if the probe
      // returns instantly.
      final results = await Future.wait<Object?>([
        _probe.run(),
        Future<void>.delayed(_minSplash),
      ]);
      final outcome = results[0] as AppInitOutcome;
      switch (outcome) {
        case AppInitOutcome.unauthenticated:
          emit(const AppInitUnauthenticated());
        case AppInitOutcome.authenticated:
          emit(const AppInitAuthenticated());
        case AppInitOutcome.locked:
          emit(const AppInitLocked());
      }
    } catch (e) {
      emit(AppInitFailure(e.toString()));
    }
  }
}
