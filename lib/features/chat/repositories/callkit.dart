import 'dart:async';

import 'package:stream_video_flutter/stream_video_flutter.dart' as sv;
// `RingingEventBroadcaster` is the one shared listener on Stream's native
// ringing event channel. It isn't exported, but a second listener on the
// same EventChannel would replace Stream's own (one native sink per channel).
// ignore: implementation_imports
import 'package:stream_video_push_notification/src/stream_video_push_notification.dart'
    show RingingEventBroadcaster;
import 'package:stream_video_push_notification/stream_video_push_notification.dart';
import 'package:stream_video_push_notification/stream_video_push_notification_platform_interface.dart';

/// The native call UI (CallKit on iOS, the full-screen ringer on Android).
///
/// `stream_video_push_notification` 1.x replaced `flutter_callkit_incoming`
/// with Stream's own native code (same events, same `id` / `extra` keys).
/// This keeps the old `FlutterCallkitIncoming` shape so the call code didn't
/// have to change: [onEvent] gives `{event, body}` with the body keys the
/// handlers already read (`id`, `nameCaller`, `handle`, `type`, `extra`,
/// `isAccepted`, `isActivate`).
class CallKit {
  CallKit._();

  static StreamVideoPushNotificationPlatform get _native =>
      StreamVideoPushNotificationPlatform.instance;

  /// User actions on the native call UI (accept / decline / ended / …).
  static Stream<CallEvent?> get onEvent =>
      RingingEventBroadcaster().onEvent.map(_toCallEvent);

  /// Show the native incoming-call UI.
  static Future<void> showCallkitIncoming(StreamVideoPushParams params) =>
      _native.showIncomingCall(params);

  /// End one native call by its id (the CallKit UUID on iOS).
  static Future<void> endCall(String id) => _native.endCall(id);

  static Future<void> endAllCalls() => _native.endAllCalls();

  /// Native calls still shown, as `{id, nameCaller, handle, type, extra,
  /// isAccepted, …}` maps (same as `flutter_callkit_incoming`).
  static Future<dynamic> activeCalls() async {
    final raw = await _native.activeCalls();
    if (raw is! List) return const <dynamic>[];
    return [
      for (final c in raw)
        if (c is Map) _withOldKeys(Map<String, dynamic>.from(c)),
    ];
  }

  /// iOS VoIP push token ('' on Android).
  static Future<dynamic> getDevicePushTokenVoIP() =>
      _native.getDevicePushTokenVoIP();

  /// Android 14+: may this app show full-screen call UI on the lock screen?
  static Future<bool> canUseFullScreenIntent() =>
      _native.canUseFullScreenIntent();

  /// Android 14+: open the settings page for the full-screen permission.
  static Future<void> requestFullIntentPermission() =>
      _native.ensureFullScreenIntentPermission();

  static Map<String, dynamic> _withOldKeys(Map<String, dynamic> m) => {
        ...m,
        if (m['callerName'] != null) 'nameCaller': m['callerName'],
      };

  static CallEvent _toCallEvent(sv.RingingEvent e) {
    Map<String, dynamic> call(sv.CallData d, {Map<String, dynamic>? more}) => {
          'id': d.uuid,
          'nameCaller': d.callerName,
          'callerName': d.callerName,
          'handle': d.handle,
          'avatar': d.avatar,
          'type': d.hasVideo == true ? 1 : 0,
          'isAccepted': d.isAccepted,
          'extra': <String, dynamic>{
            ...?d.extraData,
            if (d.callCid != null) 'callCid': d.callCid,
          },
          ...?more,
        };
    return switch (e) {
      sv.ActionCallIncoming(:final data) =>
        CallEvent(Event.actionCallIncoming, call(data)),
      sv.ActionCallIncomingFailed(:final data, :final error) =>
        CallEvent(Event.actionCallIncomingFailed,
            call(data, more: {'error': error})),
      sv.ActionCallStart(:final data) =>
        CallEvent(Event.actionCallStart, call(data)),
      sv.ActionCallAccept(:final data) =>
        CallEvent(Event.actionCallAccept, call(data)),
      sv.ActionCallDecline(:final data) =>
        CallEvent(Event.actionCallDecline, call(data)),
      sv.ActionCallEnded(:final data) =>
        CallEvent(Event.actionCallEnded, call(data)),
      sv.ActionCallTimeout(:final data) =>
        CallEvent(Event.actionCallTimeout, call(data)),
      sv.ActionCallCallback(:final data) =>
        CallEvent(Event.actionCallCallback, call(data)),
      sv.ActionCallConnected(:final data) =>
        CallEvent(Event.actionCallConnected, call(data)),
      sv.ActionDidUpdateDevicePushTokenVoip(:final token) => CallEvent(
          Event.actionDidUpdateDevicePushTokenVoip, {'deviceTokenVoIP': token}),
      sv.ActionCallToggleHold(:final uuid, :final isOnHold) => CallEvent(
          Event.actionCallToggleHold, {'id': uuid, 'isOnHold': isOnHold}),
      sv.ActionCallToggleMute(:final uuid, :final isMuted) => CallEvent(
          Event.actionCallToggleMute, {'id': uuid, 'isMuted': isMuted}),
      sv.ActionCallToggleDtmf(:final uuid, :final digits) => CallEvent(
          Event.actionCallToggleDtmf, {'id': uuid, 'digits': digits}),
      sv.ActionCallToggleGroup(:final uuid, :final callUUIDToGroupWith) =>
        CallEvent(Event.actionCallToggleGroup,
            {'id': uuid, 'callUUIDToGroupWith': callUUIDToGroupWith}),
      sv.ActionCallToggleAudioSession(:final isActive) => CallEvent(
          Event.actionCallToggleAudioSession,
          {'isActivate': isActive, 'isActive': isActive}),
      sv.ActionCallCustom(:final body) =>
        CallEvent(Event.actionCallCustom, {...?body}),
    };
  }
}

/// A native call UI event (same shape as `flutter_callkit_incoming`).
class CallEvent {
  const CallEvent(this.event, this.body);

  final Event event;
  final dynamic body;

  @override
  String toString() => 'CallEvent(event: $event, body: $body)';
}

/// Native call UI event types (same names as `flutter_callkit_incoming`).
enum Event {
  actionDidUpdateDevicePushTokenVoip,
  actionCallIncoming,
  actionCallIncomingFailed,
  actionCallStart,
  actionCallAccept,
  actionCallDecline,
  actionCallEnded,
  actionCallTimeout,
  actionCallConnected,
  actionCallCallback,
  actionCallToggleHold,
  actionCallToggleMute,
  actionCallToggleDtmf,
  actionCallToggleGroup,
  actionCallToggleAudioSession,
  actionCallCustom,
}
