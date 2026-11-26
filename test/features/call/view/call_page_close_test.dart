import 'package:bloc_test/bloc_test.dart';
import 'package:erp_mobile/core/theme/app_theme.dart';
import 'package:erp_mobile/features/call/view/call_page.dart';
import 'package:erp_mobile/features/call/viewmodel/call/call_view_model_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _MockCallBloc extends MockBloc<CallViewModelEvent, CallViewModelState>
    implements CallViewModelBloc {}

void main() {
  // iOS minimized: the page is pushed but never drawn, and the call ends
  // meanwhile. When the app comes back, the page is built for the first
  // time with the bloc ALREADY Idle → it must close by itself.
  testWidgets('first built while Idle → closes itself (no stuck "…" screen)', (
    tester,
  ) async {
    final bloc = _MockCallBloc();
    whenListen(
      bloc,
      const Stream<CallViewModelState>.empty(),
      initialState: const CallIdleState(),
    );
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      BlocProvider<CallViewModelBloc>.value(
        value: bloc,
        child: MaterialApp(
          navigatorKey: navigatorKey,
          theme: AppTheme.light(),
          home: const Scaffold(body: Text('inbox')),
        ),
      ),
    );
    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const CallPage()),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CallPage), findsNothing);
    expect(find.text('inbox'), findsOneWidget);
  });
}
