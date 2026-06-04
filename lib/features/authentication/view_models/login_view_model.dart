import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:erp_mobile/core/error/failure.dart';
import 'package:erp_mobile/data/repositories/auth_repository.dart';

/// Lifecycle of a login attempt.
enum LoginStatus { idle, submitting, success, failure }

/// ViewModel state for the login screen.
///
/// On [LoginStatus.failure] the typed [failure] is carried so the View can
/// map it to a localized message (l10n needs a `BuildContext`, so the
/// mapping stays in the widget — the Cubit never touches `BuildContext`).
class LoginState {
  const LoginState({
    this.status = LoginStatus.idle,
    this.failure,
  });

  final LoginStatus status;
  final Failure? failure;

  bool get isSubmitting => status == LoginStatus.submitting;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoginState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          failure == other.failure;

  @override
  int get hashCode => Object.hash(runtimeType, status, failure);
}

/// ViewModel for [LoginScreen]. Owns the sign-in command; the View only
/// dispatches it and renders [LoginState].
class LoginViewModel extends Cubit<LoginState> {
  LoginViewModel(this._authRepository) : super(const LoginState());

  final AuthRepository _authRepository;

  /// Runs the credential sign-in. Guards against double-submit while a
  /// request is already in flight. Emits [LoginStatus.success] (the View
  /// completes the session/redirect) or [LoginStatus.failure] with the
  /// typed [Failure].
  Future<void> login({
    required String email,
    required String password,
  }) async {
    if (state.isSubmitting) return;
    emit(const LoginState(status: LoginStatus.submitting));

    final result = await _authRepository.login(
      email: email,
      password: password,
    );
    if (isClosed) return;

    result.fold(
      (failure) =>
          emit(LoginState(status: LoginStatus.failure, failure: failure)),
      (_) => emit(const LoginState(status: LoginStatus.success)),
    );
  }
}
