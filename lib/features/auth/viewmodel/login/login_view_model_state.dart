part of 'login_view_model_bloc.dart';

@immutable
sealed class LoginViewModelState {}

final class LoginViewModelInitial extends LoginViewModelState {}

/// Request in flight → button shows a spinner, fields are locked.
final class LoginLoadingState extends LoginViewModelState {}

/// Login failed → show [error] (card) + server field errors (under fields).
final class LoginErrorState extends LoginViewModelState {
  LoginErrorState({required this.error});

  final NetworkErrorModel error;

  /// `{"email": "…"}` from a 400 VALIDATION_ERROR, else empty.
  Map<String, String> get fieldErrors => switch (error) {
    ServerError(:final fieldErrors) => fieldErrors,
    _ => const {},
  };
}

/// Login worked. Tokens are saved and the session is open — `AuthGate` is
/// already switching to Home; the page doesn't navigate.
final class LoginSuccessState extends LoginViewModelState {
  LoginSuccessState({required this.user});

  final UserModel user;
}
