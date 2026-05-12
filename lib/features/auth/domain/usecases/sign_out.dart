import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/network/session_signal.dart';
import '../repositories/auth_repository.dart';

/// Sign-out orchestrator — one of the rare "fan-out" use cases that
/// touches multiple cross-cutting collaborators.
///
/// Composes:
/// 1. [AuthRepository.signOut] — revoke + wipe (tokens, cached profile,
///    permissions).
/// 2. [SessionSignal.invalidate] — notifies the router (via the bridge
///    registered in `register_module.dart`) to bounce to `/login`. Uses
///    the Flutter-free `SessionSignal` interface rather than the
///    Flutter-bearing `AuthSession` so the use case itself stays in
///    pure-Dart territory.
/// 3. [AnalyticsService.reset] — clears the identified user so the next
///    session starts anonymous and previous traits aren't carried over.
///
/// The repository step **must** run first so the data-layer state is
/// clean before the router re-renders, otherwise the splash probe
/// (Slice 1.3.3-equivalent on the next boot) could briefly see a stale
/// cached user.
class SignOutUseCase {
  const SignOutUseCase({
    required AuthRepository authRepository,
    required SessionSignal sessionSignal,
    required AnalyticsService analytics,
  })  : _repository = authRepository,
        _session = sessionSignal,
        _analytics = analytics;

  final AuthRepository _repository;
  final SessionSignal _session;
  final AnalyticsService _analytics;

  Future<void> call() async {
    await _repository.signOut();
    await _session.invalidate();
    await _analytics.reset();
  }
}
