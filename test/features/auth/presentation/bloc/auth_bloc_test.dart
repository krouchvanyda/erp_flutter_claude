import 'package:bloc_test/bloc_test.dart';
import 'package:erp_mobile/core/error/failure.dart';
import 'package:erp_mobile/features/auth/domain/usecases/sign_in_with_password.dart';
import 'package:erp_mobile/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:erp_mobile/features/auth/presentation/bloc/auth_event.dart';
import 'package:erp_mobile/features/auth/presentation/bloc/auth_state.dart';
import 'package:test/test.dart';

class _FakeSignIn implements SignInWithPasswordUseCase {
  _FakeSignIn(this._behaviour);

  /// Function so each test can plug a different response shape (return
  /// a value, throw a Failure, throw an arbitrary error).
  final Future<SignInOutcome> Function({
    required String email,
    required String password,
  }) _behaviour;

  @override
  Future<SignInOutcome> call({
    required String email,
    required String password,
  }) =>
      _behaviour(email: email, password: password);
}

void main() {
  group('AuthBloc.LoginSubmitted', () {
    blocTest<AuthBloc, AuthState>(
      'success → AuthLoading then AuthSuccess',
      build: () => AuthBloc(
        signIn: _FakeSignIn(
          ({required email, required password}) async =>
              SignInOutcome.authenticated,
        ),
      ),
      act: (bloc) =>
          bloc.add(const LoginSubmitted(email: 'a@b.co', password: 'abcdef')),
      expect: () => [isA<AuthLoading>(), isA<AuthSuccess>()],
    );

    blocTest<AuthBloc, AuthState>(
      'mfaRequired → AuthLoading then AuthMfaRequired',
      build: () => AuthBloc(
        signIn: _FakeSignIn(
          ({required email, required password}) async =>
              SignInOutcome.mfaRequired,
        ),
      ),
      act: (bloc) =>
          bloc.add(const LoginSubmitted(email: 'a@b.co', password: 'abcdef')),
      expect: () => [isA<AuthLoading>(), isA<AuthMfaRequired>()],
    );

    blocTest<AuthBloc, AuthState>(
      'UnauthorizedFailure → AuthFailure with the failure message',
      build: () => AuthBloc(
        signIn: _FakeSignIn(
          ({required email, required password}) async {
            throw const UnauthorizedFailure(message: 'Invalid creds');
          },
        ),
      ),
      act: (bloc) =>
          bloc.add(const LoginSubmitted(email: 'a@b.co', password: 'wrong')),
      expect: () => [
        isA<AuthLoading>(),
        isA<AuthFailure>().having((s) => s.message, 'message', 'Invalid creds'),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'NetworkFailure → AuthFailure with a friendly default message',
      build: () => AuthBloc(
        signIn: _FakeSignIn(
          ({required email, required password}) async {
            throw const NetworkFailure();
          },
        ),
      ),
      act: (bloc) =>
          bloc.add(const LoginSubmitted(email: 'a@b.co', password: 'abcdef')),
      expect: () => [
        isA<AuthLoading>(),
        isA<AuthFailure>().having(
          (s) => s.message,
          'message',
          contains('connection'),
        ),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'arbitrary error becomes AuthFailure (no crash propagated)',
      build: () => AuthBloc(
        signIn: _FakeSignIn(
          ({required email, required password}) async {
            throw StateError('boom');
          },
        ),
      ),
      act: (bloc) =>
          bloc.add(const LoginSubmitted(email: 'a@b.co', password: 'abcdef')),
      expect: () => [isA<AuthLoading>(), isA<AuthFailure>()],
    );
  });

  group('AuthBloc.AuthFailureCleared', () {
    blocTest<AuthBloc, AuthState>(
      'returns to AuthInitial so the banner dismisses',
      build: () => AuthBloc(
        signIn: _FakeSignIn(
          ({required email, required password}) async =>
              SignInOutcome.authenticated,
        ),
      ),
      seed: () => const AuthFailure('boom'),
      act: (bloc) => bloc.add(const AuthFailureCleared()),
      expect: () => [isA<AuthInitial>()],
    );
  });
}
