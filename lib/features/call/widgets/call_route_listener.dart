import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/router/app_navigator.dart';
import '../../../core/router/config_router.dart';
import '../view/call_page.dart';
import '../viewmodel/call/call_view_model_bloc.dart';

/// Opens the call screen when a call starts — mine OR theirs, on ANY page.
///
/// Sits in `MaterialApp.builder`, i.e. BESIDE the navigator, not under it.
/// So it can't use `Navigator.of(context)`: it pushes with the ROOT key
/// (`AppNavigator.rootKey`) — a lesson from the old app.
///
/// Only Idle → (Outgoing | Incoming) pushes. A call that starts while the
/// "Call ended" screen is still up reuses that page (it follows the state).
class CallRouteListener extends StatelessWidget {
  const CallRouteListener({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<CallViewModelBloc, CallViewModelState>(
      listenWhen: (previous, current) =>
          previous is CallIdleState && current is! CallIdleState,
      listener: (context, state) {
        final navigatorContext = AppNavigator.rootKey.currentContext;
        if (navigatorContext == null) return;
        ConfigRouter.pushPageDialog<void>(navigatorContext, const CallPage());
      },
      child: child,
    );
  }
}
