import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:get_it/get_it.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/router/app_router.dart';
import '../entities/call_log.dart';
import '../presentation/pages/video_call_page.dart';
import '../presentation/pages/voice_call_page.dart';
import 'call_signaling_service.dart';
import 'repositories/conversations_repository.dart';
import 'stream_call_engine.dart';

/// Bridges `flutter_callkit_incoming` user actions (Accept / Reject)
/// into the call ceremony. Subscribes once at app start and stays
/// alive for the whole process — necessary because the user can hit
/// Accept on the native ringer at any moment, including after a
/// cold-start triggered by the tap itself.
///
/// On **Accept**: extracts the call CID from the CallKit event's
/// `extra` map, asks [StreamCallEngine.acceptByCid] to bring the
/// media leg up, and pushes the matching call page via the root
/// navigator so the user lands on the in-call screen.
///
/// On **Decline**: routes through [StreamCallEngine.rejectByCid] so
/// the caller gets the "declined" signal and the call log records
/// it as rejected.
///
/// Handles BOTH the minimize case (app alive, event arrives in
/// foreground process) AND the killed case (cold-start delivers the
/// event after [attach] subscribes during main()).
class CallkitEventHandler {
  CallkitEventHandler._();
  static final CallkitEventHandler instance = CallkitEventHandler._();

  StreamSubscription<CallEvent?>? _sub;
  bool _attached = false;

  /// Idempotent — safe to call from multiple bootstrap points.
  void attach() {
    if (_attached) return;
    _attached = true;
    _resubscribe();
    // Request the two Android-runtime permissions flutter_callkit_incoming
    // needs to render the proper full-screen ringer with Accept/Decline
    // buttons. Without these the plugin silently falls back to a plain
    // tray notification (no buttons) and the Accept event NEVER fires:
    //
    //   - POST_NOTIFICATIONS (Android 13+) — required for any notif to show
    //   - USE_FULL_SCREEN_INTENT (Android 14+) — required for the
    //     full-screen ring overlay. On 14+ this needs explicit user
    //     approval via Settings, not just a manifest declaration.
    //
    // Fire-and-forget: we want the prompt to show up on first launch
    // but app init must not block on it.
    unawaited(_requestCallkitPermissions());

    // Cold-start recovery. When the OS launches the app from a
    // CallKit Accept tap, the `actionCallAccept` event fires BEFORE
    // the Flutter isolate is alive — `onEvent` never sees it and
    // the call accept is silently dropped. Symptom: user taps Accept
    // on a killed/backgrounded app, the ringer dismisses, the app
    // opens to the home screen, no audio, no in-call page.
    //
    // Workaround: shortly after attach, query CallKit's own
    // `activeCalls()` — if there's still an entry there, the OS
    // believes the user accepted, so synthesise the accept ourselves.
    // Also schedule a Stream-side resync check at a longer delay,
    // since Stream's WS handshake takes a couple of seconds after a
    // cold start.
    Future.delayed(const Duration(seconds: 2), _maybeAcceptStaleCallkit);
    Future.delayed(
        const Duration(seconds: 5), _maybeAutoAcceptOnStreamResync);
  }

