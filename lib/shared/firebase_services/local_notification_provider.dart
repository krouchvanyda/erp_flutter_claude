import 'dart:convert';
import 'dart:developer';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

class LocalNotificationProvider {
  static const String _channelId = 'high_channel';
  static const String _channelName = 'High Importance Notifications';
  static const String _channelDescription = 'This channel is for important notifications';

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(_channelId, _channelName, description: _channelDescription, importance: Importance.max);

  // ✅ Constructor does not auto-initialize anymore
  LocalNotificationProvider();

  // ✅ Now public method to be awaited explicitly
  Future<void> initialize() async {
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/launcher_icon');

    const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings(requestAlertPermission: true, requestBadgePermission: true, requestSoundPermission: true);

    const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid, iOS: initializationSettingsIOS);

    final bool? initialized = await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse? payload) async {
        if (payload!.payload != null) {
          _handleNotificationResponse(payload.payload!);
        }
      },
      onDidReceiveBackgroundNotificationResponse: onDidReceiveBackgroundNotificationResponse,
    );

    log("print------------- 🟢 Local Notification Initialized: $initialized");
    log("initialized: $initialized");
    if (initialized != true) {
      log("print------------- 🔴 Failed to initialize notifications");
    }
  }

  Future<void> sendNotification({String? title, String? body, required int index, required dynamic dataPayload}) async {
    try {
      log("print--------------- 📦 Data Payload: $dataPayload");

      final NotificationDetails notificationDetails = NotificationDetails(android: AndroidNotificationDetails(_channel.id, _channel.name, channelDescription: _channel.description, importance: Importance.max, priority: Priority.high, playSound: true), iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true));

      await flutterLocalNotificationsPlugin.show(index, title, body, notificationDetails, payload: jsonEncode(dataPayload));
    } catch (e) {
      log("print--------------- ❌ Error sending notification: $e");
    }
  }

  /// Call this for cancel all notification.
  Future<void> cancelAllNotification() async {
    try {
      await flutterLocalNotificationsPlugin.cancelAll();
    } catch (e) {
      log("print------------Error cancel cancelAllNotification");
    }
  }
}

/// This will be called when a notification is tapped while app is in background or terminated
@pragma('vm:entry-point')
void onDidReceiveBackgroundNotificationResponse(NotificationResponse payload) {
  log("print------------- 🔔 Background notification tapped with payload: ${payload.payload}");
  if (payload.payload != null) {
    _handleNotificationResponse(payload.payload!);
  }
}

@pragma('vm:entry-point')
void _handleNotificationResponse(String payload) {
  try {
    final Map<String, dynamic> notificationData = jsonDecode(payload);
    log("print--------------- 📲 Notification tapped: $notificationData");
  } catch (e) {
    log("print--------------- ❌ Error handling notification response: $e");
  }
}

bool isChatType(String type) {
  const chatTypes = {"text", "voice", "image"};
  return chatTypes.contains(type);
}
