import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:injectable/injectable.dart';

import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/otp_entry_page.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import 'auth_redirect_policy.dart';
import 'auth_session.dart';
import 'not_found_page.dart';
import 'route_paths.dart';

/// Owns the app's [GoRouter] instance and wires the [AuthSession] in as the
/// `refreshListenable`, so a sign-in/out instantly re-evaluates the guard.
///
/// The actual redirect rules live in [resolveAuthRedirect] (pure Dart) so
/// they can be unit-tested without Flutter.
@lazySingleton
class AppRouter {
  AppRouter(AuthSession session) : config = _build(session);

  final GoRouter config;

  static GoRouter _build(AuthSession session) => GoRouter(
        initialLocation: RoutePaths.splash,
        debugLogDiagnostics: kDebugMode,
        refreshListenable: session,
        redirect: (context, state) => resolveAuthRedirect(
          matchedLocation: state.matchedLocation,
          isAuthenticated: session.isAuthenticated,
        ),
        errorBuilder: (context, state) =>
            NotFoundPage(location: state.matchedLocation),
        routes: [
          GoRoute(
            path: RoutePaths.splash,
            name: RoutePaths.splashName,
            builder: (_, __) => const SplashPage(),
          ),
          GoRoute(
            path: RoutePaths.login,
            name: RoutePaths.loginName,
            builder: (_, __) => LoginPage(
              // Placeholder wiring until the real AuthBloc lands: flipping
              // the stub auth session emits a listener notification, which
              // GoRouter picks up via `refreshListenable` and bounces to
              // /dashboard via the redirect policy. No `context.go` here.
              onSimulatedLogin: () {
                if (session is StubAuthSession) {
                  session.simulateSignIn();
                }
              },
            ),
          ),
          GoRoute(
            path: RoutePaths.otp,
            name: RoutePaths.otpName,
            builder: (_, __) => const OtpEntryPage(),
          ),
          GoRoute(
            path: RoutePaths.dashboard,
            name: RoutePaths.dashboardName,
            builder: (_, __) => DashboardPage(
              // Same dance in reverse: AuthSession.signOut notifies, the
              // router re-evaluates, and the redirect policy sends the
              // user back to /login.
              onSignOut: () => session.signOut(),
            ),
          ),
        ],
      );
}
