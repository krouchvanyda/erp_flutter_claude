import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart' show Either, Left, Right;
import 'package:erp_mobile/core/network/network_error_model.dart';
import 'package:erp_mobile/features/auth/model/user_model.dart';
import 'package:erp_mobile/features/profile/model/profile_model.dart';
import 'package:erp_mobile/features/profile/repository/profile_repository.dart';
import 'package:erp_mobile/features/profile/viewmodel/profile_view_model_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

void main() {
  late _MockProfileRepository repo;

  const profile = ProfileModel(
    user: UserModel(id: '7', email: 'v@x.com', fullName: 'Vanyda'),
  );

  setUp(() => repo = _MockProfileRepository());

  void loadReturns(Either<NetworkErrorModel, ProfileModel> result) =>
      when(repo.loadProfile).thenAnswer((_) async => result);

  blocTest<ProfileViewModelBloc, ProfileViewModelState>(
    'first load ok → [Loading, Loaded]',
    setUp: () => loadReturns(const Right(profile)),
    build: () => ProfileViewModelBloc(repo),
    act: (bloc) => bloc.add(OnProfileLoadEvent()),
    expect: () => [
      isA<ProfileLoadingState>(),
      isA<ProfileLoadedState>().having((s) => s.profile, 'profile', profile),
    ],
  );

  blocTest<ProfileViewModelBloc, ProfileViewModelState>(
    'first load fails → [Loading, Error(no lastProfile)] → error view',
    setUp: () => loadReturns(const Left(NoInternetError())),
    build: () => ProfileViewModelBloc(repo),
    act: (bloc) => bloc.add(OnProfileLoadEvent()),
    expect: () => [
      isA<ProfileLoadingState>(),
      isA<ProfileErrorState>().having((s) => s.lastProfile, 'last', isNull),
    ],
  );

  blocTest<ProfileViewModelBloc, ProfileViewModelState>(
    'refresh fails → NO Loading, Error KEEPS the data (snackbar)',
    setUp: () => loadReturns(const Left(NoInternetError())),
    build: () => ProfileViewModelBloc(repo),
    seed: () => ProfileLoadedState(profile: profile), // data on screen
    act: (bloc) => bloc.add(OnProfileLoadEvent()),
    expect: () => [
      isA<ProfileErrorState>()
          .having((s) => s.lastProfile, 'last', profile)
          .having((s) => s.profile, 'profile', profile),
    ],
  );

  // ─────────────── Step 4.2: avatar ───────────────

  const newProfile = ProfileModel(
    user: UserModel(
      id: '7',
      email: 'v@x.com',
      fullName: 'Vanyda',
      avatarUrl: '/uploads/new.jpg',
    ),
  );

  blocTest<ProfileViewModelBloc, ProfileViewModelState>(
    'upload ok → [AvatarUploading(old), AvatarUpdated(new)]',
    setUp: () => when(
      () => repo.uploadAvatar(any()),
    ).thenAnswer((_) async => const Right(newProfile)),
    build: () => ProfileViewModelBloc(repo),
    seed: () => ProfileLoadedState(profile: profile),
    act: (bloc) => bloc.add(OnAvatarUploadEvent(filePath: '/tmp/a.jpg')),
    expect: () => [
      isA<ProfileAvatarUploadingState>().having(
        (s) => s.profile,
        'profile',
        profile,
      ),
      isA<ProfileAvatarUpdatedState>()
          .having((s) => s.profile, 'profile', newProfile)
          .having((s) => s.removed, 'removed', false),
    ],
    verify: (_) => verify(() => repo.uploadAvatar('/tmp/a.jpg')).called(1),
  );

  blocTest<ProfileViewModelBloc, ProfileViewModelState>(
    'upload fails → [AvatarUploading, Error KEEPING the old profile]',
    setUp: () => when(
      () => repo.uploadAvatar(any()),
    ).thenAnswer((_) async => const Left(NoInternetError())),
    build: () => ProfileViewModelBloc(repo),
    seed: () => ProfileLoadedState(profile: profile),
    act: (bloc) => bloc.add(OnAvatarUploadEvent(filePath: '/tmp/a.jpg')),
    expect: () => [
      isA<ProfileAvatarUploadingState>(),
      isA<ProfileErrorState>().having((s) => s.lastProfile, 'last', profile),
    ],
  );

  blocTest<ProfileViewModelBloc, ProfileViewModelState>(
    'remove ok → [AvatarUploading, AvatarUpdated(removed: true)]',
    setUp: () =>
        when(repo.removeAvatar).thenAnswer((_) async => const Right(profile)),
    build: () => ProfileViewModelBloc(repo),
    seed: () => ProfileLoadedState(profile: newProfile),
    act: (bloc) => bloc.add(OnAvatarRemoveEvent()),
    expect: () => [
      isA<ProfileAvatarUploadingState>(),
      isA<ProfileAvatarUpdatedState>().having(
        (s) => s.removed,
        'removed',
        true,
      ),
    ],
  );

  blocTest<ProfileViewModelBloc, ProfileViewModelState>(
    'upload while nothing is on screen yet → ignored',
    build: () => ProfileViewModelBloc(repo),
    act: (bloc) => bloc.add(OnAvatarUploadEvent(filePath: '/tmp/a.jpg')),
    expect: () => <ProfileViewModelState>[],
    verify: (_) => verifyNever(() => repo.uploadAvatar(any())),
  );
}
