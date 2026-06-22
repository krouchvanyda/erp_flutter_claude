# 🧪 Lesson 01 — Unit Tests, Deeper (setUp + matchers + async)

You wrote your first test. Now let's level up with the 3 things you'll use in
almost every real test: **`setUp`**, **more matchers**, and **async tests**.

We'll learn from a REAL file in your repo:
`test/core/analytics/recording_analytics_service_test.dart`.

---

## 1. The problem `setUp` solves

Look at the first test you wrote — you made the object inside the test:

```dart
test('starts empty', () {
  final analytics = RecordingAnalyticsService();   // made here
  expect(analytics.calls, isEmpty);
});
```

If you have **10 tests**, you'd copy `final analytics = ...` 10 times. Boring,
and easy to get wrong. **`setUp` runs before EVERY test** and gives each one a
**fresh** object:

```dart
group('RecordingAnalyticsService', () {
  late RecordingAnalyticsService analytics;          // ① declared once

  setUp(() => analytics = RecordingAnalyticsService()); // ② fresh before each test

  test('starts empty', () {
    expect(analytics.calls, isEmpty);                // ③ uses the fresh one
  });

  test('track captures the event', () {
    analytics.track(const AnalyticsEvent(name: 'login'));
    expect(analytics.trackedEvents, hasLength(1));   // a DIFFERENT fresh one
  });
});
```

| Keyword | Meaning |
|---------|---------|
| `late` | "I'll assign this soon, before it's used." Lets you declare without a value yet. |
| `setUp(() => ...)` | runs **before each** `test` in the group. |
| `tearDown(() => ...)` | runs **after each** test (cleanup) — you don't always need it. |

> 🧠 **Why "fresh before each test" matters:** tests must not affect each other.
> If test A added an item and test B saw it, your tests would pass/fail
> depending on order = chaos. `setUp` guarantees a clean start every time.

---

## 2. More matchers (your vocabulary grows)

The second argument of `expect` can be a **matcher** — they read like English.
All of these are real lines from that test file:

```dart
expect(analytics.calls, isEmpty);              // the list is empty
expect(analytics.calls, hasLength(2));         // exactly 2 items
expect(analytics.calls.single, isA<TrackedEvent>()); // the one item is THIS type
expect(call.name, 'Dashboard');                // equals a value
expect(analytics.trackedEvents, [event]);      // equals this whole list
```

A cheat-sheet of the ones you'll use most:

| Matcher | Passes when… |
|---------|--------------|
| `equals(x)` or just `x` | actual == x |
| `isEmpty` / `isNotEmpty` | collection is empty / not |
| `hasLength(n)` | collection has exactly n items |
| `isA<Type>()` | the value is that type |
| `contains(x)` | collection contains x |
| `greaterThan(n)` / `lessThan(n)` | number comparison |
| `isNull` / `isNotNull` | value is null / not |
| `isTrue` / `isFalse` | boolean |
| `throwsA(...)` / `throwsException` | the code throws an error |

> 💡 `.single` means "this list has exactly ONE item — give it to me (and fail
> if there are zero or many)." Handy for "exactly one thing happened" checks.

---

## 3. Async tests (when the code uses `await`)

Some functions are asynchronous (they return a `Future`). To test them, make the
test function **`async`** and **`await`** the call:

```dart
test('identify captures userId + traits', () async {   // ① async
  await analytics.identify('user-1', traits: {'org': 'acme'}); // ② await

  final call = analytics.calls.single as Identified;
  expect(call.userId, 'user-1');
});
```

Just two changes from a normal test: add `async` after `()`, and `await` the
async call. That's it.

> 🧠 If you forget `await`, the test might finish BEFORE the code does, and you'd
> check the result too early. When testing anything with `Future`, `await` it.

---

## 4. Read the whole real file now

Open `test/core/analytics/recording_analytics_service_test.dart` and read all 8
tests. You now understand every line:
- the `group` + `late` + `setUp` pattern at the top,
- the matchers (`isEmpty`, `hasLength`, `isA<>`, `.single`),
- the `async`/`await` tests,
- even the `..` cascade (`analytics..track(...)..clear()` = call several methods
  on the same object).

Run it:
```bash
flutter test test/core/analytics/recording_analytics_service_test.dart
```

---

## 5. 👣 Exercise — write a `setUp`-based test

Pick any small class in `lib/` with a few methods. (A list/collection class is
ideal.) Then:

```dart
import 'package:test/test.dart';
// import your class

void main() {
  group('MyThing', () {
    late MyThing thing;
    setUp(() => thing = MyThing());     // fresh each time

    test('starts empty', () {
      expect(thing.items, isEmpty);     // ARRANGE done in setUp; ASSERT here
    });

    test('add() puts one item in', () {
      thing.add('a');                   // ACT
      expect(thing.items, hasLength(1)); // ASSERT
      expect(thing.items, contains('a'));
    });
  });
}
```

Run it, make it green, then add a 3rd test that checks something **fails** the
way you expect (e.g. removing from empty throws → `expect(() => thing.removeFirst(), throwsA(anything))`).

---

## 6. The mental checklist for any unit test

```
☐ group()    — one group per class/feature
☐ setUp()    — fresh object(s) before each test
☐ test()     — one behavior per test, described in plain English
☐ Arrange    — set up inputs (often in setUp)
☐ Act        — call the one method you're testing
☐ Assert     — expect(actual, matcher)
☐ Repeatable — no randomness, no real network/clock
```

---

## ✅ Check yourself

1. What does `setUp` do, and why is "fresh each test" important? *(Runs before
   each test; keeps tests independent so order never matters.)*
2. What does `expect(list, hasLength(2))` check? *(The list has exactly 2 items.)*
3. What 2 changes make a test handle async code? *(`async` after `()`, `await`
   the call.)*
4. What does `.single` give you? *(The one and only element — fails if 0 or many.)*

---

## ➡️ Next

**Lesson 02 — mocktail (fake out dependencies).** Real classes often need other
things (a network, a database). You don't want a test hitting the real network.
mocktail lets you make a **fake** version so you test ONE thing at a time. (Tell
me when you're ready and I'll build Lesson 02 from your repo's mocktail example.)

⬅ Back to the [testing index](README.md).
