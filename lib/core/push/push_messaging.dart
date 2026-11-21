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

  /// Android 13+ / iOS: may we SHOW notifications (the ring in 7.2)?
  /// Asked once after login; later calls return the saved answer.
  Future<void> requestPermission() async {
    try {
      await _messaging.requestPermission();
    } catch (e) {
      debugPrint('[Push] permission request failed: $e');
    }
  }
}
