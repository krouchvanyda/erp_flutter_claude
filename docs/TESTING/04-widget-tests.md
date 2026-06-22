# 🧪 Lesson 04 — Widget Tests (test the real UI)

So far you tested **logic** (units, fakes, BLoCs). A **widget test** tests the
**UI**: it builds a widget on a fake screen, looks at what's drawn, taps buttons,
types text — and checks the user sees the right thing. All in ~1 second, no real
device.

> 📌 **Heads-up about YOUR repo:** there are currently **0 widget tests** (all 46
> tests are unit/bloc). So this lesson helps you write the project's **first**
> widget test. Widget tests use a **different import** than the others:
> `package:flutter_test/flutter_test.dart` (not `package:test/test.dart`).

---

## 1. Unit test vs widget test (the difference)

| | Unit/BLoC test | Widget test |
|--|----------------|-------------|
| Import | `package:test/test.dart` | `package:flutter_test/flutter_test.dart` |
| Function | `test(...)` | `testWidgets(...)` |
| Tests | logic (classes, BLoCs) | the UI (what's on screen, taps, typing) |
| Gives you | nothing special | a `WidgetTester tester` to drive the UI |

---

## 2. The 4 verbs of a widget test

Almost every widget test does these 4 things:

```
  PUMP   → build the widget on the fake screen   tester.pumpWidget(...)
  FIND   → locate something on screen            find.text('Hi')
  ACT    → tap / type                            tester.tap(...) / enterText(...)
  EXPECT → check what's there                    expect(finder, findsOneWidget)
```

Remember: **Pump → Find → Act → Expect.**

---

## 3. A complete, correct example (copy-run-it)

Make `test/shared/widgets/my_first_widget_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';   // ← the widget-test tools

// A tiny widget we test (normally you'd import a real one from lib/).
class CounterButton extends StatefulWidget {
  const CounterButton({super.key});
  @override
  State<CounterButton> createState() => _CounterButtonState();
}

class _CounterButtonState extends State<CounterButton> {
  int count = 0;
  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text('Count: $count'),
          ElevatedButton(
            onPressed: () => setState(() => count++),
            child: const Text('Add'),
          ),
        ],
      );
}

void main() {
  testWidgets('tapping Add increases the count', (tester) async {  // ① testWidgets
    // PUMP — wrap in MaterialApp so Text/Button have what they need.
    await tester.pumpWidget(const MaterialApp(home: CounterButton())); // ②

    // FIND + EXPECT — it starts at 0.
    expect(find.text('Count: 0'), findsOneWidget);                 // ③
    expect(find.text('Count: 1'), findsNothing);

    // ACT — tap the button, then pump() to rebuild the frame.
    await tester.tap(find.text('Add'));                            // ④
    await tester.pump();                                           // ⑤ rebuild!

    // EXPECT — now it's 1.
    expect(find.text('Count: 1'), findsOneWidget);
    expect(find.text('Count: 0'), findsNothing);
  });
}
```

Run it:
```bash
flutter test test/shared/widgets/my_first_widget_test.dart
```

The 5 numbered lines are the whole skill. Two things beginners always miss:
- **②** you MUST wrap your widget in `MaterialApp` (or at least `Directionality`)
  — otherwise `Text`, buttons, etc. crash ("No Directionality widget found").
- **⑤** after a tap, call `await tester.pump()` to rebuild the screen. Without
  it, the UI hasn't updated yet and your `expect` checks the OLD frame.

---

## 4. `find` — how to locate things

```dart
find.text('Add')          // a widget showing this text
find.byType(ElevatedButton) // by widget class
find.byIcon(Icons.call)   // by icon
find.byKey(const Key('submit')) // by a Key you put on the widget
find.byTooltip('Close')   // by tooltip
```

## 5. The widget-test matchers (instead of values)

```dart
expect(find.text('Hi'), findsOneWidget);   // exactly one
expect(find.text('Hi'), findsNothing);     // none
expect(find.byType(Card), findsNWidgets(3)); // exactly 3
expect(find.text('Hi'), findsWidgets);     // one or more
```

## 6. Acting: tap, type, and the pump family

```dart
await tester.tap(find.byType(ElevatedButton));
await tester.enterText(find.byType(TextField), 'hello');
await tester.pump();              // rebuild ONE frame (after setState)
await tester.pumpAndSettle();     // keep pumping until animations finish
```

> 🧠 Rule of thumb: `pump()` after a simple `setState`; `pumpAndSettle()` when an
> animation or navigation is involved (it waits for them to end).

---

## 7. Testing a widget that needs a BLoC

Many of your widgets read a BLoC via `BlocProvider`. Wrap it in the pump — and
inject a BLoC built with a **fake** repo (Lessons 2 + 3 again!):

```dart
await tester.pumpWidget(
  MaterialApp(
    home: BlocProvider(
      create: (_) => GlobalSearchBloc(federatedSearch: fakeUseCase), // fake inside
      child: const SearchView(),
    ),
  ),
);
await tester.enterText(find.byType(TextField), 'finance');
await tester.pumpAndSettle();                 // let debounce + rebuild finish
expect(find.text('finance'), findsWidgets);
```

> 🔑 Same principle as every lesson: **inject fakes so the test is fast and you
> control the data.** The widget test just adds "and check what's on screen".

---

## 8. 👣 Exercise — your project's first REAL widget test

Pick a small real widget from `lib/shared/widgets/`. Good first targets:

- **`StatusChip`** — pump it with a status, `expect(find.text('APPROVED'), findsOneWidget)`
  and maybe check its color.
- **`PermissionGuard`** — pump it once *with* the permission (child shows) and
  once *without* (child hidden → `findsNothing`). Great because it's pure
  show/hide logic.
- **`AppTextField`** — `enterText`, then check the value / that a callback fired.

Steps:
1. New file `test/shared/widgets/<name>_test.dart`.
2. `import 'package:flutter_test/flutter_test.dart';` + the widget.
3. `pumpWidget(MaterialApp(home: ...))`, then `find` + `expect`.
4. If it reacts to taps/typing: `tap`/`enterText` → `pump()` → `expect` again.

Run: `flutter test test/shared/widgets/<name>_test.dart`

---

## 9. Common beginner errors (and the fix)

| Error you see | Why | Fix |
|---------------|-----|-----|
| "No Directionality widget found" | widget not wrapped | wrap in `MaterialApp(home: ...)` |
| Tapped but nothing changed | didn't rebuild | `await tester.pump()` after the action |
| "pumpAndSettle timed out" | an animation never ends (e.g. a spinner) | use `pump(Duration(...))` instead |
| `findsOneWidget` but found 0 | text differs (case/extra space) or not built yet | check exact text; `pump()` first |

---

## ✅ Check yourself

1. Which import do widget tests use? *(`package:flutter_test/flutter_test.dart`.)*
2. What are the 4 verbs? *(Pump, Find, Act, Expect.)*
3. Why wrap the widget in `MaterialApp`? *(So `Text`/buttons have Directionality,
   theme, etc. — otherwise it crashes.)*
4. Why call `pump()` after a tap? *(To rebuild the frame so the UI reflects the
   change before you assert.)*
5. `findsOneWidget` vs `findsNothing`? *(Exactly one on screen vs none.)*

---

## 🎓 You've completed the core testing path!

```
✅ README  — basics + first test
✅ 01       — setUp, matchers, async
✅ 02       — fakes & mocks (inject dependencies)
✅ 03       — bloc_test (events → states)
✅ 04       — widget tests (the UI)  ← you are here
```

**What now?**
- Practice: add tests as you build features. Aim to test every BLoC and every
  bit of tricky logic.
- Run the whole suite often: `flutter test`.
- Optional next topics (ask me): **golden tests** (pixel snapshots of a widget),
  **coverage** (`flutter test --coverage`), or **integration tests** (drive the
  whole app).

⬅ Back to the [testing index](README.md).
