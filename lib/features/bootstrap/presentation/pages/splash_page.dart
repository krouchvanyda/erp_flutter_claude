import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/app_colors.dart';
import '../bloc/app_init_bloc.dart';
import '../bloc/app_init_event.dart';
import '../bloc/app_init_state.dart';
import '../widgets/animated_logo.dart';
import '../widgets/app_version_text.dart';
import '../widgets/splash_loading_indicator.dart';

/// Screen 0.1 — Splash.
///
/// **Layout** (top → bottom):
/// ```
///                    ┌──────────────────┐
///                    │                  │
///                    │   ●  AnimatedLogo │ ← centred vertically
///                    │       App name   │
///                    │                  │
///                    │  ▭ SplashLoading │ ← thin progress bar
///                    │                  │
///                    │                  │
///                    │      v1.0.0+1    │ ← bottom-anchored
///                    └──────────────────┘
/// ```
///
/// **Navigation** is BLoC-driven, not timer-driven: when
/// [AppInitBloc] emits a terminal state, the listener replaces the
/// route. Splash is the *only* screen with no back navigation —
/// always replaced (`goNamed`), never pushed.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AppInitBloc>(
      create: (_) => GetIt.I<AppInitBloc>()..add(const AppStarted()),
      child: const _SplashView(),
    );
  }
}

class _SplashView extends StatelessWidget {
  const _SplashView();

  @override
  Widget build(BuildContext context) {
    // True edge-to-edge:
    //   - `AnnotatedRegion` makes the status bar + nav bar transparent
    //     with light icons (gradient is dark, so icons must be light).
    //   - `SafeArea` is *only* applied around the foreground content
    //     (logo, indicator, version) so they don't slide under the
    //     notch / camera cutout / gesture nav, while the gradient
    //     itself extends from the very top of the status bar to the
    //     very bottom of the system nav bar.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,   // Android
        statusBarBrightness: Brightness.dark,        // iOS
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        // No AppBar; body fills the whole window.
        body: BlocListener<AppInitBloc, AppInitState>(
          listener: _onStateChanged,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.splashGradientTop,
                  AppColors.splashGradientBottom,
                ],
              ),
            ),
            child: SafeArea(
              minimum: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  // Top spacer — gives the logo enough room to land in
                  // the optical centre (slightly above geometric centre).
                  const Spacer(flex: 5),
                  const AnimatedLogo(),
                  const SizedBox(height: 32),
                  const SplashLoadingIndicator(),
                  const Spacer(flex: 6),
                  BlocBuilder<AppInitBloc, AppInitState>(
                    builder: (context, state) {
                      if (state is AppInitFailure) {
                        return Padding(
                          padding: const EdgeInsets.all(24),
                          child: TextButton(
                            onPressed: () => context
                                .read<AppInitBloc>()
                                .add(const AppStarted()),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.splashForeground,
                            ),
                            child: const Text('Retry'),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 24),
                    child: AppVersionText(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onStateChanged(BuildContext context, AppInitState state) {
    switch (state) {
      case AppInitLoading():
      case AppInitFailure():
        return; // stay on splash
      case AppInitUnauthenticated():
        context.goNamed(RoutePaths.loginName);
      case AppInitAuthenticated():
        context.goNamed(RoutePaths.dashboardName);
      case AppInitLocked():
        // Lock route ships in Slice 9.3.3. Until then fall back to
        // login so the bounce target always exists.
        context.goNamed(RoutePaths.loginName);
    }
  }
}
