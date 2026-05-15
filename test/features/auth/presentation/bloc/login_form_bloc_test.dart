import 'package:bloc_test/bloc_test.dart';
import 'package:erp_mobile/features/auth/presentation/bloc/login_form_bloc.dart';
import 'package:erp_mobile/features/auth/presentation/bloc/login_form_event.dart';
import 'package:erp_mobile/features/auth/presentation/bloc/login_form_state.dart';
import 'package:test/test.dart';

void main() {
  group('LoginFormBloc', () {
    test('initial state is empty + untouched + invalid', () {
      final state = LoginFormBloc().state;
      expect(state.email, isEmpty);
      expect(state.password, isEmpty);
      expect(state.touched, isFalse);
      expect(state.passwordVisible, isFalse);
      expect(state.isValid, isFalse);
    });

    blocTest<LoginFormBloc, LoginFormState>(
      'EmailChanged populates email + sets touched + runs validator',
      build: LoginFormBloc.new,
      act: (bloc) => bloc.add(const LoginEmailChanged('not-an-email')),
      expect: () => [
        isA<LoginFormState>()
            .having((s) => s.email, 'email', 'not-an-email')
            .having((s) => s.emailError, 'emailError', 'invalid_email')
            .having((s) => s.touched, 'touched', isTrue)
            .having((s) => s.isValid, 'isValid', isFalse),
      ],
    );

    blocTest<LoginFormBloc, LoginFormState>(
      'PasswordChanged populates password + runs validator',
      build: LoginFormBloc.new,
      act: (bloc) => bloc.add(const LoginPasswordChanged('abc')),
      expect: () => [
        isA<LoginFormState>()
            .having((s) => s.password, 'password', 'abc')
            .having((s) => s.passwordError, 'passwordError', 'too_short')
            .having((s) => s.isValid, 'isValid', isFalse),
      ],
    );

    blocTest<LoginFormBloc, LoginFormState>(
      'isValid flips true when both fields are valid',
      build: LoginFormBloc.new,
      act: (bloc) {
        bloc.add(const LoginEmailChanged('foo@bar.com'));
        bloc.add(const LoginPasswordChanged('abcdef'));
      },
      skip: 1, // only check the final state after both edits
      expect: () => [
        isA<LoginFormState>()
            .having((s) => s.emailError, 'emailError', isNull)
            .having((s) => s.passwordError, 'passwordError', isNull)
            .having((s) => s.isValid, 'isValid', isTrue),
      ],
    );

    blocTest<LoginFormBloc, LoginFormState>(
      'PasswordVisibilityToggled flips the bool without touching errors',
      build: LoginFormBloc.new,
      seed: () => const LoginFormState(
        email: 'foo@bar.com',
        password: 'abcdef',
      ),
      act: (bloc) => bloc.add(const LoginPasswordVisibilityToggled()),
      expect: () => [
        isA<LoginFormState>()
            .having((s) => s.passwordVisible, 'passwordVisible', isTrue)
            .having((s) => s.email, 'email', 'foo@bar.com'),
      ],
    );
  });
}
