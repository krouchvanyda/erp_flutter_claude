import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_spacing.dart';
import '../viewmodel/splash/splash_view_model_bloc.dart';
import '../widgets/splash_logo.dart';

/// Screen 0.1 — logo + name + small spinner while we check for a saved
/// session (auto-login).
///
/// The decision lives in [SplashViewModelBloc] → `AuthRepository
/// .restoreSession()`. If tokens exist, the session is OPENED there, before
/// [onFinished] runs — so `AuthGate` shows Home, not Login.
///
/// The splash does NOT navigate: it calls [onFinished], and `AuthGate` picks
/// the next screen from the session.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      // an "edge": fresh bloc from DI, and start the check right away
      create: (_) => getIt<SplashViewModelBloc>()..add(OnSplashStartedEvent()),
      child: BlocListener<SplashViewModelBloc, SplashViewModelState>(
        listenWhen: (previous, current) => current is SplashFinishedState,
        listener: (context, state) => onFinished(),
        child: const Scaffold(
          body: Column(
            children: [
              Expanded(child: Center(child: SplashLogo())),
              Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.xxl),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
