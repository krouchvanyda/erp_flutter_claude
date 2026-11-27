import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart' show appFlavor;

import 'app/app.dart';
import 'app/app_di.dart';
import 'app/call_push.dart';
import 'app/chat_push.dart';
import 'core/config/flavor.dart';
import 'core/di/service_locator.dart';
import 'core/push/chat_notification_channel.dart';
import 'core/push/push_messaging.dart';
import 'core/push/push_registrar.dart';
import 'core/realtime/realtime_lifecycle.dart';
import 'core/router/auth_session.dart';

/// Plain `flutter run`: flavor comes from `--flavor` (dev when none).
Future<void> main() => bootstrap(Flavor.current);

/// Shared start-up for every entry point (main_dev / main_uat / main_prod).
Future<void> bootstrap(Flavor flavor) async {
  // Debug-only guard: `--flavor` (native side) and the entry point (Dart
  // side) must agree, e.g. `--flavor dev -t lib/main_prod.dart` is a bug.
  // `appFlavor == null` is fine: no `--flavor` given, the entry point wins.
  assert(
    appFlavor == null || appFlavor == flavor.name,
    'Flavor mismatch: --flavor $appFlavor but entry point is ${flavor.name}',
  );
  Flavor.pin(flavor);
  WidgetsFlutterBinding.ensureInitialized(); // plugins need the bridge first
  // Push (Step 7): reads google-services.json / GoogleService-Info.plist.
  // A broken Firebase setup must not stop the app: chat and calls in the
  // app still work, only pushes don't.
  var pushReady = false;
  try {
    await Firebase.initializeApp();
    pushReady = true;
    // Pushes while minimized / killed → a background isolate (Step 7.2).
    setUpCallPushBackground();
  } catch (e) {
    debugPrint('[Push] Firebase not available: $e');
  }
  await configureAppDependencies(); // fill the DI box: core + features

  // Live connection follows the session / app / network (Step 5.3).
  getIt<RealtimeLifecycle>().attach();
  // This phone's push token follows the session (Step 7.1).
  if (pushReady) {
    // "Allow notifications?" FIRST, before any screen (like feature/call):
    // every question is answered before the login. Asked only once by iOS /
    // Android; later starts return at once. A "no" is fine: the app runs
    // (iOS CallKit doesn't need it; Android just can't show the ring).
    await getIt<PushMessaging>().requestPermission();
    getIt<PushRegistrar>().attach();
  }

  // Edge: take services from the box, pass them in by constructor.
  runApp(App(session: getIt<AuthSession>()));

  // Call ring notifications ↔ the call bloc (Step 7.2).
  await attachCallPush(fcm: pushReady);

  // Chat banners (Step 5.7): the Android channel, and a tap opens the chat.
  if (pushReady) {
    await ChatNotificationChannel.ensure();
    await getIt<ChatPushOpener>().attach(getIt<PushMessaging>());
  }
}
