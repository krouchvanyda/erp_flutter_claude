import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_paths.dart';

/// Bootstrap landing page.
///
/// Placeholder probe: after a brief delay the page pushes to `/login`.
/// The router's redirect policy then takes over — if a session already
/// exists (the real silent-refresh probe in a future slice would write
/// tokens before this delay elapses), it bounces straight to
/// `/dashboard` without a flash of the login screen.
///
/// Replace with the real probe once `AuthBloc` lands.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  static const _probeDelay = Duration(milliseconds: 700);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(_probeDelay, _decide);
  }

  void _decide() {
    if (!mounted) return;
    // Always navigate to /login — the router's `resolveAuthRedirect`
    // forwards to /dashboard automatically when a session is active,
    // so we don't need to branch here.
    context.goNamed(RoutePaths.loginName);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
