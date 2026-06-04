import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:erp_mobile/features/chat/models/call_log_model.dart';
import 'package:erp_mobile/data/services/call_signaling_service.dart';
import 'package:erp_mobile/data/services/callkit_event_handler.dart';
import 'package:erp_mobile/data/services/chat_settings.dart';
import 'package:erp_mobile/data/services/chat_transport.dart';
import 'package:erp_mobile/data/repositories/presence_repository.dart';
import 'package:erp_mobile/data/services/stream_call_engine.dart';

/// Slice 10.2.6 — keeps [ChatTransport] in sync with the app's
/// foreground / background lifecycle.
///
/// **What this fixes:**
/// - Android / iOS routinely suspend long-lived TCP sockets when the
///   app is backgrounded; the OS may keep them alive for a few minutes
///   but typically not longer. When the user returns to the app the
///   socket can be silently dead, so the auto-reconnect needs a kick.
/// - Some manufacturer ROMs throttle networking aggressively in the
///   background, which can drop call invites that arrive during that
///   window. Forcing a reconnect on `resumed` makes sure we catch the
///   missed-call rows the next time the transport syncs.
///
/// **What this CANNOT fix (and the killed-app honesty note):**
/// The WebSocket relay is a local-LAN demo. When the OS terminates
/// the app process (force-stop, low memory kill, swipe-away on some
/// devices) the socket is gone and there is no background service to
/// re-open it. A peer's `call.invite` envelope hits nobody and the
/// log row stays in `noAnswer` / `missed` forever. The production
/// path for this is FCM / APNs push: a backend wakes the device with
/// a high-priority push, which spins up a background isolate that
/// shows the incoming call sheet via `flutter_local_notifications`.
/// None of that is wired here — see CLAUDE.md slice 10.2.6.
class ChatLifecycleBridge with WidgetsBindingObserver {
  ChatLifecycleBridge({
    required this.transport,
    required this.settings,
    required this.presence,
    required this.streamEngine,
    required this.signaling,
  });

  final ChatTransport transport;
  final ChatSettings settings;
  final PresenceRepository presence;
  final StreamCallEngine streamEngine;
  final CallSignalingService signaling;

  void attach() {
    WidgetsBinding.instance.addObserver(this);
  }

  void detach() {
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.detached:
        // Process is about to die (user swiped from recents / OS
        // low-memory kill / Force Stop). End any in-flight call
        // FIRST so audio doesn't leak past the app and the peer
        // gets a clean hangup envelope instead of an unexplained
        // disconnect. detached is best-effort — Android sometimes
        // skips it under aggressive task removal, in which case
        // Stream's own 60 s ring timer will eventually catch up,
        // but for the common path this is what stops "phone keeps
        // ringing on A after B killed the app" cleanly.
        final active = signaling.current;
        if (active != null &&
            active.state == CallSignalState.connected) {
          // ignore: avoid_print
          print('[ChatLifecycle] detached during active call '
              '${active.callId} — hanging up before process death');
          // Fire-and-forget: the await won't complete because the
          // isolate is shutting down, but the wire call is queued
          // and Dio will flush it before the OS reclaims the
          // process in most cases. Same for streamEngine.leave().
          unawaited(signaling.hangup(
            finalStatus: ChatCallStatus.answered,
          ));
        }
        transport.pause();
        streamEngine.disconnectForBackground();
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        // Explicitly drop the STOMP socket so the backend's
        // heartbeat detects the disconnect immediately and fans
        // `presence.update {status: OFFLINE, lastSeenAt: now}` to
        // every peer's `/topic/presence`. Without this, the OS would
        // keep the TCP socket alive for minutes after minimise — so
        // peers would keep seeing us as Online instead of Away (the
        // 5-min effectiveStatus heuristic on the receiver maps a
        // fresh-OFFLINE to AWAY for the right amber-dot rendering).
        transport.pause();
        // ALSO drop Stream's WebSocket so the SDK's coordinator marks
        // this client offline. Stream prefers WS over FCM when it
        // thinks a client is online — if we leave the WS up while
        // backgrounded, Stream pushes the incoming-call event over
        // WS only, our in-app overlay can't render (app not visible),
        // and the native ringer never fires. Dropping the WS makes
        // Stream fall back to FCM, which `flutter_callkit_incoming`
        // renders as a native full-screen ringer.
        //
        // No-op when there's an active call (would kill audio mid-
        // conversation; the engine itself enforces that guard) —
        // standard calling-app behaviour: minimize keeps the call
        // alive so the user can multitask while talking.
        streamEngine.disconnectForBackground();
      case AppLifecycleState.resumed:
        // Re-open the socket so we're Online again. Once connected
        // our presence flips back to ONLINE server-side and peers'
        // dots turn green.
        transport.resume();
        // Re-hydrate presence: the broker may have advanced while we
        // were backgrounded, and `/topic/presence` only delivers
        // deltas (not the current snapshot) once we reconnect.
        presence.loadAll();
        // Re-warm Stream so incoming-call events flow over the live
        // WS path again while we're in foreground. Idempotent.
        streamEngine.warmUp();
        // Re-subscribe + check for any pending CallKit accept that
        // fired while we were backgrounded. The plugin's onEvent
        // stream drops events while the app's main isolate is paused,
        // so the user tapping Accept on the native ringer may have
        // brought us back to foreground without us catching the
        // Accept event. This re-runs the subscription and queries
        // `activeCalls()` to recover from that.
        CallkitEventHandler.instance.onAppResumed();
      case AppLifecycleState.inactive:
        // Brief transition (incoming call sheet, control-center on
        // iOS, etc.) — don't tear the socket down here, the user
        // hasn't actually backgrounded us.
        break;
    }
  }
}
