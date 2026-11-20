import 'package:dartz/dartz.dart' show Either;
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/network_error_model.dart';
import '../model/profile_model.dart';
import '../repository/profile_repository.dart';

part 'profile_view_model_event.dart';
part 'profile_view_model_state.dart';

/// The profile page's ViewModel (MVVM-template style).
///
/// First load:   Loading → Loaded(profile)  or  Error(error)
/// Pull refresh: (no Loading — keep the data on screen)
///               → Loaded(newProfile)  or  Error(error, lastProfile)
/// Avatar:       AvatarUploading(profile)
///               → AvatarUpdated(newProfile)  or  Error(error, lastProfile)
class ProfileViewModelBloc
    extends Bloc<ProfileViewModelEvent, ProfileViewModelState> {
  ProfileViewModelBloc(this._repository) : super(ProfileViewModelInitial()) {
    on<OnProfileLoadEvent>(_onLoad);
    on<OnAvatarUploadEvent>(
      (event, emit) => _changeAvatar(
        emit,
        removed: false,
        run: () => _repository.uploadAvatar(event.filePath),
      ),
    );
    on<OnAvatarRemoveEvent>(
      (event, emit) =>
          _changeAvatar(emit, removed: true, run: _repository.removeAvatar),
    );
  }

  final ProfileRepository _repository;

  Future<void> _onLoad(
    OnProfileLoadEvent event,
    Emitter<ProfileViewModelState> emit,
  ) async {
    if (_busy) return; // already loading / uploading
    final shown = state.profile; // what's on screen now (null on first load)
    if (shown == null) {
      emit(ProfileLoadingState()); // full-page spinner only on the first load
    }

    final result = await _repository.loadProfile();
    result.fold(
      (error) => emit(ProfileErrorState(error: error, lastProfile: shown)),
      (profile) => emit(ProfileLoadedState(profile: profile)),
    );
  }

  bool get _busy =>
      state is ProfileLoadingState || state is ProfileAvatarUploadingState;

  /// Upload and remove work the same way:
  /// Uploading(profile) → Updated(newProfile)  or  Error(error, lastProfile)
  Future<void> _changeAvatar(
    Emitter<ProfileViewModelState> emit, {
    required bool removed,
    required Future<Either<NetworkErrorModel, ProfileModel>> Function() run,
  }) async {
    final shown = state.profile;
    if (_busy || shown == null) return; // nothing on screen yet, or busy
    emit(ProfileAvatarUploadingState(profile: shown));

    final result = await run();
    result.fold(
      (error) => emit(ProfileErrorState(error: error, lastProfile: shown)),
      (profile) =>
          emit(ProfileAvatarUpdatedState(profile: profile, removed: removed)),
    );
  }
}