  Future<void> _requestCallkitPermissions() async {
    // Delay briefly so the first Activity is alive and can host the
    // system permission dialogs. Without this delay (firing during
    // main() before runApp), the prompts queue but never surface and
    // the user never sees them — which is exactly what was happening.
    await Future.delayed(const Duration(seconds: 1));

    // Step 1: POST_NOTIFICATIONS (Android 13+). Use permission_handler
    // directly — it's the standard runtime-permission request path
    // and reliably shows the system dialog.
    try {
      final status = await Permission.notification.status;
      // ignore: avoid_print
      print('[CallkitEventHandler] Notification permission '
          'status (before request)=$status');
      if (!status.isGranted) {
        final result = await Permission.notification.request();
        // ignore: avoid_print
        print('[CallkitEventHandler] Notification permission '
            'request result=$result');
      }
    } catch (e) {
      // ignore: avoid_print
      print('[CallkitEventHandler] notification permission error: $e');
    }

    // Step 2: USE_FULL_SCREEN_INTENT (Android 14+). NOT a normal
    // runtime permission — `canUseFullScreenIntent` returns false
    // until the user manually toggles a setting. The plugin's
    // `requestFullIntentPermission` opens the matching system
    // Settings page so the user can grant it with one tap.
    try {
      final canUse = await FlutterCallkitIncoming.canUseFullScreenIntent();
      // ignore: avoid_print
      print('[CallkitEventHandler] canUseFullScreenIntent=$canUse');
      if (canUse == false) {
        // ignore: avoid_print
        print('[CallkitEventHandler] opening Settings page for '
            'full-screen intent grant — user must toggle it on');
        await FlutterCallkitIncoming.requestFullIntentPermission();
      }
    } catch (e) {
      // ignore: avoid_print
      print('[CallkitEventHandler] fullScreenIntent check error: $e');
    }
  }

  /// Re-subscribe to the CallKit event channel. Used on app resume
  /// (when minimize → foreground may have caused the prior
  /// subscription to miss events). Called via [onAppResumed].
  void _resubscribe() {
    _sub?.cancel();
    // ignore: avoid_print
    print('[CallkitEventHandler] (re)subscribing to FlutterCallkitIncoming.onEvent');
    _sub = FlutterCallkitIncoming.onEvent.listen(
      (event) {
        // Trace EVERY event hitting the subscription so we can confirm
        // delivery. Print is unconditional so it fires in release too
        // while we triangulate the ring-not-accepted bug.
        // ignore: avoid_print
        print('[CallkitEventHandler] RAW event received: '
            'type=${event?.event} body=${event?.body}');
        _onEvent(event);
      },
      onError: (Object e, StackTrace s) {
        // ignore: avoid_print
        print('[CallkitEventHandler] subscription ERROR: $e\n$s');
      },
      onDone: () {
        // ignore: avoid_print
        print('[CallkitEventHandler] subscription CLOSED — events stop here');
      },
      cancelOnError: false,
    );
  }

  /// Called from `ChatLifecycleBridge` when the app comes back to
  /// foreground. The fix for the minimize→accept dead-event problem:
  /// `FlutterCallkitIncoming.onEvent` events fired while the app was
  /// backgrounded may not be delivered to our previous subscription.
  /// We:
  ///   1. Re-subscribe so a fresh stream handler is in place for any
  ///      buffered events the OS may now flush.
  ///   2. Check `activeCalls()` to detect if there's a CallKit call
  ///      the OS thinks we're in but our state doesn't know about
  ///      (means user tapped Accept and we missed the event).
  ///      Treat that as an implicit accept and route through.
  Future<void> onAppResumed() async {
    if (!_attached) return;
    _resubscribe();
    await _maybeAcceptStaleCallkit();
    // Fallback path B: if activeCalls() didn't surface the call
    // (Android's "content is null" quirk), wait for Stream's WS to
    // resync after warmUp and check for a pending incoming Stream
    // call. If one exists, the user almost certainly just tapped
    // Accept on the CallKit ringer — auto-accept it so they land
    // on the call page with audio flowing.
    Future.delayed(const Duration(seconds: 2), _maybeAutoAcceptOnStreamResync);
  }

