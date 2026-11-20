import '../core/di/injection.dart';
import '../core/di/service_locator.dart';
import '../features/auth/auth_di.dart';
import '../features/chat/chat_di.dart';
import '../features/profile/profile_di.dart';

/// Fills the DI box for the whole app. Called ONCE from `bootstrap()`.
///
/// Lives in `app/` (not `core/`) because it imports every feature, and
/// `core/` must never import `features/`.
///
/// ```
/// configureAppDependencies()
///   ├── configureDependencies()   core: prefs, session, Dio, AppService, tokens
///   ├── registerAuthModule()      Step 3
///   ├── registerProfileModule()   Step 4
///   ├── registerChatModule()      Step 5
///   └── registerCallModule()      Step 6
/// ```
Future<void> configureAppDependencies() async {
  await configureDependencies(); // core first: features depend on it
  registerAuthModule(getIt);
  registerProfileModule(getIt);
  registerChatModule(getIt);
}
