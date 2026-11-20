part of 'profile_view_model_bloc.dart';

@immutable
sealed class ProfileViewModelEvent {}

/// Page opened, pull-to-refresh, or "Try again".
final class OnProfileLoadEvent extends ProfileViewModelEvent {}

/// Step 4.2: the user picked / took a photo → upload it.
final class OnAvatarUploadEvent extends ProfileViewModelEvent {
  OnAvatarUploadEvent({required this.filePath});

  final String filePath;
}

/// Step 4.2: "Remove photo".
final class OnAvatarRemoveEvent extends ProfileViewModelEvent {}
