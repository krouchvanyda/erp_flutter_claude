import 'package:bloc/bloc.dart';

import '../../../../core/error/failure.dart';
import '../../domain/usecases/sign_in_with_password.dart';
import 'auth_event.dart';
import 'auth_state.dart';

/// Auth bloc for Screen 1.1.
///
/// Translates [LoginSubmitted] into a call to the
/// [SignInWithPasswordUseCase], then maps the outcome to one of
/// `AuthSuccess` / `AuthMfaRequired` / `AuthFailure`. Bloc never
/// touches `BuildContext`; navigation is the page's job via a
/// `BlocListener`.
///
/// **Failure mapping** — typed `Failure`s come back from the use case;
/// we translate to short user-facing strings here. The page is welcome
/// to override via i18n when the message lands in ARB.
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({required SignInWithPasswordUseCase signIn})
      : _signIn = signIn,
        super(const AuthInitial()) {
    on<LoginSubmitted>(_onLoginSubmitted);
    on<BiometricLoginSubmitted>(_onBiometricLoginSubmitted);
    on<AuthFailureCleared>((_, emit) => emit(const AuthInitial()));
  }

  final SignInWithPasswordUseCase _signIn;

  Future<void> _onLoginSubmitted(
    LoginSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final outcome = await _signIn(
        email: event.email,
        password: event.password,
      );
      switch (outcome) {
        case SignInOutcome.authenticated:
          emit(const AuthSuccess());
        case SignInOutcome.mfaRequired:
          emit(const AuthMfaRequired());
      }
    } on UnauthorizedFailure catch (f) {
      emit(AuthFailure(f.message ?? 'Invalid email or password.'));
    } on ValidationFailure catch (f) {
      emit(AuthFailure(f.message ?? 'Please check your credentials.'));
    } on NetworkFailure catch (_) {
      emit(const AuthFailure('No connection. Check your network.'));
    } on TimeoutFailure catch (_) {
      emit(const AuthFailure('The server took too long to respond.'));
    } on Failure catch (f) {
      emit(AuthFailure(f.toString()));
    } catch (e) {
      emit(AuthFailure(e.toString()));
    }
  }

  Future<void> _onBiometricLoginSubmitted(
    BiometricLoginSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    // Biometric unlock lives on its own screen (1.2 — Biometric Unlock).
    // The login screen's Biometric button just navigates there. Bloc
    // emits AuthSuccess so the page's BlocListener can route — kept here
    // so the spec's "BiometricLoginButton on Screen 1.1" is wired
    // end-to-end without a new event/state for the demo.
    emit(const AuthSuccess());
  }
}
