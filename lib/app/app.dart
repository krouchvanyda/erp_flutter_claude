import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/config/flavor.dart';
import '../core/di/service_locator.dart';
import '../core/router/app_navigator.dart';
import '../core/router/auth_session.dart';
import '../core/theme/app_theme.dart';
import '../features/call/viewmodel/call/call_view_model_bloc.dart';
import '../features/call/widgets/call_route_listener.dart';
import 'auth_gate.dart';

/// The root widget: theme + root navigator + AuthGate.
class App extends StatelessWidget {
  const App({super.key, required this.session});

  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    // The call bloc sits ABOVE every page: an invite can come on any screen,
    // and a call outlives the page that started it (Step 6).
    return BlocProvider.value(
      value: getIt<CallViewModelBloc>(),
      child: MaterialApp(
        title: Flavor.current.appName,
        debugShowCheckedModeBanner: false,
        // So code without a context can navigate (logout, Step 2, Step 6).
        navigatorKey: AppNavigator.rootKey,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        // Follows the phone's light/dark setting. A saved user choice comes
        // later as a Cubit (BLoC owns real state).
        themeMode: ThemeMode.system,
        // Beside the navigator: opens the call screen with the root key.
        builder: (context, child) =>
            CallRouteListener(child: child ?? const SizedBox.shrink()),
        home: AuthGate(session: session),
      ),
    );
  }
}
