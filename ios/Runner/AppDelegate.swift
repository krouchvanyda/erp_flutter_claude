import Flutter
import UIKit
import Firebase
import flutter_local_notifications
import stream_video_push_notification
import CallKit

// iOS start-up (Step 7.3).
//
// Who rings an iPhone:
//   app OPEN       → our STOMP invite → the in-app call screen (Step 6)
//   app minimized  → Stream's VoIP push → CallKit (the backend rings only
//   / killed         OFFLINE callees; a minimized app says "background")
//
// CallKit's buttons (Accept / Decline / End) reach Dart through Stream's
// plugin → `CallMedia.callKit` → the call bloc. Nothing else is bridged here.
@main
@objc class AppDelegate: FlutterAppDelegate, CXCallObserverDelegate {
  // True only after a REAL didBecomeActive. It starts false, so a killed
  // app woken by a VoIP push counts as "not on screen".
  private var isAppForeground = false
  private let callObserver = CXCallObserver()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FirebaseApp.configure()
    UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    GeneratedPluginRegistrant.register(with: self)

    // PushKit: iOS gives a VoIP token (Dart sends it to Stream at login)
    // and every VoIP push is shown with CallKit by Stream's plugin.
    StreamVideoPKDelegateManager.shared.registerForPushNotifications()

    // One safety rule (see callObserver below).
    callObserver.setDelegate(self, queue: DispatchQueue.main)
    NotificationCenter.default.addObserver(
      self, selector: #selector(appDidBecomeActive),
      name: UIApplication.didBecomeActiveNotification, object: nil)
    NotificationCenter.default.addObserver(
      self, selector: #selector(appDidEnterBackground),
      name: UIApplication.didEnterBackgroundNotification, object: nil)

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  @objc private func appDidBecomeActive() { isAppForeground = true }
  @objc private func appDidEnterBackground() { isAppForeground = false }

  // A CallKit ring that appears while the app is ON SCREEN is closed at
  // once: our own call screen shows that call (STOMP). It can only happen
  // in a race (the app came to the front just as the backend rang).
  // reportCall(endedAt:) is the only API that closes a PushKit call
  // (Stream: saveEndCall(uuid, 6) = remoteEnded).
  func callObserver(_ callObserver: CXCallObserver, callChanged call: CXCall) {
    guard isAppForeground,
          !call.isOutgoing, !call.hasConnected, !call.hasEnded else { return }
    StreamVideoCallkitManager.shared.saveEndCall(call.uuid.uuidString, 6)
  }
}
