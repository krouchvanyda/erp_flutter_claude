import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import 'local_notification_provider.dart';

/// Top-level background message handler. **Must be a top-level (or
/// static) function annotated with `@pragma('vm:entry-point')`** so
/// the Flutter background isolate can find it. Registered ONCE from
/// `main.dart` via `FirebaseMessaging.onBackgroundMessage(...)` — that
/// call MUST sit before `runApp(...)` for terminated-app pushes to
/// reach this entry point.
///
/// Runs in a separate isolate: no access to your app's singletons,
/// providers, or BLoCs. Keep the work minimal — log + show a local
/// notification so the user sees something in the tray. Persisting to
/// the inbox repository requires re-opening drift in this isolate
/// (not done here; deferred to when the app reopens).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Fires when a push arrives while the app is either MINIMISED (in
  // recents but not on screen) OR KILLED (swiped away). The Firebase
  // SDK doesn't distinguish those two cases here — both run this
  // background isolate. If you need to tell them apart, set a flag
  // in `WidgetsBindingObserver.didChangeAppLifecycleState` and check
  // it from the foreground (impossible in this isolate).
  _logPush('🟡 MINI / KILLED (tray)', message);

  // ── De-duplication rule ─────────────────────────────────────────
  // When the FCM payload includes a `notification` block AND the app
  // is in the background (which is the only state this handler runs
  // in), the OS already rendered the system notification automatically
  // — both Android and iOS. Showing another LocalNotification here
  // would produce TWO entries in the tray for the same push.
  //
  // We only render locally when the payload is DATA-ONLY (no
  // `notification` block). That's the case the OS does NOT auto-show
  // — typical for silent / custom-rendered chat pushes.
  if (message.notification != null) {
    return;
  }

  // Data-only push → render manually. The plugin must be re-init'd in
  // the background isolate because each isolate has its own plugin
  // registry.
  final local = LocalNotificationProvider();
  await local.initialize();
  await local.sendNotification(
    title: message.data['title']?.toString(),
    body: message.data['body']?.toString(),
    id: _stableId(message),
    dataPayload: message.data,
  );
}

/// Unified push-state log so every entry point emits the same shape.
/// Look for these prefixes in the console to know which lifecycle
/// state the app was in when a push arrived:
///
///   🟢 IN APP            — foreground listener fired
///   🟡 MINI / KILLED     — background isolate fired (no tap)
///   🔵 TAP from MINI     — user tapped notification while backgrounded
///   🔴 TAP from KILLED   — user tapped notification to launch from killed
///
/// Gated on `kDebugMode` so release builds don't spam logcat with
/// notification metadata (and don't leak titles/bodies into crash
/// breadcrumbs).
void _logPush(String state, RemoteMessage m) {
  if (!kDebugMode) return;
  log('$state · id=${m.messageId} · '
      'title=${m.notification?.title ?? m.data['title']} · '
      'body=${m.notification?.body ?? m.data['body']} · '
      'data=${m.data}');
}

/// Derive a stable notification id from the message so:
///   - the same push redelivered over multiple transports collapses
///     into one tray row (the OS uses id as the merge key)
///   - app restarts don't reset to 0 and overwrite previous rows
///
/// Uses `messageId` when present (FCM guarantees uniqueness), falls
/// back to a hash of the data payload. `.abs()` because flutter_local_notifications
/// requires a non-negative int.
int _stableId(RemoteMessage m) {
  final raw = m.messageId ?? m.data.toString();
  return raw.hashCode.abs() & 0x7fffffff;
}

/// Singleton wrapper over `firebase_messaging`. Hold the same instance
/// app-wide so subscription state, dedupe counters, and the dispose
/// hook don't fragment across callers (the previous design created a
/// fresh instance on every `FirebaseNotificationProvider()` call,
/// which scattered the `index` counter and leaked listeners).
class FirebaseNotificationProvider {
  FirebaseNotificationProvider._();
  static final FirebaseNotificationProvider instance =
      FirebaseNotificationProvider._();

  final FirebaseMessaging messaging = FirebaseMessaging.instance;

  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onOpenedAppSub;
  bool _listenersAttached = false;

