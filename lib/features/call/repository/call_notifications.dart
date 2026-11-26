import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../model/call_push.dart';

/// The Android "incoming call" notification (Step 7.2): what rings the phone
/// when the app is minimized or killed.
///
/// ```
/// ┌──────────────────────────────────────┐
/// │ 📞 Mr Min                             │  full-screen over the lock screen,
/// │ Incoming voice call                   │  heads-up when unlocked, rings
/// │        [ Decline ]   [ Answer ]       │  (system ringtone, loops) ≤ 60 s
/// └──────────────────────────────────────┘
/// ```
/// Decline → [backgroundActionDecline] runs in a background isolate (even
/// when the app is killed) → `POST /calls/{id}/reject`.
/// Answer / tap → opens the app on the incoming call screen.
///
/// Works in ANY isolate (the FCM background handler uses it too): no DI.
class CallNotifications with WidgetsBindingObserver {
  CallNotifications({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  static const String channelId = 'calls_ringing';
  static const String actionDecline = 'decline';
  static const String actionAnswer = 'answer';

  /// The server gives up after 60 s → so does the notification.
  static const Duration ringTimeout = Duration(seconds: 60);

  /// Android's FLAG_INSISTENT: the sound repeats until it's gone.
  static const int _flagInsistent = 4;

  /// The call ringing as a notification while the bloc shows it too.
  String? _ringingCallId;

  void Function(String callId, {required bool answer})? _onOpen;

  /// One int per call (Android notification ids are ints).
  static int notificationId(String callId) =>
      (int.tryParse(callId) ?? callId.hashCode) & 0x7fffffff;

  /// This class is Android only: iOS rings through CallKit (7.3), and the
  /// plugin CRASHES on iOS without iOS settings. So on iOS every method
  /// does nothing.
  static bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Set up the plugin. [onOpen] = the user tapped the notification or
  /// Answer (main isolate); [onBackgroundAction] = a TOP-LEVEL function for
  /// Decline when the app isn't running.
  Future<void> init({
    void Function(String callId, {required bool answer})? onOpen,
    void Function(String callId)? onDecline,
    DidReceiveBackgroundNotificationResponseCallback? onBackgroundAction,
  }) async {
    if (!_android) return;
    _onOpen = onOpen;
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/launcher_icon'),
      ),
      onDidReceiveNotificationResponse: (r) {
        final callId = callIdOf(r.payload);
        if (callId == null) return;
        if (r.actionId == actionDecline) {
          onDecline?.call(callId); // app running → the bloc declines
        } else {
          onOpen?.call(callId, answer: r.actionId == actionAnswer);
        }
      },
      onDidReceiveBackgroundNotificationResponse: onBackgroundAction,
    );
  }

  /// Start following the app: back to the front → the app shows the call
  /// itself, so the notification stops ringing.
  void attach() {
    if (_android) WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final id = _ringingCallId;
    if (id != null) {
      cancel(id); // the app's own screen + ringtone take over
    } else {
      // opened from the launcher while a call notification rings
      ringingNow().then((ringing) {
        if (ringing != null) _onOpen?.call(ringing, answer: false);
      });
    }
  }

  /// The bloc tells us when a call rings / stops ringing on screen.
  void onIncoming(String? callId) {
    if (!_android) return;
    final old = _ringingCallId;
    if (old != null && old != callId) cancel(old); // answered / ended
    _ringingCallId = callId;
    final appOpen =
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    if (callId != null && appOpen) cancel(callId); // the app rings instead
  }

  /// Ring (Android only; iOS rings through CallKit in 7.3).
  Future<void> showIncoming(CallPushInvite invite) async {
    if (!_android) return;
    final kind = invite.video ? 'video' : 'voice';
    await _plugin.show(
      notificationId(invite.callId),
      invite.callerName.isEmpty ? 'Incoming call' : invite.callerName,
      'Incoming $kind call',
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          'Incoming calls',
          channelDescription: 'Rings when someone calls you.',
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.call,
          fullScreenIntent: true, // over the lock screen
          ongoing: true, // can't be swiped away while ringing
          autoCancel: false,
          visibility: NotificationVisibility.public,
          timeoutAfter: ringTimeout.inMilliseconds,
          audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
          sound: const UriAndroidNotificationSound(
            'content://settings/system/ringtone',
          ),
          additionalFlags: Int32List.fromList([_flagInsistent]),
          actions: const [
            AndroidNotificationAction(
              actionDecline,
              'Decline',
              cancelNotification: true,
            ),
            AndroidNotificationAction(
              actionAnswer,
              'Answer',
              showsUserInterface: true, // opens the app
              cancelNotification: true,
            ),
          ],
        ),
      ),
      payload: jsonEncode({'callId': invite.callId}),
    );
  }

  /// Stop ringing for [callId] (cancel push, answered, declined, ended).
  Future<void> cancel(String callId) async {
    if (!_android) return;
    try {
      await _plugin.cancel(notificationId(callId));
    } catch (_) {}
  }

  /// The app was STARTED by tapping a call notification / Answer → its call
  /// id (and whether it was Answer), else null.
  Future<({String callId, bool answer})?> launchedFrom() async {
    if (!_android) return null;
    final details = await _plugin.getNotificationAppLaunchDetails();
    final r = details?.notificationResponse;
    if (details?.didNotificationLaunchApp != true || r == null) return null;
    final callId = callIdOf(r.payload);
    if (callId == null || r.actionId == actionDecline) return null;
    return (callId: callId, answer: r.actionId == actionAnswer);
  }

  /// A call notification still on screen (the app was opened from the
  /// launcher while it rang) → its call id.
  Future<String?> ringingNow() async {
    if (!_android) return null;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final active = await android?.getActiveNotifications() ?? const [];
    for (final n in active) {
      if (n.channelId == channelId) return callIdOf(n.payload);
    }
    return null;
  }

  static String? callIdOf(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final id = (jsonDecode(payload) as Map<String, dynamic>)['callId'];
      return id == null ? null : '$id';
    } catch (_) {
      return null;
    }
  }
}
