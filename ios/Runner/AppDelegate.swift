import Flutter
import UIKit
import Firebase
import flutter_local_notifications
import stream_video_push_notification
import flutter_callkit_incoming
import CallKit

@main
@objc class AppDelegate: FlutterAppDelegate, CXCallObserverDelegate {
  // Genuine on-screen state. Updated ONLY on real lifecycle transitions —
  // deliberately NOT on the transient `.inactive` that CallKit triggers when
  // it presents over a foreground app, and it starts `false` so a VoIP-push
  // COLD LAUNCH (killed app) is treated as background. So this is true only
  // when the app is actually on screen. This is the accurate, device-local,
  // zero-lag answer to "is the user in the app right now?" — far better than
  // backend presence, which can't know the instant the user backgrounds.
  private var isAppForeground = false

  // Observes every CallKit call so we can instantly tear down an incoming
  // screen that appears while the app is foreground.
  private let callObserver = CXCallObserver()

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

    // FOREGROUND CallKit suppression (the real fix for "header shows while the
    // user is in the app").
    //
    // The backend always rings (ring: true) so a minimized/killed callee gets
    // the native CallKit screen. But Stream's VoIP push handler reports the
    // call to CallKit even when the app is FOREGROUND, where we want only the
    // in-app overlay. We can't decide this on the backend (it can't know the
    // instant the user backgrounds) — but the DEVICE knows its own state with
    // zero lag. So we observe every call and, the moment an incoming screen
    // appears while the app is genuinely on screen, end it via
    // CXProvider.reportCall(endedAt:) — the only API that dismisses a
    // PushKit-reported incoming call (a CXEndCallAction does NOT). A
    // backgrounded/killed app is NOT foreground here, so its ring is kept.
    callObserver.setDelegate(self, queue: DispatchQueue.main)

    // Track genuine on-screen state via NotificationCenter (not by overriding
    // FlutterAppDelegate's lifecycle methods). didBecomeActive / didEnterBackground
    // are the ONLY transitions we trust: CallKit presenting over a foreground
    // app fires willResignActive → .inactive but NOT didEnterBackground, so
    // `isAppForeground` correctly stays true through a foreground ring.
    NotificationCenter.default.addObserver(
      self, selector: #selector(appDidBecomeActive),
      name: UIApplication.didBecomeActiveNotification, object: nil)
    NotificationCenter.default.addObserver(
      self, selector: #selector(appDidEnterBackground),
      name: UIApplication.didEnterBackgroundNotification, object: nil)

    // Dart-side safety-net channel (kept): lets the signaling layer also nudge
    // a dismiss for the rare group-call case where a foreground member is rung
    // alongside an offline one. Same reportCall path as the observer.
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
                plugin.saveEndCall(uuid, 6) // remoteEnded → reportCall(endedAt:)
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

  @objc private func appDidBecomeActive() { isAppForeground = true }
  @objc private func appDidEnterBackground() { isAppForeground = false }

  // ── CXCallObserverDelegate ───────────────────────────────────────────────
  func callObserver(_ callObserver: CXCallObserver, callChanged call: CXCall) {
    // Act only on a freshly-appeared INCOMING call (ringing — not outgoing,
    // not answered, not already ended). After we end it, hasEnded becomes true
    // and this guard skips the follow-up event (no loop).
    guard !call.isOutgoing, !call.hasConnected, !call.hasEnded else { return }
    // Suppress ONLY when the app is genuinely on screen. Background/killed must
    // keep the native ring — that's the entire point of CallKit there.
    guard isAppForeground else { return }
    guard let plugin = SwiftFlutterCallkitIncomingPlugin.sharedInstance else { return }
    // reason 6 → remoteEnded → CXProvider.reportCall(endedAt:) dismisses the
    // incoming UI (CXEndCallAction does not).
    plugin.saveEndCall(call.uuid.uuidString, 6)
  }
}
