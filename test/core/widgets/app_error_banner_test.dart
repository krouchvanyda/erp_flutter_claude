import 'dart:async';

import 'package:erp_mobile/core/network/network_error_model.dart';
import 'package:erp_mobile/core/widgets/app_error_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  // Tests have no internet: don't let google_fonts try to download Inter.
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> pumpBanner(
    WidgetTester tester,
    Future<void> Function() onRetry,
  ) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AppErrorBanner(error: const NoInternetError(), onRetry: onRetry),
      ),
    ),
  );

  testWidgets('shows the error title, message and a matching icon', (
    tester,
  ) async {
    await pumpBanner(tester, () async {});
    expect(find.text(const NoInternetError().title), findsOneWidget);
    expect(find.text(const NoInternetError().description), findsOneWidget);
    expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
  });

  testWidgets('Try again → spinner while waiting, one call only, then back', (
    tester,
  ) async {
    var calls = 0;
    final done = Completer<void>();
    await pumpBanner(tester, () {
      calls++;
      return done.future;
    });

    await tester.tap(find.text('Try again'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Try again'), findsNothing); // can't tap twice
    expect(calls, 1);

    done.complete();
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Try again'), findsOneWidget);
  });
}
