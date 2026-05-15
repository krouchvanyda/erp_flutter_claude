/// Inputs to [AppInitBloc] (Screen 0.1).
///
/// Single event today — the splash screen has only one job. Sealed so
/// new boot-time signals (e.g. a "retry probe" after a transient drift
/// migration failure) become a compile-error switch, not a silent miss.
sealed class AppInitEvent {
  const AppInitEvent();
}

class AppStarted extends AppInitEvent {
  const AppStarted();
}
