# 🧪 Lesson 03 — Testing a BLoC with `bloc_test`

BLoCs are the **brain of every screen** in this app. So testing them is the most
valuable testing skill here. Good news: a BLoC is **very** predictable, which
makes it easy to test.

We learn from a REAL file:
`test/features/search/presentation/bloc/global_search_bloc_test.dart`.

---

## 1. What a BLoC is (in one line)

> A BLoC takes **events** IN and emits **states** OUT. That's the whole thing.

```
   you add an EVENT  ───►  [ BLoC ]  ───►  emits one or more STATES
   QueryChanged('finance')              Loading('finance') → Success([...])
```

So **testing a BLoC = "I add THIS event, I expect THESE states, in this order."**
Nothing more.

---

## 2. Why there's a special `blocTest` helper

You *could* test a BLoC with plain `test` + listen to its stream + collect
states… but that's fiddly. The `bloc_test` package gives you `blocTest(...)`
which does all that plumbing. You just fill in 3 blanks:

```dart
blocTest<GlobalSearchBloc, GlobalSearchState>(   // <Bloc, State> types
  'description of what should happen',
  build: () => _bloc(),                 // ① make a fresh BLoC
  act:   (bloc) => bloc.add(SomeEvent), // ② add the event(s)
  expect: () => [ StateA, StateB ],     // ③ the states you expect, IN ORDER
);
```

| Blank | Meaning |
|-------|---------|
| `build:` | create a fresh BLoC (often with **fakes** — hello Lesson 02!) |
| `act:` | the events you fire at it |
| `expect:` | the **list** of states it should emit, in the exact order |

Extra optional blanks: `wait:` (pause for debounce/async), `seed:` (start from a
given state), `skip:` (ignore the first N states), `verify:` (extra checks at
the end).

---

## 3. The simplest real example

```dart
blocTest<GlobalSearchBloc, GlobalSearchState>(
  'Cleared event always returns to Idle',
  build: _bloc,                                       // fresh bloc
  act: (bloc) => bloc.add(const GlobalSearchEvent.cleared()),  // one event
  expect: () => [const GlobalSearchState.idle()],     // one state out
);
```

Read it like a sentence: *"Given a fresh bloc, when I add `Cleared`, I expect it
to emit `Idle`."* ✅

> 🧠 `expect:` is a **list** because a BLoC often emits **several** states for one
> event (e.g. `Loading` then `Success`). Order matters.

---

## 4. Expecting MULTIPLE states (Loading → Success)

```dart
blocTest<GlobalSearchBloc, GlobalSearchState>(
  'QueryChanged with text emits Loading then Success after debounce',
  build: _bloc,
  act: (bloc) => bloc.add(const GlobalSearchEvent.queryChanged('finance')),
  wait: const Duration(milliseconds: 380),   // ① wait out the 300ms debounce
  expect: () => [
    const GlobalSearchState.loading('finance'),     // ② first state
    isA<GlobalSearchSuccess>()                       // ③ second state (matched by parts)
        .having((s) => s.query, 'query', 'finance')
        .having((s) => s.groups, 'groups', hasLength(1)),
  ],
);
```

Two new tricks here:

- **`wait:`** — this BLoC waits 300ms before searching (debounce). If the test
  checked immediately, `Success` wouldn't have arrived yet. `wait` pauses so the
  async work finishes.
- **`isA<Type>().having(...)`** — when a state is a big object and you only care
  about *parts* of it. `.having((s) => s.query, 'query', 'finance')` means
  "the state's `query` field (call it 'query' in errors) should equal 'finance'".
  You can chain several `.having(...)`.

> 🧠 Use a plain value (`const ...loading('finance')`) when you can build the
> exact expected state. Use `isA<>().having(...)` when the state has fields you
> don't want to (or can't) reproduce exactly.

---

## 5. `build:` is where Lesson 02's fakes come back

Look how this file builds the BLoC — it injects a **fake** search provider so no
real search runs:

```dart
class _ScriptedProvider implements SearchProvider {     // ← a hand-rolled fake (Lesson 02!)
  final bool shouldThrow;
  @override
  Future<List<SearchResult>> search(String query) async {
    if (shouldThrow) throw StateError('boom');          // make it FAIL on demand
    return [SearchResult(id: query, title: query, providerId: id)];
  }
}

GlobalSearchBloc _bloc({bool shouldThrow = false}) =>
    GlobalSearchBloc(
      federatedSearch: FederatedSearchUseCase(
        providers: [_ScriptedProvider(shouldThrow: shouldThrow)],  // inject the fake
        holds: (_) => true,
      ),
    );
```

So testing the **failure** case is trivial — build with a fake that throws:

```dart
blocTest<GlobalSearchBloc, GlobalSearchState>(
  'provider throwing still yields Loading -> Success(empty)',
  build: () => _bloc(shouldThrow: true),     // ← the fake throws
  act: (bloc) => bloc.add(const GlobalSearchEvent.queryChanged('q')),
  wait: const Duration(milliseconds: 380),
  expect: () => [
    const GlobalSearchState.loading('q'),
    isA<GlobalSearchSuccess>().having((s) => s.groups, 'groups', isEmpty),
  ],
);
```

> 🔑 This is the payoff of Lessons 1–3 combined: **inject a fake (L2) into the
> BLoC's `build:` (L3), then assert the emitted states with matchers (L1).**

---

## 6. Checking the initial state (plain `test`, no blocTest)

The very first state doesn't need `blocTest` — just read `.state`:

```dart
test('initial state is Idle', () {
  expect(_bloc().state, const GlobalSearchState.idle());
});
```

---

## 7. 👣 Exercise — test a BLoC

Pick a BLoC in `lib/features/.../bloc/`. Then:

1. Write the **initial state** test (`expect(bloc.state, ...)`).
2. Write a `blocTest` for the **happy path**: add the main event, expect
   `[Loading, Success]` (use `isA<>().having(...)` for the success fields).
3. Write a `blocTest` for a **failure**: `build:` the BLoC with a fake that
   throws, and expect the error/empty state.
4. If the BLoC is async or debounced, add `wait:`.

Run just your file:
```bash
flutter test test/features/.../your_bloc_test.dart
```

---

## 8. `blocTest` cheat-sheet

```dart
blocTest<MyBloc, MyState>(
  'what should happen',
  build: () => MyBloc(fakeDep),     // make it (inject fakes)
  seed:  () => SomeState(),         // OPTIONAL: start from this state
  act:   (bloc) => bloc.add(Ev()),  // fire events
  wait:  Duration(milliseconds: 380), // OPTIONAL: let async/debounce finish
  skip:  0,                         // OPTIONAL: ignore first N emitted states
  expect: () => [StateA, StateB],   // the states, in order
  verify: (bloc) {                  // OPTIONAL: extra checks at the end
    // e.g. verify a fake was called
  },
);
```

---

## ✅ Check yourself

1. A BLoC turns ___ into ___. *(events into states.)*
2. What are the 3 main blanks in `blocTest`? *(`build`, `act`, `expect`.)*
3. Why is `expect:` a **list**? *(One event can emit several states; order
   matters.)*
4. When do you use `wait:`? *(When the BLoC does async work / debounce, so the
   later states arrive before the assertion.)*
5. When do you use `isA<>().having(...)` instead of a plain expected state?
   *(When you only care about some fields, or can't rebuild the exact state.)*

---

## ➡️ Next

**Lesson 04 — Widget tests.** Now we test the actual UI: pump a widget, `tap` a
button, `find.text(...)` on screen, and check what the user sees. Say **"next"**
when ready.

⬅ Back to the [testing index](README.md).
