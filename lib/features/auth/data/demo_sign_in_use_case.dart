import '../../../core/error/failure.dart';
import '../../../core/router/auth_session.dart';
import '../domain/usecases/sign_in_with_password.dart';
import 'demo_sign_in.dart';

/// Demo wiring for [SignInWithPasswordUseCase].
///
/// Pretends to talk to the auth server: any non-empty email + password
/// "succeeds", anything else throws [UnauthorizedFailure]. On success
/// we seed the demo user into drift via [DemoSignInService] and flip
/// the [StubAuthSession] so the router redirect carries the user from
/// /login to /dashboard.
///
/// Drop-in replaceable: when [AuthRepositoryImpl] grows a real
/// `signInWithPassword` method, swap this binding in DI for one that
/// calls it.
class DemoSignInWithPasswordUseCase implements SignInWithPasswordUseCase {
  DemoSignInWithPasswordUseCase({
    required DemoSignInService demoSignIn,
    required AuthSession session,
    Duration latency = const Duration(milliseconds: 600),
  })  : _demoSignIn = demoSignIn,
        _session = session,
        _latency = latency;

  final DemoSignInService _demoSignIn;
  final AuthSession _session;
  final Duration _latency;

  /// Demo accepts any email matching the validators + password ≥ 6
  /// chars. Reject the well-known "wrong password" combo so the demo
  /// can showcase the error banner without changing build flags.
  static const String _rejectPassword = 'wrongpass';

  @override
  Future<SignInOutcome> call({
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(_latency);

    if (password == _rejectPassword) {
      throw const UnauthorizedFailure(message: 'Invalid email or password.');
    }
    if (email.trim().isEmpty || password.isEmpty) {
      throw const ValidationFailure();
    }

    await _demoSignIn.seed();
    final session = _session;
    if (session is StubAuthSession) {
      session.simulateSignIn();
    }
    return SignInOutcome.authenticated;
  }
}
