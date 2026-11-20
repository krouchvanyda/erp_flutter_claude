import 'package:flutter/material.dart';

import '../core/di/service_locator.dart';
import '../core/network/app_service.dart';
import '../core/router/app_navigator.dart';
import '../core/router/auth_session.dart';
import '../features/auth/repository/auth_repository.dart';
import '../features/auth/view/login_page.dart';
import '../features/auth/view/splash_page.dart';
import 'home_placeholder_page.dart';

/// The app's first screen. Decides the BIG screen from the session:
///
/// ```
///  splash not done ──► SplashPage
///  logged out      ──► LoginPage
///  logged in       ──► HomePlaceholderPage
/// ```
///
/// This replaces go_router's `redirect` guard: pages never navigate after
/// login/logout — they flip [AuthSession], and this gate swaps the screen.
/// Normal page-to-page moves use `ConfigRouter`.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.session, required this.appService});

  final AuthSession session;

  /// Only for the temporary home's "Check server" demo (Step 2.1).
  final AppService appService;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  /// UI-only boot flag (not business state): has the splash finished?
  bool _splashDone = false;

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_onSessionChanged);
  }

  @override
  void dispose() {
    widget.session.removeListener(_onSessionChanged); // no leaks
    super.dispose();
  }

  void _onSessionChanged() {
    if (!widget.session.isAuthenticated) {
      // Logged out (button, or token expired in Step 2) while pages were
      // pushed on top with ConfigRouter → close them all, back to this gate.
      AppNavigator.rootKey.currentState?.popUntil((route) => route.isFirst);
    }
    setState(() {}); // rebuild → show Login or Home
  }

  @override
  Widget build(BuildContext context) {
    final Widget screen;
    if (!_splashDone) {
      // The splash opens the session itself (auto-login) BEFORE it calls
      // onFinished → the next build already sees isAuthenticated.
      screen = SplashPage(onFinished: () => setState(() => _splashDone = true));
    } else if (widget.session.isAuthenticated) {
      screen = HomePlaceholderPage(
        // Real logout: server revoke → clear tokens → close session.
        onLogout: getIt<AuthRepository>().logout,
        appService: widget.appService,
      );
    } else {
      screen = const LoginPage();
    }

    // Fade between the big screens (design guide: no bounce, no spin).
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: KeyedSubtree(key: ValueKey(screen.runtimeType), child: screen),
    );
  }
}
