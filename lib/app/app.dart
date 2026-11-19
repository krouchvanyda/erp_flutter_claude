import 'package:flutter/material.dart';

import '../core/config/flavor.dart';
import '../core/router/app_navigator.dart';
import '../core/router/auth_session.dart';
import '../core/theme/app_theme.dart';
import 'auth_gate.dart';

/// The root widget: theme + root navigator + AuthGate.
class App extends StatelessWidget {
  const App({super.key, required this.session});

  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: Flavor.current.appName,
      debugShowCheckedModeBanner: false,
      // So code without a context can navigate (logout, Step 2, Step 6).
      navigatorKey: AppNavigator.rootKey,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      // Follows the phone's light/dark setting. A saved user choice comes
      // later as a Cubit (BLoC owns real state).
      themeMode: ThemeMode.system,
      home: AuthGate(session: session),
    );
  }
}
