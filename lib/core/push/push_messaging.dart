import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// The ONE wrapper around Firebase Cloud Messaging (Step 7.1): the push
/// token and the permission. Everything else talks to this class, so tests
/// use a mock and only this file knows Firebase.
class PushMessaging {
  PushMessaging({FirebaseMessaging? messaging})
    : _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseMessaging _messaging;

  /// This phone's FCM token, or null (no Google Play services, iOS without
  /// APNs set up yet, offline…). Never throws.
  Future<String?> token() async {
    try {
      return await _messaging.getToken();
    } catch (e) {
      debugPrint('[Push] no FCM token: $e');
      return null;
    }
  }

  /// Google can change the token (app data cleared, restore…) → save again.
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  /// Data of pushes that arrive while the app is OPEN (7.2). Calls are
  /// shown by STOMP then; a `call.cancel` still stops a ring notification.
  Stream<Map<String, dynamic>> get onForegroundData =>
      FirebaseMessaging.onMessage.map((m) => m.data);

  /// TEST BRANCH: the user TAPPED a visible push (iOS call banner) or one
  /// of its buttons while the app was minimized → its data + the button id
  /// (null / iOS's default id = the banner itself).
  Stream<({Map<String, dynamic> data, String? action})> get onOpened =>
      FirebaseMessaging.onMessageOpenedApp.map(
        (m) => (data: m.data, action: m.actionIdentifier),
      );

  /// TEST BRANCH: the app was STARTED by tapping a visible push (or a button).
  Future<({Map<String, dynamic> data, String? action})?> launchedBy() async {
    try {
      final m = await _messaging.getInitialMessage();
      return m == null ? null : (data: m.data, action: m.actionIdentifier);
    } catch (_) {
      return null;
    }
  }

  /// The TOP-LEVEL function run in a background isolate for pushes that
  /// arrive while the app is minimized / killed. Call before `runApp`.
  static void setBackgroundHandler(
    Future<void> Function(RemoteMessage message) handler,
  ) => FirebaseMessaging.onBackgroundMessage(handler);

  /// Android 13+ / iOS: may we SHOW notifications (the ring in 7.2)?
  /// Asked once after login; later calls return the saved answer.
  Future<void> requestPermission() async {
    try {
      final settings = await _messaging.requestPermission();
      // TEST BRANCH: authorized / denied / provisional / notDetermined
      debugPrint(
        '[Push] permission=${settings.authorizationStatus.name} '
        'alert=${settings.alert.name} lockScreen=${settings.lockScreen.name} '
        'center=${settings.notificationCenter.name}',
      );
    } catch (e) {
      debugPrint('[Push] permission request failed: $e');
    }
  }
}
