import Flutter
import UIKit
import Firebase
import flutter_local_notifications
import stream_video_push_notification
import flutter_callkit_incoming

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

    // Foreground CallKit suppression bridge.
    //
    // Stream's VoIP PushKit handler reports an incoming call to CallKit even
    // when the app is FOREGROUND (.active), where we want only the in-app
    // overlay. The Dart side can't dismiss it: flutter_callkit_incoming's
    // endCall/endAllCalls issue a CXEndCallAction transaction, which does NOT
    // tear down a PushKit-reported *incoming* call's UI. The reliable dismiss
    // is CXProvider.reportCall(with:endedAt:reason:) — exposed by the plugin
    // as `saveEndCall`. This channel walks the plugin's active calls and ends
    // each that way. iOS-only; Android is untouched.
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "erp/ios_callkit",
        binaryMessenger: controller.binaryMessenger)
      channel.setMethodCallHandler { (call, result) in
        switch call.method {
        case "dismissIncoming":
          if let plugin = SwiftFlutterCallkitIncomingPlugin.sharedInstance {
            let calls = plugin.activeCalls()
            for c in calls {
              if let uuid = (c["id"] as? String) ?? (c["uuid"] as? String),
                 !uuid.isEmpty {
                // reason 6 → remoteEnded → reportCall(endedAt:) → dismisses
                // the incoming screen (unlike CXEndCallAction).
                plugin.saveEndCall(uuid, 6)
              }
            }
            result(calls.count)
          } else {
            result(0)
          }
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
