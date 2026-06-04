import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:erp_mobile/core/error/failure.dart';
import 'package:erp_mobile/data/repositories/auth_repository.dart';

/// Lifecycle of a registration attempt.
enum RegisterStatus { idle, submitting, success, failure }

/// ViewModel state for the registration screen. Carries the typed
/// [failure] on [RegisterStatus.failure] so the View maps it to l10n.
class RegisterState {
  const RegisterState({
    this.status = RegisterStatus.idle,
    this.failure,
  });

  final RegisterStatus status;
  final Failure? failure;

  bool get isSubmitting => status == RegisterStatus.submitting;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RegisterState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          failure == other.failure;

  @override
  int get hashCode => Object.hash(runtimeType, status, failure);
}

/// ViewModel for [RegisterScreen]. Owns the create-account command. Form
/// validation + the terms checkbox stay in the View (pure UI concerns).
class RegisterViewModel extends Cubit<RegisterState> {
  RegisterViewModel(this._authRepository) : super(const RegisterState());

  final AuthRepository _authRepository;

  Future<void> register({
    required String email,
    required String password,
    required String fullName,
    required String phone,
  }) async {
    if (state.isSubmitting) return;
    emit(const RegisterState(status: RegisterStatus.submitting));

    final result = await _authRepository.register(
      email: email,
      password: password,
      fullName: fullName,
      phone: phone,
    );
    if (isClosed) return;

    result.fold(
      (failure) => emit(
        RegisterState(status: RegisterStatus.failure, failure: failure),
      ),
      (_) => emit(const RegisterState(status: RegisterStatus.success)),
    );
  }
}
