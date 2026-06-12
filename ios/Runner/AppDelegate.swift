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

  // The Dart-side method channel (`erp/ios_callkit`). Kept as a property so
  // the CXCallObserver can push a native→Dart `incomingCallAnswered` event
  // (see callObserver below). nil until the FlutterViewController is ready.
  private var callkitChannel: FlutterMethodChannel?

  // UUIDs we've already reported as answered, so the CXCallObserver (which
  // fires repeatedly for one call) drives the Dart accept flow only once.
  private var answeredCallUUIDs = Set<String>()

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
      callkitChannel = channel
      channel.setMethodCallHandler { (call, result) in
        switch call.method {
        case "isDeviceUnlocked":
          // Lock-state probe used by the Dart CallKit-suppression sweep.
          // `isProtectedDataAvailable` is true when the device is unlocked
          // and false once it locks (passcode devices). The sweep dismisses
          // the native CallKit ONLY when unlocked — on a locked accept the
          // native CallKit is the only call UI iOS permits on the lock
          // screen, so we must NOT dismiss it there. Defaults handled on the
          // Dart side. Public API; read-only; nothing else changes.
          result(UIApplication.shared.isProtectedDataAvailable)
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
    // INCOMING call just became CONNECTED = the user tapped Accept on the
    // native CallKit screen (lock screen / minimized / killed cold-start).
    // This is the ONLY reliable, timing-independent signal for that accept:
    // on a killed/locked cold-start the flutter_callkit_incoming
    // `actionCallAccept` event is missed (the Dart isolate/subscription
    // isn't ready when it fires) and Stream's native push handler consumes
    // the call before Dart's resync runs — so nothing tells OUR backend the
    // callee answered, and the CALLER stays stuck on "Calling…". Bridge it
    // to Dart, which runs the normal accept flow (POST /accept → the backend
    // re-broadcasts call.accept so the caller connects, + joins the Stream
    // media leg). Only when NOT genuinely foreground — a foreground accept
    // goes through the in-app overlay/signaling directly, and the native
    // ring is suppressed below so it never reaches `hasConnected` there.
    if !call.isOutgoing, call.hasConnected, !call.hasEnded {
      if !isAppForeground {
        let uuid = call.uuid.uuidString
        if !answeredCallUUIDs.contains(uuid), callkitChannel != nil {
          answeredCallUUIDs.insert(uuid)
          notifyIncomingCallAnswered(uuid: uuid)
        }
      }
      return
    }
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

  /// Push a native→Dart `incomingCallAnswered` event for a CallKit call the
  /// user just answered. Looks up the matching flutter_callkit_incoming
  /// entry (which carries the Stream cid under `extra.callCid`) so the Dart
  /// side has everything `_handleAccept` needs; falls back to the bare UUID
  /// if the entry isn't found. Runs on the observer's main queue.
  private func notifyIncomingCallAnswered(uuid: String) {
    var payload: [String: Any] = ["uuid": uuid]
    if let plugin = SwiftFlutterCallkitIncomingPlugin.sharedInstance {
      let calls = plugin.activeCalls()
      for c in calls {
        let entryId = (c["id"] as? String) ?? (c["uuid"] as? String) ?? ""
        if entryId == uuid {
          payload["call"] = c
          break
        }
      }
    }
    callkitChannel?.invokeMethod("incomingCallAnswered", arguments: payload)
  }
}
