import 'package:get_it/get_it.dart';

import '../../core/router/auth_session.dart';
import 'data/demo_sign_in.dart';
import 'data/demo_sign_in_use_case.dart';
import 'data/stub_biometric_availability_probe.dart';
import 'domain/biometric_availability.dart';
import 'domain/usecases/sign_in_with_password.dart';
import 'presentation/bloc/auth_bloc.dart';

/// Manual DI registration for the Module 1 surfaces that aren't wired
/// via `injectable` annotations (Screen 1.1 — Login).
///
/// Same pattern as the other modules' `_di.dart` entry points: avoids
/// re-running build_runner per bloc tweak. Call once from `main.dart`
/// after `configureDependencies()`.
void registerAuthModule(GetIt getIt) {
  if (!getIt.isRegistered<SignInWithPasswordUseCase>()) {
    getIt.registerLazySingleton<SignInWithPasswordUseCase>(
      () => DemoSignInWithPasswordUseCase(
        demoSignIn: getIt<DemoSignInService>(),
        session: getIt<AuthSession>(),
      ),
    );
  }
  if (!getIt.isRegistered<BiometricAvailabilityProbe>()) {
    getIt.registerLazySingleton<BiometricAvailabilityProbe>(
      // Flip to `available: true` here when wiring the real probe so
      // the Screen 1.1 BiometricLoginButton appears in the demo.
      () => const StubBiometricAvailabilityProbe(),
    );
  }
  if (!getIt.isRegistered<AuthBloc>()) {
    getIt.registerFactory<AuthBloc>(
      () => AuthBloc(signIn: getIt<SignInWithPasswordUseCase>()),
    );
  }
}
