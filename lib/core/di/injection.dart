import 'package:shared_preferences/shared_preferences.dart';

import 'service_locator.dart';

/// Fills the box. Called ONCE from `bootstrap()` before `runApp()`.
///
/// Order matters: register a thing before anything that needs it.
/// Each feature will add its own `registerXModule(getIt)` here later:
///
/// ```
/// configureDependencies()
///   ├── _registerCore()        SharedPreferences  (Step 1.3, now)
///   │                          Dio, TokenStorage   (Step 2)
///   ├── registerAuthModule()   (Step 3)
///   ├── registerProfileModule()(Step 4)
///   ├── registerChatModule()   (Step 5)
///   └── registerCallModule()   (Step 6)
/// ```
Future<void> configureDependencies() async {
  await _registerCore();
}

Future<void> _registerCore() async {
  // async setup → build it first, then registerSingleton the ready object.
  final prefs = await SharedPreferences.getInstance();
  getIt.registerSingleton<SharedPreferences>(prefs);
}
