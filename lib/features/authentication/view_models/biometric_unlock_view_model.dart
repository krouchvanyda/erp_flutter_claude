import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:erp_mobile/core/router/auth_session.dart';
import 'package:erp_mobile/data/services/demo_sign_in.dart';

/// Lifecycle of the biometric unlock flow.
enum BiometricStatus { idle, authenticating, authenticated }

/// ViewModel state for the biometric unlock screen.
class BiometricUnlockState {
  const BiometricUnlockState({this.status = BiometricStatus.idle});

  final BiometricStatus status;

  bool get isAuthenticating => status == BiometricStatus.authenticating;
  bool get isAuthenticated => status == BiometricStatus.authenticated;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BiometricUnlockState &&
          runtimeType == other.runtimeType &&
          status == other.status;

  @override
  int get hashCode => Object.hash(runtimeType, status);
}

/// ViewModel for [BiometricUnlockScreen].
///
/// Demo flow (no real `local_auth` prompt yet): simulate a sensor delay,
/// seed the demo identity, flip the in-process session to authenticated,
/// then emit [BiometricStatus.authenticated] so the View can pop back —
/// the router's `refreshListenable` then redirects `/login` → `/dashboard`.
class BiometricUnlockViewModel extends Cubit<BiometricUnlockState> {
  BiometricUnlockViewModel({
    required DemoSignInService demoSignIn,
    required AuthSession authSession,
  })  : _demoSignIn = demoSignIn,
        _authSession = authSession,
        super(const BiometricUnlockState());

  final DemoSignInService _demoSignIn;
  final AuthSession _authSession;

  Future<void> authenticate() async {
    if (state.isAuthenticating) return;
    emit(const BiometricUnlockState(status: BiometricStatus.authenticating));

    // Simulate the biometric sensor check.
    await Future<void>.delayed(const Duration(milliseconds: 1500));

    await _demoSignIn.seed();
    final session = _authSession;
    if (session is StubAuthSession) {
      session.simulateSignIn();
    }
    if (isClosed) return;
    emit(const BiometricUnlockState(status: BiometricStatus.authenticated));
  }
}
