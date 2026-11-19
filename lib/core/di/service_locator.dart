/// A tiny, hand-written service locator (the "box").
///
/// Why: some code has NO `BuildContext` — `main()`, and later the background
/// isolate that rings a killed app (Step 7). `RepositoryProvider` /
/// `BlocProvider` can't reach there, so we need one global box.
///
/// ```dart
/// getIt.registerLazySingleton<Dio>(() => Dio());   // register (start-up)
/// final dio = getIt<Dio>();                         // resolve (anywhere)
/// ```
///
/// Rule: only the "edges" (bootstrap, providers, background handlers) call
/// `getIt`. Classes receive what they need in their constructor.
library;

/// The one global box. `getIt<T>()` works because [ServiceLocator.call].
final ServiceLocator getIt = ServiceLocator.instance;

class ServiceLocator {
  ServiceLocator._(); // private: nobody can create a second box

  static final ServiceLocator instance = ServiceLocator._();

  /// Type → how to build it.
  final Map<Type, _Registration<Object>> _registrations = {};

  // ── Register ────────────────────────────────────────────────────

  /// Built on the FIRST `getIt<T>()`, then the SAME object every time.
  /// Use for: Dio, repositories, storage.
  void registerLazySingleton<T extends Object>(T Function() create) =>
      _add<T>(_LazySingleton<T>(create));

  /// A NEW object on every `getIt<T>()`.
  /// Use for: BLoCs (each screen gets a fresh one).
  void registerFactory<T extends Object>(T Function() create) =>
      _add<T>(_Factory<T>(create));

  /// An object you ALREADY built (e.g. after an `await`).
  /// Use for: SharedPreferences, things that need async setup.
  void registerSingleton<T extends Object>(T instance) =>
      _add<T>(_Singleton<T>(instance));

  // ── Resolve ─────────────────────────────────────────────────────

  /// Lets you write `getIt<Dio>()` instead of `getIt.get<Dio>()`.
  T call<T extends Object>() => get<T>();

  T get<T extends Object>() {
    final registration = _registrations[T];
    if (registration == null) {
      throw StateError(
        'ServiceLocator: $T is not registered. '
        'Register it in configureDependencies() first.',
      );
    }
    return registration.resolve() as T;
  }

  bool isRegistered<T extends Object>() => _registrations.containsKey(T);

  // ── Tests ───────────────────────────────────────────────────────

  /// Remove one type (e.g. to swap in a fake).
  void unregister<T extends Object>() => _registrations.remove(T);

  /// Empty the box. Call in `setUp()` so tests don't leak into each other.
  void reset() => _registrations.clear();

  void _add<T extends Object>(_Registration<T> registration) {
    // Registering twice is almost always a bug (two different objects for
    // one type). Crash loudly in debug; use `unregister` first on purpose.
    assert(
      !_registrations.containsKey(T),
      'ServiceLocator: $T is already registered.',
    );
    _registrations[T] = registration;
  }
}

/// The 3 ways to register — a Dart 3 `sealed` family: the compiler knows
/// these are the ONLY subtypes.
sealed class _Registration<T extends Object> {
  T resolve();
}

final class _LazySingleton<T extends Object> extends _Registration<T> {
  _LazySingleton(this._create);
  final T Function() _create;
  T? _instance;

  @override
  T resolve() => _instance ??= _create(); // build once, then reuse
}

final class _Factory<T extends Object> extends _Registration<T> {
  _Factory(this._create);
  final T Function() _create;

  @override
  T resolve() => _create(); // build every time
}

final class _Singleton<T extends Object> extends _Registration<T> {
  _Singleton(this._instance);
  final T _instance;

  @override
  T resolve() => _instance; // already built
}
