import 'package:erp_mobile/core/di/service_locator.dart';
import 'package:flutter_test/flutter_test.dart';

class _Counter {
  _Counter() {
    created++;
  }
  static int created = 0;
}

class _Engine {}

/// Constructor injection: Car does not build its Engine, it receives it.
class _Car {
  _Car(this.engine);
  final _Engine engine;
}

void main() {
  setUp(() {
    getIt.reset();
    _Counter.created = 0;
  });

  test('registerLazySingleton: built on first get, then the same object', () {
    getIt.registerLazySingleton<_Counter>(_Counter.new);
    expect(_Counter.created, 0, reason: 'lazy: nothing built yet');

    final a = getIt<_Counter>();
    final b = getIt<_Counter>();

    expect(_Counter.created, 1);
    expect(identical(a, b), isTrue);
  });

  test('registerFactory: a new object every time', () {
    getIt.registerFactory<_Counter>(_Counter.new);

    final a = getIt<_Counter>();
    final b = getIt<_Counter>();

    expect(_Counter.created, 2);
    expect(identical(a, b), isFalse);
  });

  test('registerSingleton: returns the object we passed in', () {
    final engine = _Engine();
    getIt.registerSingleton<_Engine>(engine);

    expect(identical(getIt<_Engine>(), engine), isTrue);
  });

  test('constructor injection: dependencies are resolved from the box', () {
    getIt
      ..registerLazySingleton<_Engine>(_Engine.new)
      ..registerFactory<_Car>(() => _Car(getIt()));

    final car = getIt<_Car>();

    expect(identical(car.engine, getIt<_Engine>()), isTrue);
  });

  test('get an unregistered type → clear error', () {
    expect(() => getIt<_Engine>(), throwsStateError);
  });

  test('register the same type twice → assert fails (debug)', () {
    getIt.registerLazySingleton<_Engine>(_Engine.new);
    expect(
      () => getIt.registerLazySingleton<_Engine>(_Engine.new),
      throwsA(isA<AssertionError>()),
    );
  });

  test('unregister lets you swap in a fake', () {
    getIt.registerSingleton<_Engine>(_Engine());
    final fake = _Engine();

    getIt
      ..unregister<_Engine>()
      ..registerSingleton<_Engine>(fake);

    expect(identical(getIt<_Engine>(), fake), isTrue);
  });
}
