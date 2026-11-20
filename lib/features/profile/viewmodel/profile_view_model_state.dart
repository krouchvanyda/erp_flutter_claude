part of 'profile_view_model_bloc.dart';

@immutable
sealed class ProfileViewModelState {
  /// The profile to draw, if any. The page asks this instead of checking
  /// every state type.
  ProfileModel? get profile => null;
}

final class ProfileViewModelInitial extends ProfileViewModelState {}

/// First load → full-page spinner.
final class ProfileLoadingState extends ProfileViewModelState {}

final class ProfileLoadedState extends ProfileViewModelState {
  ProfileLoadedState({required this.profile});

  @override
  final ProfileModel profile;
}

/// Step 4.2: avatar upload / remove running → keep the page, spinner on
/// the avatar only.
final class ProfileAvatarUploadingState extends ProfileViewModelState {
  ProfileAvatarUploadingState({required this.profile});

  @override
  final ProfileModel profile;
}

/// Step 4.2: avatar changed → show the new profile + a success snackbar.
final class ProfileAvatarUpdatedState extends ProfileViewModelState {
  ProfileAvatarUpdatedState({required this.profile, required this.removed});

  @override
  final ProfileModel profile;

  /// true = "Photo removed", false = "Photo updated".
  final bool removed;
}

/// Load failed.
/// - [lastProfile] null  → nothing to show → error view + "Try again".
/// - [lastProfile] set   → a REFRESH failed → keep the data, show a snackbar.
final class ProfileErrorState extends ProfileViewModelState {
  ProfileErrorState({required this.error, this.lastProfile});

  final NetworkErrorModel error;
  final ProfileModel? lastProfile;

  @override
  ProfileModel? get profile => lastProfile;
}