  /// After the WS reconnects on resume, Stream's client should have
  /// the still-ringing call back in `state.incomingCall`. If it's
  /// there, treat the recent CallKit tap as an accept (because if
  /// the user had tapped Reject, the call would have been ended on
  /// Stream's side already via `rejectByCid` event).
  Future<void> _maybeAutoAcceptOnStreamResync() async {
    final engine = _safelyGet<StreamCallEngine>();
    if (engine == null) return;
    if (!engine.hasPendingIncoming) {
      // ignore: avoid_print
      print('[CallkitEventHandler] resync check: no pending Stream call');
      return;
    }
    final signaling = _safelyGet<CallSignalingService>();
    if (signaling == null) return;
    // If signaling already saw it via the WS bridge AND we're
    // already past incomingRinging (e.g. user accepted in-app), do
    // nothing.
    final active = signaling.current;
    if (active != null && active.state != CallSignalState.incomingRinging) {
      // ignore: avoid_print
      print('[CallkitEventHandler] resync check: active call already in '
          'state=${active.state}, skipping');
      return;
    }
    // ignore: avoid_print
    print('[CallkitEventHandler] resync check: pending Stream call found — '
        'auto-accepting (user must have tapped Accept on CallKit)');
    await signaling.acceptIncoming();
  }

  /// Inspect the plugin's `activeCalls()` to see if there's a call
  /// the OS thinks is connected but we never got the Accept event
  /// for. If so, this is the missed-event case — synthesize an
  /// Accept by treating the call as accepted (so audio + UI flow).
  ///
  /// Wrapped in try/catch because activeCalls() on Android has a
  /// known PlatformException("content is null") quirk when there
  /// are no calls — we just want to silently no-op on that.
  Future<void> _maybeAcceptStaleCallkit() async {
    try {
      final calls = await FlutterCallkitIncoming.activeCalls();
      // ALWAYS log so we can tell whether this path ran and what it
      // saw — without this, a silent return on "empty list" makes it
      // impossible to distinguish "ran but no call" from "didn't run".
      // ignore: avoid_print
      print('[CallkitEventHandler] activeCalls() returned: '
          'type=${calls.runtimeType} value=$calls');
      if (calls is! List || calls.isEmpty) {
        // ignore: avoid_print
        print('[CallkitEventHandler] no active CallKit call — '
            'nothing to recover (this is expected if user opened the '
            'app outside a call, or if the OS already cleared the '
            'CallKit entry)');
        return;
      }
      final first = calls.first;
      if (first is! Map) {
        // ignore: avoid_print
        print('[CallkitEventHandler] active call entry is not a Map: '
            '${first.runtimeType}');
        return;
      }
      // ignore: avoid_print
      print('[CallkitEventHandler] resume: stale CallKit call detected → $first');
      await _handleAccept(first);
    } catch (e) {
      // PlatformException("content is null") = no active calls.
      // ignore: avoid_print
      print('[CallkitEventHandler] resume: no stale call to recover ($e)');
    }
  }

  Future<void> detach() async {
    await _sub?.cancel();
    _sub = null;
    _attached = false;
  }

  Future<void> _onEvent(CallEvent? event) async {
    if (event == null) return;
    // ignore: avoid_print
    print('[CallkitEventHandler] event=${event.event} body=${event.body}');
    switch (event.event) {
      case Event.actionCallAccept:
        await _handleAccept(event.body);
      case Event.actionCallDecline:
        await _handleDecline(event.body);
      case Event.actionCallEnded:
      case Event.actionCallTimeout:
        await _handleDecline(event.body);
      default:
        // Ignore lifecycle/diagnostic events (incoming/start/etc.) —
        // they're informational only.
        break;
    }
  }

