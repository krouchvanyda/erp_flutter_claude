# 🧪 Learning: Testing — Step by Step (for total beginners)

This teaches you **how to write and run tests** in this project, in simple
words. You already have **46 test files** to learn from — we'll use your own
code, not made-up examples.

## 📖 Lessons in this series

| # | File | What you learn | Status |
|---|------|----------------|--------|
| — | **README.md** (this page) | Basics: what a test is, `expect`, run commands, your first test. | ✅ |
| 1 | [01-unit-tests-deeper.md](01-unit-tests-deeper.md) | `setUp`, more matchers, async tests. | ✅ |
| 2 | [02-fakes-and-mocks.md](02-fakes-and-mocks.md) | Fake dependencies (network/db): hand-rolled fakes + mocktail. | ✅ |
| 3 | [03-bloc-test.md](03-bloc-test.md) | Test a BLoC: event in → states out, with `blocTest`. | ✅ |
| 4 | [04-widget-tests.md](04-widget-tests.md) | Test the UI: pump, find, tap, type, expect on screen. | ✅ |

> ✅ **Done with this page?** Go to **[Lesson 01](01-unit-tests-deeper.md)**.
> The core path is **README → 01 → 02 → 03 → 04**.

---

## 1. What is a test, in one sentence?

> A test is a **small piece of code that checks your real code does what you
> expect** — automatically, so you don't have to click around the app by hand.

Example in plain words: *"When I add 2 + 2, I expect 4."* A test writes that
down as code, and the computer checks it for you — every time, in 1 second.

---

## 2. Why test? (why it's worth your time)

- 🛡️ **Catch bugs early** — before users do.
- 🔁 **Change code safely** — if you break something, a test goes red instantly.
- 📖 **Tests are documentation** — they show how a function is meant to be used.
- 😌 **Confidence** — you can ship without fear.

---

## 3. The anatomy of a test (memorize this shape)

Here is a **real test from your project**
(`test/core/theme/app_radii_test.dart`), with every part labeled:

```dart
import 'package:erp_mobile/core/theme/app_radii.dart';  // ① the code you test
import 'package:test/test.dart';                          // ② the test tools

void main() {                       // ③ every test file has a main()
  group('AppRadii', () {            // ④ group = a folder of related tests
    test('none is exactly zero', () {   // ⑤ one test = one thing you check
      expect(AppRadii.none, 0);         // ⑥ expect(ACTUAL, EXPECTED)
    });
  });
}
```

| Part | What it does |
|------|--------------|
| ① `import ...app_radii.dart` | brings in the REAL code you want to check |
| ② `import package:test/test.dart` | gives you `test`, `group`, `expect` |
| ③ `void main()` | the entry point — the test runner calls this |
| ④ `group('name', () {...})` | bundles related tests under a label |
| ⑤ `test('description', () {...})` | ONE check. The description says what it proves |
| ⑥ `expect(actual, expected)` | the heart: "is actual what I expected?" |

> 🧠 **99% of testing is just `expect(actual, expected)`.** Everything else is
> setup around that one line.

---

## 4. `expect` — the most important function

```dart
expect(2 + 2, 4);                          // equals
expect(name, 'Vibol');                     // equals a string
expect(list, isEmpty);                     // a "matcher"
expect(value, greaterThan(48));            // bigger than
expect(value, isNot(equals(0)));           // not equal
expect(list, contains('apple'));           // list has this item
expect(() => doBadThing(), throwsException); // it throws an error
```

The second argument can be a **plain value** (`4`, `'Vibol'`) or a **matcher**
(`isEmpty`, `greaterThan(48)`, `contains(...)`). Matchers read like English.

---

## 5. The 3 kinds of tests in THIS project

| Kind | What it checks | Example file in your repo |
|------|----------------|---------------------------|
| **Unit test** | one function/class, no UI | `test/core/theme/app_radii_test.dart` |
| **BLoC test** | a BLoC: send an event → expect states | `test/features/.../bloc/*_test.dart` (uses `bloc_test`) |
| **Widget test** | a widget renders/behaves correctly | `test/shared/widgets/...` |

Start with **unit tests** — they are the easiest and 80% of what you'll write.

---

## 6. How to RUN tests (the commands)

```bash
# Run ALL tests
flutter test

# Run ONE file (fast — do this while learning)
flutter test test/core/theme/app_radii_test.dart

# Run tests whose description contains a word
flutter test --name "zero"

# See it live as you code (re-runs on save) — optional
flutter test --reporter expanded
```

Green ✅ = pass. Red ❌ = fail (it prints what it expected vs what it got).

> 💡 In VS Code you can also click the little **▶ Run** / **Debug** text that
> appears above every `test(...)` and `main()`.

---

## 7. 👣 Your first exercise (do this now)

You will write a brand-new test from scratch. 10 minutes.

**Step 1 — pick something tiny to test.** Open `lib/core/theme/app_radii.dart`
and look at the values (`xs`, `sm`, `md`, …).

**Step 2 — make a new file** `test/core/theme/my_first_test.dart`:

```dart
import 'package:erp_mobile/core/theme/app_radii.dart';
import 'package:test/test.dart';

void main() {
  test('my first test — sm is bigger than xs', () {
    expect(AppRadii.sm, greaterThan(AppRadii.xs));
  });
}
```

**Step 3 — run it:**
```bash
flutter test test/core/theme/my_first_test.dart
```
You should see ✅ **All tests passed!**

**Step 4 — break it on purpose** (to see a failure). Change `greaterThan` to
`lessThan`, run again, and read the red message. This is what a failing test
looks like — get comfortable with it.

**Step 5 — fix it back, then delete the file** (it was just practice). 🎉

---

## 8. The rhythm of writing a test (AAA)

Every test follows **Arrange → Act → Assert**:

```dart
test('adds an item to the cart', () {
  final cart = Cart();          // ① ARRANGE — set things up
  cart.add('apple');            // ② ACT — do the thing
  expect(cart.items, ['apple']); // ③ ASSERT — check the result
});
```

Say it in your head: *"set up, do it, check it."*

---

## 9. What to learn next (in order)

1. ✅ **Unit tests** (you just started) — read 5 small files in `test/core/`.
2. **`setUp`** — code that runs before each test (shared arrange). Look at
   `test/core/analytics/recording_analytics_service_test.dart`.
3. **mocktail** — fake out dependencies (e.g. a fake network) so you test ONE
   thing. Search the repo: `grep -rl mocktail test`.
4. **bloc_test** — test your BLoCs (event in → states out). Look in
   `test/features/*/presentation/bloc/`.
5. **Widget tests** — `testWidgets(...)`, `tester.tap(...)`, `find.text(...)`.

---

## 10. Golden rules for a beginner

- One test checks **one thing** (one reason to fail).
- The test **description** should read like a sentence: *"sm is bigger than xs"*.
- A test must be **repeatable** — same result every run (no random, no real
  network — that's what mocktail is for).
- If a test is hard to write, your code is probably doing too much — that's a
  useful hint, not a problem with testing.
- **Run tests often.** Red is your friend; it found the bug before a user did.

---

## ✅ Check yourself

1. What does `expect(x, 5)` check? *(That `x` equals 5.)*
2. What are the 3 parts of every test? *(Arrange, Act, Assert.)*
3. How do you run one test file? *(`flutter test path/to/file_test.dart`.)*
4. Which kind of test should a beginner start with? *(Unit tests.)*

You're ready. Open a small file in `test/core/`, read it, then write one of your
own. That's how everyone learns testing. 🚀
