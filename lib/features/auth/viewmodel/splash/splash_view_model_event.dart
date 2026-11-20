part of 'splash_view_model_bloc.dart';

@immutable
sealed class SplashViewModelEvent {}

/// The splash appeared → check for a saved session.
final class OnSplashStartedEvent extends SplashViewModelEvent {}