  Future<void> _handleAccept(dynamic body) async {
    // ignore: avoid_print
    print('[CallkitEventHandler] _handleAccept ENTER · body=$body');
    final params = _params(body);
    final callCid = params['call_cid']?.toString() ?? params['id']?.toString();
    if (callCid == null || callCid.isEmpty) {
      // ignore: avoid_print
      print('[CallkitEventHandler] _handleAccept BAIL · missing call_cid');
      return;
    }
    final isVideo = (params['type']?.toString() == '1');
    final signaling = _safelyGet<CallSignalingService>();
    final callerId = params['caller_id']?.toString() ?? '';
    final callerName = params['caller_name']?.toString() ?? callerId;
    // ignore: avoid_print
    print('[CallkitEventHandler] _handleAccept · '
        'callCid=$callCid · callerId=$callerId · callerName=$callerName · '
        'isVideo=$isVideo · signaling=${signaling != null}');

    // Resolve the LOCAL conversation id (not Stream's call CID) so
    // the call page's `ConversationsRepository.watchById(...)` finds
    // the real entity → caller name + avatar render correctly. Falls
    // back to the CID only if the lookup fails.
    String resolvedConvId = callCid;
    final conversations = _safelyGet<ConversationsRepository>();
    if (conversations != null && callerId.isNotEmpty) {
      try {
        final direct = await conversations.findDirectWith(callerId);
        if (direct != null) resolvedConvId = direct.id;
      } catch (_) {/* fall through to CID */}
    }
    // ignore: avoid_print
    print('[CallkitEventHandler] _handleAccept · resolvedConvId=$resolvedConvId');

    // 1) Seed signaling state FIRST so the call page mounts with an
    //    ActiveCall already in place — no overlay flash. State is
    //    `incomingRinging` momentarily; acceptIncoming below flips it
    //    to `connected`.
    if (signaling != null && callerId.isNotEmpty) {
      final payload = <String, dynamic>{
        'type': 'call.invite',
        'callId': _parseBackendCallId(callCid),
        'conversationId': resolvedConvId,
        'callerId': callerId,
        'callerName': callerName,
        'callType': isVideo ? 'video' : 'voice',
        'startedAt': DateTime.now().toUtc().toIso8601String(),
        'streamCallCid': callCid,
      };
      // ignore: avoid_print
      print('[CallkitEventHandler] step 1 → handleIncomingFromPush');
      await signaling.handleIncomingFromPush(payload);
    }

    // 2) Push the call page with the RESOLVED conv id so the page
    //    can render the caller's name + avatar from the local conv.
    //    On cold start the navigator key may briefly be null while
    //    MaterialApp.router is still building. Retry a few times
    //    (40 ms × 25 = 1 s total) before giving up — without this,
    //    the user lands on the home screen with audio flowing but
    //    no in-call UI ("Accept didn't work" from their POV).
    await _pushCallPageWithRetry(
      isVideo: isVideo,
      conversationId: resolvedConvId,
    );

    // 3) Run the full accept flow — POSTs to our backend's
    //    `/chats/calls/{id}/accept` AND calls `streamEngine.join`
    //    which does Stream's `accept()` + `join()`. This transitions
    //    ActiveCall to `connected`, collapses any overlay, audio
    //    starts flowing.
    if (signaling != null) {
      // ignore: avoid_print
      print('[CallkitEventHandler] step 3 → signaling.acceptIncoming()');
      await signaling.acceptIncoming();
      // ignore: avoid_print
      print('[CallkitEventHandler] step 3 done · '
          'active.state=${signaling.current?.state}');
    } else {
      final engine = _safelyGet<StreamCallEngine>();
      if (engine != null) {
        // ignore: avoid_print
        print('[CallkitEventHandler] step 3 fallback → engine.acceptByCid');
        await engine.acceptByCid(callCid: callCid, isVideo: isVideo);
      }
    }
    // ignore: avoid_print
    print('[CallkitEventHandler] _handleAccept EXIT');
  }

