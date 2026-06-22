# 🧪 Lesson 02 — Faking Dependencies (test doubles)

Real classes often need **other** things to work: a network, a database, a
clock, a token refresher. In a test you do **not** want to hit the real network
(slow, flaky, needs internet). So you give the code a **fake** version instead.

A fake stand-in is called a **test double** (like a stunt double in movies).

> 💡 **Surprise from YOUR repo:** this project mostly uses **hand-rolled fakes**,
> not the `mocktail` package. Hand-rolled fakes are simpler to understand, so we
> learn those first, then show mocktail as a shortcut.

---

## 1. Why fake anything? (the core idea)

You want to test **ONE** thing at a time. If `LoginService` calls a real
`Network`, then a failing test could mean:
- the login logic is wrong, **or**
- the network is down, **or**
- the server changed.

Too many reasons. So you replace `Network` with a **fake** you fully control.
Now if the test fails, it's the login logic — nothing else. 🎯

```
   Real world:   LoginService ── uses ──► Network ──► internet 😱
   In a test:    LoginService ── uses ──► FakeNetwork (you control it) 😌
```

---

## 2. The 2 jobs a fake does

A fake usually does one or both of these:

1. **Give canned answers** — "when asked, return THIS" (so you control inputs).
2. **Record what happened** — "was I called? how many times? with what?"
   (so you can check outputs/side-effects).

You already met a recorder in Lesson 01: `RecordingAnalyticsService` just
**records** every call so the test can check it.

---

## 3. A real fake from YOUR repo (the recorder kind)

From `test/core/network/auth_interceptor_test.dart`:

```dart
class _RecordingSessionSignal implements SessionSignal {  // ① implement the interface
  int invalidateCount = 0;                                // ② a place to record

  @override
  Future<void> invalidate() async => invalidateCount++;   // ③ record the call
}
```

How a test uses it:

```dart
test('a failed refresh invalidates the session', () async {
  final signal = _RecordingSessionSignal();   // make the fake
  // ... run the code that SHOULD call invalidate() ...
  expect(signal.invalidateCount, 1);          // check it happened exactly once
});
```

> 🧠 The pattern: **implement the real interface, but instead of doing real work,
> record what happened** so the test can `expect` on it.

---

## 4. A real fake from YOUR repo (the canned-answer kind)

Also from that file:

```dart
class _ScriptedRefresher implements TokenRefresher {
  _ScriptedRefresher(this._respond);                         // you pass in the behavior
  final Future<AuthTokens> Function(String refreshToken) _respond;
  int callCount = 0;                                         // also records calls

  @override
  Future<AuthTokens> refresh(String refreshToken) {
    callCount++;
    return _respond(refreshToken);                           // returns YOUR canned answer
  }
}
```

Now a test can make it **succeed** or **fail** on demand:

```dart
// Make it succeed with fake tokens:
final ok = _ScriptedRefresher((_) async => AuthTokens(access: 'new', refresh: 'r'));

// Make it throw (simulate the server rejecting):
final bad = _ScriptedRefresher((_) async => throw Exception('refresh failed'));
```

> 🧠 This is how you test the **hard cases** — "what if the refresh fails?" —
> without ever needing a real failing server.

---

## 5. Write your own fake (the recipe)

```dart
// 1. There is some interface your code depends on:
abstract class Clock { DateTime now(); }

// 2. Make a fake that you control:
class FakeClock implements Clock {
  FakeClock(this.fixed);
  final DateTime fixed;
  @override
  DateTime now() => fixed;          // always returns the SAME time → repeatable!
}

// 3. Use it in a test:
test('greeting says good morning at 9am', () {
  final clock = FakeClock(DateTime(2026, 1, 1, 9));  // 9:00 — you decide
  final greeter = Greeter(clock);                    // inject the fake
  expect(greeter.greeting(), 'Good morning');
});
```

> 🔑 **Dependency injection** = passing the dependency IN (`Greeter(clock)`)
> instead of the class creating it itself. This is what makes a class testable.
> If a class builds its own network/clock inside, you can't fake it. Pass it in.

---

## 6. The shortcut: `mocktail` (the package)

Writing a fake class by hand is clear but a bit of typing. `mocktail` generates
the behavior inline. Same idea, less code:

```dart
import 'package:mocktail/mocktail.dart';

class MockNetwork extends Mock implements Network {}   // 1. one-line fake

test('returns the user on success', () async {
  final net = MockNetwork();

  // 2. canned answer: "WHEN fetch is called, RETURN this"
  when(() => net.fetch('/me')).thenAnswer((_) async => '{"name":"Vibol"}');

  final repo = UserRepo(net);
  final user = await repo.me();

  expect(user.name, 'Vibol');

  // 3. verify it was actually called
  verify(() => net.fetch('/me')).called(1);
});
```

| mocktail piece | Plain meaning |
|----------------|---------------|
| `extends Mock implements X` | make a fake of interface `X` |
| `when(() => f()).thenReturn(v)` | canned answer (sync) |
| `when(() => f()).thenAnswer((_) async => v)` | canned answer (async/Future) |
| `verify(() => f()).called(1)` | check it was called exactly once |
| `verifyNever(() => f())` | check it was never called |
| `any()` | "any argument" when you don't care which |

> ⚖️ **Hand-rolled fake vs mocktail:** both do the same job. Hand-rolled is
> clearer for beginners and is what most of THIS repo uses. mocktail is handy
> when an interface has many methods and you only care about one or two.

---

## 7. 👣 Exercise — fake a dependency

1. Find (or write) a small class that takes a dependency in its constructor.
2. Hand-roll a fake of that dependency (implement the interface; record calls
   and/or return a canned value).
3. Write 2 tests: one where the fake **succeeds**, one where it **fails/throws**.
4. Assert the right thing happened (e.g. `expect(fake.callCount, 1)` or
   `expect(() => sut.doIt(), throwsA(anything))`).

If you want to try mocktail instead, do the same with
`class MockX extends Mock implements X {}` + `when(...)` + `verify(...)`.

---

## 8. Golden rules

- Fake the **slow / external** things (network, db, clock, push) — keep the real
  thing you're actually testing.
- A test with a fake is **fast and repeatable** (no internet, no random time).
- **Inject** dependencies (pass them in) so they CAN be faked.
- Prefer a **recorder** fake to check side-effects, a **scripted** fake to
  control inputs. Many fakes do both (like `_ScriptedRefresher`).

---

## ✅ Check yourself

1. Why fake the network in a test? *(So a failure means YOUR logic is wrong, not
   the internet; and so the test is fast + repeatable.)*
2. What are the 2 jobs a fake does? *(Give canned answers; record what
   happened.)*
3. What makes a class fakeable? *(Dependency injection — it takes the dependency
   in, instead of creating it itself.)*
4. In mocktail, what does `verify(() => f()).called(1)` check? *(That `f` was
   called exactly once.)*

---

## ➡️ Next

**Lesson 03 — `bloc_test` (test a BLoC).** BLoCs are the heart of this app's
screens: you send an **event** and expect a sequence of **states**. `bloc_test`
makes that a one-liner. Say **"next"** when ready and I'll build it from your
repo's real BLoC tests.

⬅ Back to the [testing index](README.md).
