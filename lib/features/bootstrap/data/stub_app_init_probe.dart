import '../domain/app_init_probe.dart';

/// Demo probe that always reports "no token" so the splash routes the
/// user to the login screen on cold start.
///
/// Real implementation lands in Slice 1.1.x — it will read the access
/// token from `flutter_secure_storage`, hydrate the cached user from
/// drift, check the app-lock policy from [AppLockSettingsRepository],
/// and pick the right outcome.
class StubAppInitProbe implements AppInitProbe {
  const StubAppInitProbe({this.outcome = AppInitOutcome.unauthenticated});

  final AppInitOutcome outcome;

  @override
  Future<AppInitOutcome> run() async => outcome;
}
