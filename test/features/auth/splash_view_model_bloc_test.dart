import 'package:bloc_test/bloc_test.dart';
import 'package:erp_mobile/features/auth/repository/auth_repository.dart';
import 'package:erp_mobile/features/auth/viewmodel/splash/splash_view_model_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late _MockAuthRepository repo;

  setUp(() => repo = _MockAuthRepository());

  SplashViewModelBloc build() =>
      SplashViewModelBloc(repo, minDuration: Duration.zero); // no waiting

  blocTest<SplashViewModelBloc, SplashViewModelState>(
    'saved session → Finished(isLoggedIn: true)',
    setUp: () => when(repo.restoreSession).thenAnswer((_) async => true),
    build: build,
    act: (bloc) => bloc.add(OnSplashStartedEvent()),
    expect: () => [
      isA<SplashFinishedState>().having(
        (s) => s.isLoggedIn,
        'isLoggedIn',
        true,
      ),
    ],
    verify: (_) => verify(repo.restoreSession).called(1),
  );

  blocTest<SplashViewModelBloc, SplashViewModelState>(
    'no session → Finished(isLoggedIn: false)',
    setUp: () => when(repo.restoreSession).thenAnswer((_) async => false),
    build: build,
    act: (bloc) => bloc.add(OnSplashStartedEvent()),
    expect: () => [
      isA<SplashFinishedState>().having(
        (s) => s.isLoggedIn,
        'isLoggedIn',
        false,
      ),
    ],
  );

  test('waits at least minDuration (logo animation can play)', () async {
    when(repo.restoreSession).thenAnswer((_) async => true); // instant
    final bloc = SplashViewModelBloc(
      repo,
      minDuration: const Duration(milliseconds: 200),
    );
    final watch = Stopwatch()..start();

    bloc.add(OnSplashStartedEvent());
    await bloc.stream.firstWhere((s) => s is SplashFinishedState);

    expect(watch.elapsedMilliseconds, greaterThanOrEqualTo(200));
    await bloc.close();
  });
}
