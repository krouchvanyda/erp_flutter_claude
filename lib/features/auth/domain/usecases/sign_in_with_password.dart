import '../../../../core/error/failure.dart';

/// Outcome of [SignInWithPasswordUseCase].
///
/// Closed enum so the [AuthBloc] handler stays exhaustive — a future
/// "MFA challenge required" outcome lands as a new case here, forcing
/// the bloc to handle it.
enum SignInOutcome {
  /// Tokens stored, profile cached → router can bounce to /dashboard.
  authenticated,

  /// Server accepted the password but requires a second factor → bloc
  /// should redirect to /mfa/otp instead of /dashboard.
  mfaRequired,
}

/// Sign-in contract used by [AuthBloc] (Screen 1.1).
///
/// **Why an interface, not a static call**: the bloc unit-tests a fake
/// to drive each branch (success, MFA, ValidationFailure, server
/// error) deterministically. The production wiring will plug the
/// real `AuthRepository.signInWithPassword` in here once that surface
/// lands; the demo wiring (today) seeds the demo user and flips the
/// stub auth session.
abstract class SignInWithPasswordUseCase {
  /// Throws on failure:
  /// - [ValidationFailure] for shape errors (server-side email/password
  ///   policy rejection that doesn't fit the local validators)
  /// - [UnauthorizedFailure] for bad credentials
  /// - [NetworkFailure] / [TimeoutFailure] for transport
  Future<SignInOutcome> call({
    required String email,
    required String password,
  });
}
