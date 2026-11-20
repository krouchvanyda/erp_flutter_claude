part of 'splash_view_model_bloc.dart';

@immutable
sealed class SplashViewModelState {}

/// Logo animating, token check running.
final class SplashViewModelInitial extends SplashViewModelState {}

/// Done. The session is ALREADY open when [isLoggedIn] is true, so
/// `AuthGate` can just leave the splash and pick Home or Login.
final class SplashFinishedState extends SplashViewModelState {
  SplashFinishedState({required this.isLoggedIn});

  final bool isLoggedIn;
}
