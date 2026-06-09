import Flutter
import UIKit
import Firebase
import flutter_local_notifications
import stream_video_push_notification

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FirebaseApp.configure()
    if #available(iOS 10.0, *) {
        UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    }
      FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { (registry) in
          GeneratedPluginRegistrant.register(with: registry)
      }
    GeneratedPluginRegistrant.register(with: self)
    // Register the VoIP PushKit registry so iOS issues a VoIP token and
    // routes incoming-call pushes to CallKit. Without this, PushKit never
    // initializes → getDevicePushTokenVoIP() stays empty → the device never
    // registers with Stream → backgrounded incoming calls never ring.
    // (iOS-only; Android handles call push via FCM and is unaffected.)
    StreamVideoPKDelegateManager.shared.registerForPushNotifications()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
