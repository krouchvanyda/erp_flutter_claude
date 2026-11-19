part of 'login_view_model_bloc.dart';

@immutable
sealed class LoginViewModelEvent {}

/// The user tapped "Sign in" (form already checked on the phone).
final class OnLoginSubmittedEvent extends LoginViewModelEvent {
  OnLoginSubmittedEvent({required this.email, required this.password});

  final String email;
  final String password;
}
