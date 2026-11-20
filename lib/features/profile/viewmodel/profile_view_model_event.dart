part of 'profile_view_model_bloc.dart';

@immutable
sealed class ProfileViewModelEvent {}

/// Page opened, pull-to-refresh, or "Try again".
final class OnProfileLoadEvent extends ProfileViewModelEvent {}
