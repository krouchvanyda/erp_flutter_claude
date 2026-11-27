import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// The Android notification channel for chat banners (Step 5.7).
///
/// ```
/// backend push  android.notification.channelId = "chat_messages"
///        └─► Android draws the banner in THIS channel
///            (no channel → "Miscellaneous": low importance, no pop-up)
/// ```
///
/// A channel can only be made by the app, once (later calls change nothing).
/// The user can turn it off in Settings → Apps → ERP → Notifications, without
/// turning off calls. iOS has no channels: nothing to do there.
abstract final class ChatNotificationChannel {
  /// The SAME id as the backend's `FcmService.CHAT_CHANNEL_ID` and the
  /// manifest's `default_notification_channel_id`.
  static const String id = 'chat_messages';

  static Future<void> ensure({FlutterLocalNotificationsPlugin? plugin}) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await (plugin ?? FlutterLocalNotificationsPlugin())
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              id,
              'Messages',
              description: 'New chat messages',
              importance: Importance.high, // pops up on screen
            ),
          );
    } catch (e) {
      debugPrint('[Push] chat channel not created: $e');
    }
  }
}
