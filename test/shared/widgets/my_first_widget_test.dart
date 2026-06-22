import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Lesson 04 exercise: test a REAL widget from lib/ (not a fake one).
import 'package:erp_mobile/shared/widgets/app_text_field.dart';

void main() {
  group('AppTextField', () {
    // Small helper: wrap the widget under test in the minimum app shell it
    // needs (MaterialApp + Scaffold) so Material widgets don't crash.
    Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

    testWidgets('shows its label on screen', (tester) async {
      // PUMP
      await tester.pumpWidget(wrap(const AppTextField(label: 'Email')));

      // FIND + EXPECT
      expect(find.text('Email'), findsOneWidget);
    });

    testWidgets('shows the prefix icon when one is given', (tester) async {
      await tester.pumpWidget(
        wrap(const AppTextField(label: 'Email', icon: Icons.email_outlined)),
      );

      expect(find.byIcon(Icons.email_outlined), findsOneWidget);
    });

    testWidgets('typing fires onChanged with what I typed', (tester) async {
      String? captured; // we record the callback value here

      await tester.pumpWidget(
        wrap(
          AppTextField(
            label: 'Email',
            onChanged: (value) => captured = value, // ARRANGE the callback
          ),
        ),
      );

      // ACT — type into the field, then rebuild.
      await tester.enterText(find.byType(TextField), 'hello@erp.com');
      await tester.pump();

      // EXPECT — the callback got exactly what we typed.
      expect(captured, 'hello@erp.com');
      expect(find.text('hello@erp.com'), findsOneWidget);
    });

    testWidgets('shows an error message when errorText is set', (tester) async {
      await tester.pumpWidget(
        wrap(const AppTextField(label: 'Email', errorText: 'Required')),
      );

      expect(find.text('Required'), findsOneWidget);
    });

    testWidgets('does NOT show an error when errorText is null', (tester) async {
      await tester.pumpWidget(wrap(const AppTextField(label: 'Email')));

      expect(find.text('Required'), findsNothing);
    });
  });
}
