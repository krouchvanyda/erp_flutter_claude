import 'dart:developer';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';
import 'local_notification_provider.dart';

class FirebaseNotificationProvider {
  int index = 0;
  final FirebaseMessaging messaging = FirebaseMessaging.instance;

  /// Request notification permissions from the user.
  Future<void> requestNotificationPermissions() async {
    try {
      await messaging.setAutoInitEnabled(true);
      if (Platform.isAndroid) {
        await Permission.notification.request();
      }

      /// Only IOS:
      /// Update the foreground notification presentation options to allow
      /// heads up notifications when [alert = true]
      await messaging.setForegroundNotificationPresentationOptions(alert: false, badge: true, sound: true);

      /// Only IOS
      messaging.requestPermission(alert: true, announcement: false, badge: true, sound: true);
    } catch (e) {
      log("Error requesting notification permissions: $e");
    }
  }

  Future<void> removeForegroundSound() async {
    try {
      /// Only IOS:
      /// Update the foreground notification presentation options to allow
      /// heads up notifications when [alert = true], Hide Notification Overlay on Open app.
      await messaging.setForegroundNotificationPresentationOptions(alert: false, badge: false, sound: false);
    } catch (e, stackTrace) {
      log("Error requesting notification permissions: $e", stackTrace: stackTrace);
    }
  }

  Future<void> setForegroundSound() async {
    try {
      /// Only IOS:
      /// Update the foreground notification presentation options to allow
      /// heads up notifications when [alert = true], Hide Notification Overlay on Open app.
      await messaging.setForegroundNotificationPresentationOptions(alert: false, badge: false, sound: true);
    } catch (e, stackTrace) {
      log("Error requesting notification permissions: $e", stackTrace: stackTrace);
    }
  }

  /// Get the device token for push notifications.
  Future<String?> getFirebaseToken() async {
    try {
      if (Platform.isIOS) {
        String? apnsToken = await messaging.getAPNSToken();
        log("APNs Token: $apnsToken");
      }

      String? token = await messaging.getToken();
      log("FCM Token: $token");
      return token;
    } catch (e) {
      log("Error retrieving device token: $e");
      return null;
    }
  }

  Future<bool> deleteFirebaseToken() async {
    try {
      await messaging.deleteToken();
      return true;
    } catch (e) {
      log("Error delete device token: $e");
      return false;
    }
  }

  /// Initialize the onMessage listener for foreground notifications.
  void initOnMessageListener({required Function(RemoteMessage) getData}) {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.data["type"] == null || message.data["type"] == "") return;
      getData(message);
      LocalNotificationProvider().sendNotification(title: message.notification!.title, body: message.notification!.body, index: index, dataPayload: message.data);
      index++;
    });
  }

  /// Initialize the onMessageOpenedApp listener for background/terminated notifications.
  void initOnMessageOpenedApp({required Function(RemoteMessage) getData}) {
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      getData(message);
    });
  }

  /// Handle notification when the app is terminated and launched via notification click.
  Future<void> handleInitialMessage({required Function(RemoteMessage) getData}) async {
    try {
      RemoteMessage? message = await messaging.getInitialMessage();
      if (message != null) {
        getData(message);
      }
    } catch (e) {
      log("Error retrieving initial message: $e");
    }
  }
}
