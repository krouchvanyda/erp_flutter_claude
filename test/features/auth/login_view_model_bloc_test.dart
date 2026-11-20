import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart' show Either, Left, Right;
import 'package:erp_mobile/core/network/network_error_model.dart';
import 'package:erp_mobile/features/auth/model/user_model.dart';
import 'package:erp_mobile/features/auth/repository/auth_repository.dart';
import 'package:erp_mobile/features/auth/viewmodel/login/login_view_model_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

/// A fake repository: each test decides what `login` returns.
class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late _MockAuthRepository repo;

  const user = UserModel(id: '1', email: 'v@x.com', fullName: 'Vanyda');

  setUp(() => repo = _MockAuthRepository());

  /// Tell the fake repository what `login(...)` should return.
  void loginReturns(Either<NetworkErrorModel, UserModel> result) => when(
    () => repo.login(
      email: any(named: 'email'),
      password: any(named: 'password'),
    ),
  ).thenAnswer((_) async => result);

  blocTest<LoginViewModelBloc, LoginViewModelState>(
    'success → [Loading, Success(user)]',
    build: () {
      loginReturns(const Right<NetworkErrorModel, UserModel>(user));
      return LoginViewModelBloc(repo);
    },
    act: (bloc) =>
        bloc.add(OnLoginSubmittedEvent(email: 'v@x.com', password: 'secret')),
    expect: () => [
      isA<LoginLoadingState>(),
      isA<LoginSuccessState>().having((s) => s.user, 'user', user),
    ],
    verify: (_) => verify(
      () => repo.login(email: 'v@x.com', password: 'secret'),
    ).called(1),
  );

  blocTest<LoginViewModelBloc, LoginViewModelState>(
    'failure → [Loading, Error(error)]',
    build: () {
      loginReturns(const Left<NetworkErrorModel, UserModel>(NoInternetError()));
      return LoginViewModelBloc(repo);
    },
    act: (bloc) =>
        bloc.add(OnLoginSubmittedEvent(email: 'v@x.com', password: 'secret')),
    expect: () => [
      isA<LoginLoadingState>(),
      isA<LoginErrorState>().having(
        (s) => s.error,
        'error',
        isA<NoInternetError>(),
      ),
    ],
  );

  blocTest<LoginViewModelBloc, LoginViewModelState>(
    'ServerError fieldErrors are exposed for the form',
    build: () {
      loginReturns(
        const Left<NetworkErrorModel, UserModel>(
          ServerError(
            description: 'Validation failed',
            statusCode: 400,
            fieldErrors: {'email': 'bad email'},
          ),
        ),
      );
      return LoginViewModelBloc(repo);
    },
    act: (bloc) =>
        bloc.add(OnLoginSubmittedEvent(email: 'x', password: 'secret')),
    skip: 1, // skip Loading
    expect: () => [
      isA<LoginErrorState>().having((s) => s.fieldErrors, 'fieldErrors', {
        'email': 'bad email',
      }),
    ],
  );
}
