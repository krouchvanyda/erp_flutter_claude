import 'dart:convert';
import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

class LocalNotificationProvider {
  static const String _channelId = 'high_channel';
  static const String _channelName = 'High Importance Notifications';
  static const String _channelDescription = 'This channel is for important notifications';

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    _channelId,
    _channelName,
    description: _channelDescription,
    importance: Importance.max,
  );

  /// Idempotent guard so a stray double-call from `main.dart` + a
  /// background isolate doesn't register the channel twice or create
  /// duplicate tap listeners.
  bool _initialized = false;

  LocalNotificationProvider();

  Future<void> initialize() async {
    if (_initialized) return;

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    final bool? initialized = await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse? payload) async {
        // FIX: null-safe — `payload` itself can be null on cancellation
        // events. Old code did `payload!.payload != null` which would
        // crash before checking. Guard both layers.
        final body = payload?.payload;
        if (body != null) {
          _handleNotificationResponse(body);
        }
      },
      onDidReceiveBackgroundNotificationResponse:
          onDidReceiveBackgroundNotificationResponse,
    );

    // FIX (critical): create the Android notification channel.
    // Without this, Android 8.0+ silently drops every notification
    // because the channel id we reference in `sendNotification` does
    // not exist on the device. iOS doesn't need this — channels are
    // an Android-only concept; the plugin returns null on iOS.
    final androidPlugin = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_channel);

    _initialized = true;

    if (kDebugMode) {
      log("🟢 Local Notification Initialized: $initialized");
      if (initialized != true) {
        log("🔴 Failed to initialize notifications");
      }
    }
  }

  Future<void> sendNotification({
    String? title,
    String? body,
    required int id,
    required dynamic dataPayload,
  }) async {
    try {
      if (kDebugMode) {
        log("📦 Local notification id=$id payload=$dataPayload");
      }

      final NotificationDetails notificationDetails = NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

      await flutterLocalNotificationsPlugin.show(
        id,
        title,
        body,
        notificationDetails,
        payload: jsonEncode(dataPayload),
      );
    } catch (e, stackTrace) {
      if (kDebugMode) {
        log("❌ Error sending notification: $e", stackTrace: stackTrace);
      }
    }
  }

  /// Cancel a single notification by its display id.
  Future<void> cancelNotification(int id) async {
    try {
      await flutterLocalNotificationsPlugin.cancel(id);
    } catch (e) {
      if (kDebugMode) log("❌ Error cancelling notification $id: $e");
    }
  }

  /// Cancel every active notification (typically called on sign-out).
  Future<void> cancelAllNotification() async {
    try {
      await flutterLocalNotificationsPlugin.cancelAll();
    } catch (e) {
      if (kDebugMode) log("❌ Error cancelling all notifications: $e");
    }
  }
}

/// This will be called when a notification is tapped while app is in
/// background or terminated. Runs in a SEPARATE isolate — cannot touch
/// app state, providers, or navigation. Keep work minimal; route the
/// tap intent through native channels or a hand-off file if you need
/// to drive UI from here.
@pragma('vm:entry-point')
void onDidReceiveBackgroundNotificationResponse(NotificationResponse payload) {
  if (kDebugMode) {
    log("🔔 Background notification tapped: ${payload.payload}");
  }
  final body = payload.payload;
  if (body != null) {
    _handleNotificationResponse(body);
  }
}

@pragma('vm:entry-point')
void _handleNotificationResponse(String payload) {
  try {
    final Map<String, dynamic> notificationData =
        jsonDecode(payload) as Map<String, dynamic>;
    if (kDebugMode) {
      log("📲 Notification tapped: $notificationData");
    }
    // TODO(navigation): deep-link to the relevant screen using the
    // payload's `route` field once the router-side handler exists.
    // Currently a no-op beyond the log.
  } catch (e) {
    if (kDebugMode) {
      log("❌ Error handling notification response: $e");
    }
  }
}