  Future<void> _handleDecline(dynamic body) async {
    final params = _params(body);
    final callCid = params['call_cid']?.toString() ?? params['id']?.toString();
    if (callCid == null || callCid.isEmpty) return;
    final callerId = params['caller_id']?.toString() ?? '';
    final callerName = params['caller_name']?.toString() ?? callerId;
    final isVideo = (params['type']?.toString() == '1');

    // ignore: avoid_print
    print('[CallkitEventHandler] decline: callCid=$callCid');

    // 1) Tell Stream we're declining the ringing call. Uses a fresh
    //    Call reference + `.reject()` so the caller sees a "declined"
    //    signal immediately (without waiting for the ring timeout).
    final engine = _safelyGet<StreamCallEngine>();
    if (engine != null) {
      await engine.rejectByCid(callCid: callCid);
    }

    // 2) Tell our backend via /chats/calls/{id}/reject. This requires
    //    `_active` to be set — seed it first if needed (the user may
    //    have hit Decline without ever opening the in-app overlay, so
    //    no prior path populated _active). Lookup the local conv id
    //    too so the call-log entry attaches to the right conversation.
    final signaling = _safelyGet<CallSignalingService>();
    if (signaling == null || callerId.isEmpty) return;
    if (signaling.current == null) {
      String resolvedConvId = callCid;
      final conversations = _safelyGet<ConversationsRepository>();
      if (conversations != null) {
        try {
          final direct = await conversations.findDirectWith(callerId);
          if (direct != null) resolvedConvId = direct.id;
        } catch (_) {/* ignore */}
      }
      final payload = <String, dynamic>{
        'type': 'call.invite',
        'callId': _parseBackendCallId(callCid),
        'conversationId': resolvedConvId,
        'callerId': callerId,
        'callerName': callerName,
        'callType': isVideo ? 'video' : 'voice',
        'startedAt': DateTime.now().toUtc().toIso8601String(),
        'streamCallCid': callCid,
      };
      await signaling.handleIncomingFromPush(payload);
    }
    await signaling.rejectIncoming();
  }

  /// Push the in-call page onto the root navigator, retrying briefly
  /// if the navigator key isn't attached yet (happens on cold start
  /// when this fires before `MaterialApp.router` has finished its
  /// first build). 40 ms × 25 = 1 s total ceiling — well under the
  /// time it takes a user to notice the missing UI.
  Future<void> _pushCallPageWithRetry({
    required bool isVideo,
    required String conversationId,
  }) async {
    for (var attempt = 0; attempt < 25; attempt++) {
      final navigator = AppRouter.rootNavigatorKey.currentState;
      if (navigator != null) {
        // ignore: avoid_print
        print('[CallkitEventHandler] step 2 → pushing '
            '${isVideo ? "VideoCallPage" : "VoiceCallPage"}'
            '(conversationId=$conversationId) on attempt ${attempt + 1}');
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => isVideo
                ? VideoCallPage(conversationId: conversationId)
                : VoiceCallPage(conversationId: conversationId),
            fullscreenDialog: true,
          ),
        );
        return;
      }
      await Future.delayed(const Duration(milliseconds: 40));
    }
    // ignore: avoid_print
    print('[CallkitEventHandler] step 2 GAVE UP → root navigator '
        'never came up after 1 s — call audio may flow but user is '
        'stuck on whatever screen was visible at cold start');
  }

  /// CallKit event body is `Map` on Android / iOS — wraps params we
  /// passed via `CallKitParams.extra` plus the call id under top-level
  /// keys. Defensive accessor — returns empty map on any oddity.
  Map<dynamic, dynamic> _params(dynamic body) {
    if (body is Map) {
      // Common shape: {id, nameCaller, extra: {call_cid: ..., ...}}
      final extra = body['extra'];
      if (extra is Map) {
        return {...body, ...extra};
      }
      return body;
    }
    return const <String, dynamic>{};
  }

  /// Extract backend numeric id from Stream's CID format
  /// (e.g. `default:erp-call-42` → `42`). Falls back to the CID
  /// verbatim if the format doesn't match.
  String _parseBackendCallId(String callCid) {
    final id = callCid.contains(':') ? callCid.split(':').last : callCid;
    final match = RegExp(r'^(?:erp-call-)?(\d+)').firstMatch(id);
    return match?.group(1) ?? id;
  }

  /// `GetIt.I<T>()` throws if not yet registered (rare on cold-start
  /// from CallKit). Log + skip rather than crash on the event handler.
  T? _safelyGet<T extends Object>() {
    try {
      return GetIt.I<T>();
    } catch (_) {
      return null;
    }
  }
}

// ChatCallType is referenced via the existing entities/call_log.dart
// only to keep import lists tidy; the handler itself doesn't reach
// for its enum members directly.
// ignore: unused_element
ChatCallType? _unusedTypeAnchor() => null;
