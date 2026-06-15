/// Minimal in-house service locator — a drop-in replacement for the former
/// `get_it` package (removed).
///
/// Why this exists: the app needs type-based service resolution in places
/// that have **no `BuildContext`** — the `main()` bootstrap, the call
/// services, and especially the FCM background isolate that shows the
/// incoming-call screen on a killed app. `BlocProvider`/`RepositoryProvider`
/// can't reach those, so a global locator is required. This keeps the exact
/// API surface the codebase already used (`GetIt.I<T>()`, `getIt<T>()`,
/// `registerLazySingleton`, `registerFactory`, `registerSingleton`,
/// `isRegistered`, `unregister`, `reset`) so call sites are unchanged.
///
/// Supports only the subset the app uses — no scopes, no instance names,
/// no async singletons, no dispose hooks.
class GetIt {
  GetIt._();

  /// The process-wide singleton (mirrors `GetIt.instance` / `GetIt.I`).
  static final GetIt instance = GetIt._();
  static GetIt get I => instance;

  final Map<Type, _Registration> _registrations = {};

  /// Callable form: `getIt<T>()`.
  T call<T extends Object>() => get<T>();

  T get<T extends Object>() {
    final reg = _registrations[T];
    if (reg == null) {
      throw StateError(
        'GetIt: type $T is not registered. Register it before resolving.',
      );
    }
    return reg.resolve() as T;
  }

  bool isRegistered<T extends Object>() => _registrations.containsKey(T);

  /// One instance, created lazily on first resolution.
  void registerLazySingleton<T extends Object>(T Function() factoryFunc) {
    _registrations[T] = _Registration.lazySingleton(factoryFunc);
  }

  /// A fresh instance on every resolution.
  void registerFactory<T extends Object>(T Function() factoryFunc) {
    _registrations[T] = _Registration.factory(factoryFunc);
  }

  /// A pre-built instance, registered eagerly.
  void registerSingleton<T extends Object>(T instance) {
    _registrations[T] = _Registration.singleton(instance);
  }

  void unregister<T extends Object>() => _registrations.remove(T);

  Future<void> reset() async => _registrations.clear();
}

class _Registration {
  _Registration._({
    this.factoryFunc,
    required this.isFactory,
    this.instance,
  });

  factory _Registration.lazySingleton(Object Function() f) =>
      _Registration._(factoryFunc: f, isFactory: false);
  factory _Registration.factory(Object Function() f) =>
      _Registration._(factoryFunc: f, isFactory: true);
  factory _Registration.singleton(Object instance) =>
      _Registration._(isFactory: false, instance: instance);

  final Object Function()? factoryFunc;
  final bool isFactory;
  Object? instance;

  Object resolve() {
    if (isFactory) return factoryFunc!();
    return instance ??= factoryFunc!();
  }
}