  /// Request notification permission on both platforms. The iOS call
  /// is now AWAITED — previously it was fire-and-forget, which let
  /// downstream `getToken()` race against an undecided prompt and
  /// return null.
  Future<NotificationSettings?> requestNotificationPermissions() async {
    try {
      if (Platform.isAndroid) {
        // Android 13+ POST_NOTIFICATIONS runtime permission. Older
        // Androids treat this as already granted.
        await Permission.notification.request();
      }

      // Foreground presentation: alert/badge/sound all ON so the user
      // sees heads-up banners while the app is open. The previous
      // `alert: false` contradicted the documenting comment and
      // suppressed in-app banners on iOS.
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // iOS / macOS notification permission prompt. Awaited so the
      // caller can decide what to do with denials.
      final settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        sound: true,
      );
      if (kDebugMode) {
        log('🔔 Notification permission: ${settings.authorizationStatus}');
      }
      return settings;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        log('Error requesting notification permissions: $e',
            stackTrace: stackTrace);
      }
      return null;
    }
  }

  Future<void> removeForegroundSound() async {
    try {
      await messaging.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: false,
        sound: false,
      );
    } catch (e, stackTrace) {
      if (kDebugMode) {
        log('Error updating foreground sound: $e', stackTrace: stackTrace);
      }
    }
  }

  Future<void> setForegroundSound() async {
    try {
      await messaging.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: false,
        sound: true,
      );
    } catch (e, stackTrace) {
      if (kDebugMode) {
        log('Error updating foreground sound: $e', stackTrace: stackTrace);
      }
    }
  }

  /// Returns the FCM device token. On iOS the APNS token must be
  /// available BEFORE FCM can mint its own — older code fetched both
  /// in parallel and often got null on a cold start. Now we await APNS
  /// first and short-circuit if it's still pending.
  ///
  /// Token logging is gated on `kDebugMode` so release builds don't
  /// leak auth-equivalent material into logcat / Crashlytics breadcrumbs.
  Future<String?> getFirebaseToken() async {
    try {
      if (Platform.isIOS) {
        final apnsToken = await messaging.getAPNSToken();
        if (apnsToken == null) {
          // APNS token not yet provisioned — common on simulator and
          // immediately after a fresh install. Caller can retry.
          if (kDebugMode) log('APNs token not ready yet');
          return null;
        }
        if (kDebugMode) log('APNs Token: $apnsToken');
      }

      final token = await messaging.getToken();
      if (kDebugMode) log('FCM Token: $token');
      return token;
    } catch (e) {
      if (kDebugMode) log('Error retrieving device token: $e');
      return null;
    }
  }

  /// Stream of token-rotation events. Wire this into `PushTokenStorage`
  /// so each new token is persisted + re-synced with the backend.
  Stream<String> get onTokenRefresh => messaging.onTokenRefresh;

  Future<bool> deleteFirebaseToken() async {
    try {
      await messaging.deleteToken();
      return true;
    } catch (e) {
      if (kDebugMode) log('Error deleting device token: $e');
      return false;
    }
  }

  /// Foreground message listener. Tracked via `_onMessageSub` so we
  /// can dispose on logout instead of leaking handlers across sessions.
  ///
  /// **Behaviour change**: the previous `type == null` short-circuit
  /// dropped every push that didn't carry a custom `type` data field —
  /// including standard notification-only payloads from the Firebase
  /// console. We now ALWAYS run the caller's `getData` callback and
  /// ALWAYS show a local notification, leaving filtering to the caller.
  void initOnMessageListener({required Function(RemoteMessage) getData}) {
    _onMessageSub?.cancel();
    _onMessageSub = FirebaseMessaging.onMessage.listen((message) {
      try {
        _logPush('🟢 IN APP', message);
        getData(message);

        // ── De-duplication rule (foreground) ────────────────────
        // On iOS we asked for `alert: true` in
        // `setForegroundNotificationPresentationOptions`, so the OS
        // auto-displays any FCM payload with a `notification` block
        // even in foreground. If we ALSO render via LocalNotification
        // here, the user sees two.
        //
        // On Android the OS does NOT auto-display foreground pushes
        // regardless of payload shape, so we MUST render locally
        // there or the user sees nothing.
        //
        // Net rule:
        //   - Android foreground            → always render locally
        //   - iOS foreground + notif block  → skip (OS already shows)
        //   - iOS foreground + data-only    → render locally
        final notif = message.notification;
        final iosWillAutoDisplay = Platform.isIOS && notif != null;
        if (iosWillAutoDisplay) return;

        LocalNotificationProvider().sendNotification(
          title: notif?.title ?? message.data['title']?.toString(),
          body: notif?.body ?? message.data['body']?.toString(),
          id: _stableId(message),
          dataPayload: message.data,
        );
      } catch (e, stackTrace) {
        if (kDebugMode) {
          log('Error handling foreground push: $e', stackTrace: stackTrace);
        }
      }
    });
  }

  void initOnMessageOpenedApp({required Function(RemoteMessage) getData}) {
    _onOpenedAppSub?.cancel();
    _onOpenedAppSub = FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _logPush('🔵 TAP from MINI', message);
      getData(message);
    });
  }

  /// Handle the notification that launched the app from a terminated
  /// state. Only delivers the message the user actually tapped — other
  /// pushes that were waiting in the tray are NOT replayed (reconcile
  /// them via `GET /notifications?unread=true` on cold start).
  Future<void> handleInitialMessage({
    required Function(RemoteMessage) getData,
  }) async {
    try {
      final message = await messaging.getInitialMessage();
      if (message != null) {
        _logPush('🔴 TAP from KILLED', message);
        getData(message);
      }
    } catch (e) {
      if (kDebugMode) log('Error retrieving initial message: $e');
    }
  }

  /// Convenience: attach BOTH listeners + handle the cold-start
  /// initial message in one call. Idempotent — guarded so a hot
  /// reload doesn't double-attach handlers.
  Future<void> attachAllHandlers({
    required Function(RemoteMessage) onMessage,
  }) async {
    if (_listenersAttached) return;
    _listenersAttached = true;
    initOnMessageListener(getData: onMessage);
    initOnMessageOpenedApp(getData: onMessage);
    await handleInitialMessage(getData: onMessage);
  }

  /// Tear down listeners — call on sign-out so the next user on the
  /// same device doesn't inherit subscriptions from the previous one.
  Future<void> dispose() async {
    await _onMessageSub?.cancel();
    await _onOpenedAppSub?.cancel();
    _onMessageSub = null;
    _onOpenedAppSub = null;
    _listenersAttached = false;
  }
}
