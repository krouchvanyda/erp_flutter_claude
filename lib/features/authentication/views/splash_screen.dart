import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:erp_mobile/core/di/app_dependencies.dart';
import 'package:erp_mobile/core/router/route_paths.dart';
import 'package:erp_mobile/core/theme/app_font_size.dart';
import 'package:erp_mobile/core/theme/app_label.dart';
import 'package:erp_mobile/core/widgets/dynamic_status_bar.dart';
import 'package:erp_mobile/l10n/app_localizations.dart';
import 'package:erp_mobile/features/authentication/view_models/app_init_view_model.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // The ViewModel runs the auto-login probe (Slice 1.1.5) after the
    // splash animation runtime, then emits authenticated/unauthenticated.
    // Navigation is a View concern, so it lives in the listener — the
    // Cubit never touches a `BuildContext`.
    return BlocProvider(
      create: (_) => AppInitViewModel(
        tokenStorage: AppDependencies.I.tokenStorage,
        authSession: AppDependencies.I.authSession,
      )..decide(),
      child: BlocListener<AppInitViewModel, AppInitState>(
        listenWhen: (previous, current) => previous.status != current.status,
        listener: (context, state) {
          switch (state.status) {
            case AppInitStatus.authenticated:
              context.goNamed(RoutePaths.dashboardName);
            case AppInitStatus.unauthenticated:
              context.goNamed(RoutePaths.loginName);
            case AppInitStatus.probing:
              break;
          }
        },
        child: const _SplashView(),
      ),
    );
  }
}

class _SplashView extends StatelessWidget {
  const _SplashView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: DynamicStatusBar(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.primaryContainer.withOpacity(0.9),
                theme.colorScheme.surface,
                theme.colorScheme.secondaryContainer.withOpacity(0.4),
              ],
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Floating background blobs
              Positioned(
                top: -50,
                left: -50,
                child: _CircularBlob(
                  color: theme.colorScheme.primary.withOpacity(0.05),
                  radius: 120,
                ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                 .moveY(begin: 0, end: 20, duration: 3000.ms, curve: Curves.easeInOut),
              ),
              
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated Logo
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withOpacity(0.1),
                          blurRadius: 40,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.business_center_rounded,
                      size: 96,
                      color: theme.colorScheme.primary,
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 1000.ms)
                      .scale(
                        delay: 200.ms,
                        duration: 800.ms,
                        curve: Curves.easeOutBack,
                      )
                      .shimmer(delay: 1500.ms, duration: 2000.ms)
                      .then()
                      .animate(onPlay: (controller) => controller.repeat(reverse: true))
                      .moveY(begin: 0, end: -10, duration: 2000.ms, curve: Curves.easeInOut),
                  
                  const SizedBox(height: 32),
                  
                  // Animated App Name
                  AppLabel(
                    text: l10n.appName,
                    fontSize: AppFontSize.value32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                    color: theme.colorScheme.primary,
                  )
                      .animate()
                      .fadeIn(delay: 800.ms, duration: 1000.ms)
                      .slideY(begin: 0.3, end: 0, curve: Curves.easeOutCubic),

                  const SizedBox(height: 12),

                  // Subtle Tagline
                  AppLabel(
                    text: l10n.splashTagline,
                    fontSize: AppFontSize.value14,
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                    letterSpacing: 2,
                    fontWeight: FontWeight.w300,
                  )
                      .animate()
                      .fadeIn(delay: 1200.ms, duration: 800.ms),
                ],
              ),
              
              const Positioned(
                bottom: 64,
                child: _SplashFooter(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircularBlob extends StatelessWidget {
  final Color color;
  final double radius;

  const _CircularBlob({required this.color, required this.radius});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _SplashFooter extends StatelessWidget {
  const _SplashFooter();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        SizedBox(
          width: 44,
          height: 44,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: theme.colorScheme.primary.withOpacity(0.4),
          ),
        ).animate().fadeIn(delay: 1500.ms),
        const SizedBox(height: 32),
        AppLabel(
          text: 'v1.0.0',
          fontSize: AppFontSize.value12,
          color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
          letterSpacing: 3,
          fontWeight: FontWeight.bold,
        ).animate().fadeIn(delay: 1800.ms),
      ],
    );
  }
}
