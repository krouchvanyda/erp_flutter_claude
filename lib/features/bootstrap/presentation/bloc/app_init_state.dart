/// Splash-time machine states (Screen 0.1).
///
/// `AppInitLoading` → one of `AppInitAuthenticated` /
/// `AppInitUnauthenticated` / `AppInitLocked`. Failure carries a
/// message so the splash can surface a "tap to retry" affordance
/// instead of stranding the user on the spinner forever.
sealed class AppInitState {
  const AppInitState();
}

class AppInitLoading extends AppInitState {
  const AppInitLoading();
}

class AppInitAuthenticated extends AppInitState {
  const AppInitAuthenticated();
}

class AppInitUnauthenticated extends AppInitState {
  const AppInitUnauthenticated();
}

class AppInitLocked extends AppInitState {
  const AppInitLocked();
}

class AppInitFailure extends AppInitState {
  const AppInitFailure(this.message);
  final String message;
}
