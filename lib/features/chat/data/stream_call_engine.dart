import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';
import 'package:stream_video_push_notification/stream_video_push_notification.dart';

import 'chats_remote_data_source.dart';
import 'users_cache.dart';

/// Thin wrapper around `stream_video_flutter` so the rest of the
/// chat module doesn't import the SDK directly. Exposes just three
/// operations: lazy [_ensureClient] (one client per process), [join]
/// (called after our REST POST has produced a `streamCallCid`), and
/// [leave] (called on every end-of-call path).
///
/// Failures are deliberately swallowed — call media is best-effort
/// on top of the chat ceremony. If Stream is unreachable we still
/// want the signalling state machine, timers, and call logs to
/// behave correctly so the user can hang up cleanly.
class StreamCallEngine {
  StreamCallEngine({required this.remote});

  final ChatsRemoteDataSource remote;

  StreamVideo? _client;
  Call? _activeCall;

  /// Cached identity used to bring the client up. We re-fetch the
  /// token if [_clientUserId] doesn't match the one we're being asked
  /// to join as (rare: sign-out → sign-in mid-session).
  String? _clientUserId;

  /// Live handle to the currently-joined Stream [Call] (or null when
  /// idle). The voice/video pages listen to this so they can mount a
  /// [StreamCallParticipants] / video renderer the instant Stream
  /// finishes its join — without it, the UI sits on the placeholder
  /// avatar forever even though the media leg is healthy.
  final ValueNotifier<Call?> callNotifier = ValueNotifier<Call?>(null);

  /// Fires every time Stream pushes a new incoming-call event over
  /// the live WebSocket (i.e. when B is FOREGROUNDED and A initiates
  /// a call with `ring=true`). The native CallKit ringer only fires
  /// for backgrounded/killed apps — for foreground, Stream just sets
  /// `client.state.incomingCall` and expects the app to render its
  /// own incoming-call UI.
  ///
  /// `CallSignalingService` subscribes to this and forwards the data
  /// into `handleIncomingFromPush(...)` so the existing
  /// `IncomingCallOverlay` (the Flutter widget that paints the in-app
  /// Accept/Reject sheet) lights up.
  Stream<Call> get onStreamIncomingCall => _incomingCallController.stream;
  final StreamController<Call> _incomingCallController =
      StreamController<Call>.broadcast();
  StreamSubscription<Call?>? _incomingCallSub;

  /// Pending incoming Stream Call — the one currently ringing. We keep
  /// a reference because Stream needs us to call `accept()` / `reject()`
  /// on the SAME object that fired in `state.incomingCall`. Creating a
  /// new Call via `client.makeCall(id)` and joining it would bypass
  /// Stream's ringing-acceptance flow → no audio.
  Call? _pendingIncomingCall;

  /// True when there's a Stream incoming Call awaiting accept/reject.
  /// Signaling layer uses this to decide between
  /// `acceptPendingIncoming()` (preserves ringing acceptance, audio
  /// flows) and a fresh `join()` (FCM-push fallback path).
  bool get hasPendingIncoming => _pendingIncomingCall != null;

  /// Fires when Stream signals the active call has ended (caller hung
  /// up before callee answered, peer left, etc.). The signaling layer
  /// subscribes so it can pop the local UI even when the end event
  /// came from Stream instead of our STOMP/REST backend.
  Stream<void> get onStreamCallEnded => _callEndedController.stream;
  final StreamController<void> _callEndedController =
      StreamController<void>.broadcast();
  StreamSubscription<CallState>? _activeStateSub;

  /// Join the media leg of the call carried by [streamCallCid]
  /// (e.g. `default:abc123`). The chat ceremony is responsible for
  /// reaching the "connected" state BEFORE this is called — Stream
  /// is just the audio/video pipe under it.
  ///
  /// No-op when [streamCallCid] is null/empty (backend hasn't shipped
  /// Stream integration for this call) or the token endpoint fails.
  Future<void> join({
    required String streamCallCid,
    required bool isVideo,
    // ── Stream ring-on-call wiring ───────────────────────────────
    // [calleeUserIds]: Stream user ids of everyone we want the SDK
    //   to RING when this call is created. Empty list means caller-
    //   only (no push will fire on anyone else). For a 1:1 call
    //   from A→B, pass `['10']`. For a group, pass every other
    //   participant.
    // [shouldRing]: true on the caller's side (we want Stream to
    //   broadcast the VoIP notification); false on the callee's
    //   side (we're just joining a call that already rang us).
    //   Defaults to true because the only caller of this method
    //   today is the outgoing-call path.
    List<String> calleeUserIds = const [],
    bool shouldRing = true,
  }) async {
    if (streamCallCid.isEmpty) return;
    try {
      await _ensureClient();
      final client = _client;
      if (client == null) return;

      // CID is `type:id` — split and feed both halves to the SDK.
      // Tolerant of a missing `:` (treat the whole string as the id
      // and use the default call type).
      final parts = streamCallCid.split(':');
      final callType = parts.length > 1 ? parts[0] : 'default';
      final callId = parts.length > 1 ? parts[1] : streamCallCid;

      final call = client.makeCall(
        callType: StreamCallType.fromString(callType),
        id: callId,
      );
      // `ringing: true` tells Stream to push the VoIP notification to
      // every `memberId` — that's what lights up the full-screen
      // ringer on the callees' phones via the SDK's native
      // PushNotificationManager. Without this, Stream creates the
      // call silently and nobody else's phone ever rings.
      // ignore: avoid_print
      print('[StreamCallEngine] getOrCreate(callId=$callId, '
          'members=$calleeUserIds, ringing=$shouldRing)');
      await call.getOrCreate(
        memberIds: calleeUserIds,
        ringing: shouldRing,
        video: isVideo,
      );
      await call.join(
        connectOptions: CallConnectOptions(
          camera: isVideo
              ? TrackOption.enabled()
              : TrackOption.disabled(),
          microphone: TrackOption.enabled(),
        ),
      );
      _activeCall = call;
      callNotifier.value = call;
      if (kDebugMode) {
        debugPrint(
          '[StreamCallEngine] joined cid=$streamCallCid '
          '(video=$isVideo) — Call ready for rendering',
        );
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('StreamCallEngine.join failed: $e\n$st');
      }
    }
  }

  /// Accept the currently-pending incoming Stream call (the one
  /// surfaced via `onStreamIncomingCall`). MUST be called on the SAME
  /// `Call` instance Stream gave us — `client.makeCall(id)` returns
  /// a fresh reference that hasn't gone through ringing-acceptance,
  /// so `accept()` on a fresh ref would fail and audio wouldn't flow.
  Future<void> acceptPendingIncoming({required bool isVideo}) async {
    final call = _pendingIncomingCall;
    if (call == null) {
      // ignore: avoid_print
      print('[StreamCallEngine] acceptPendingIncoming: no pending call');
      return;
    }
    try {
      // ignore: avoid_print
      print('[StreamCallEngine] accept() on incoming call ${call.callCid}');
      await call.accept();
      await call.join(
        connectOptions: CallConnectOptions(
          camera: isVideo ? TrackOption.enabled() : TrackOption.disabled(),
          microphone: TrackOption.enabled(),
        ),
      );
      _activeCall = call;
      callNotifier.value = call;
      _pendingIncomingCall = null;
      // ignore: avoid_print
      print('[StreamCallEngine] accept+join OK — media leg up');
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[StreamCallEngine] acceptPendingIncoming failed: $e\n$st');
      }
    }
  }

  /// Reject the currently-pending incoming Stream call.
  Future<void> rejectPendingIncoming() async {
    final call = _pendingIncomingCall;
    if (call == null) return;
    try {
      await call.reject();
      _pendingIncomingCall = null;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[StreamCallEngine] rejectPendingIncoming failed: $e\n$st');
      }
    }
  }

  /// Subscribe to [call.state] so we detect Stream-side end events
  /// (peer hung up, network disconnect, etc.) and surface them
  /// through [onStreamCallEnded] for the signaling layer to pop the
  /// local UI. Only one active subscription at a time — replaces the
  /// previous one so we don't fan out duplicate end events when a new
  /// call comes in.
  void _attachEndListener(Call call) {
    _activeStateSub?.cancel();
    _activeStateSub = call.state.valueStream.listen((s) {
      final status = s.status;
      if (status is CallStatusDisconnected ||
          status is CallStatusReconnectionFailed) {
        // ignore: avoid_print
        print('[StreamCallEngine] Stream call ended · status=$status');
        if (!_callEndedController.isClosed) {
          _callEndedController.add(null);
        }
      }
    });
  }

  /// Eagerly connect the Stream client so the SDK's
  /// [PushNotificationManager.registerDevice] runs against this
  /// user's identity — without it, Stream's backend has no FCM token
  /// recorded for this user and `call.getOrCreate({ring: true})` from
  /// the caller side silently drops the ring.
  ///
  /// Call this from the auth login path AND from the cold-start auto-
  /// login path. Safe to call repeatedly — `_ensureClient` short-
  /// circuits when the client is already live for the same userId.
  /// Failures (token fetch 401, network) are swallowed inside
  /// `_ensureClient`; this is best-effort.
  Future<void> warmUp() async {
    // Unconditional print so this also fires in release while we
    // triangulate the ring-not-arriving bug. Re-gate once confirmed.
    // ignore: avoid_print
    print('[StreamCallEngine] warmUp() invoked');
    await _ensureClient();
  }

  /// Leave the active Stream call (if any) and clear the cached
  /// handle. Safe to call multiple times. Does NOT tear down the
  /// shared client — that stays for the next call.
  Future<void> leave() async {
    final call = _activeCall;
    _activeCall = null;
    callNotifier.value = null;
    if (call == null) return;
    try {
      await call.leave();
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('StreamCallEngine.leave failed: $e\n$st');
      }
    }
  }

  /// Build (or rebuild) the `StreamVideo` client using a fresh token
  /// from `GET /chats/calls/stream-token`. Cached by `userId` so a
  /// sign-out / sign-in rotation rebuilds; otherwise re-used.
  Future<void> _ensureClient() async {
    Map<String, dynamic> tokenJson;
    try {
      tokenJson = await remote.getStreamToken();
    } catch (e) {
      if (kDebugMode) debugPrint('StreamCallEngine token fetch failed: $e');
      return;
    }
    final apiKey = tokenJson['apiKey']?.toString() ?? '';
    final token = tokenJson['token']?.toString() ?? '';
    final userId = tokenJson['userId']?.toString() ?? '';

    // Unconditional (release-visible) while diagnosing the ring bug.
    // ignore: avoid_print
    print(
      '[StreamCallEngine] /stream-token → '
      'apiKey=$apiKey '
      'userId=$userId '
      'token=${_redactToken(token)}',
    );

    if (apiKey.isEmpty || token.isEmpty || userId.isEmpty) {
      if (kDebugMode) {
        debugPrint(
          '[StreamCallEngine] missing field(s) from /stream-token — '
          'apiKey.empty=${apiKey.isEmpty} '
          'token.empty=${token.isEmpty} '
          'userId.empty=${userId.isEmpty} — aborting join',
        );
      }
      return;
    }

    if (_client != null && _clientUserId == userId) return;
    // Identity changed (or first use) — rebuild.
    try {
      await _client?.disconnect();
    } catch (_) {/* swallow */}
    // Look up our display name from the shared UsersCache (populated
    // by /users/me on login). Without this Stream falls back to the
    // bare userId in the VoIP notification body, so callees see a
    // ringer saying "10 is calling…" instead of "Mr A is calling…".
    final displayName = UsersCache.instance.nameOf(userId) ?? '';
    final avatarUrl = UsersCache.instance.avatarOf(userId);
    // ignore: avoid_print
    print('[StreamCallEngine] building client as userId=$userId '
        'name="$displayName" avatar=${avatarUrl ?? "none"}');
    _client = StreamVideo(
      apiKey,
      user: User.regular(
        userId: userId,
        name: displayName,
        image: avatarUrl,
      ),
      userToken: token,
      // Native incoming-call ring screen. Without a PN manager the
      // SDK falls back to a silent grouped notification (the one that
      // was spamming `notify(...)` in the receiver logs). With this
      // wired, Stream's backend ring=true push lands in the SDK's
      // native handler → flutter_callkit_incoming renders the
      // FaceTime/Connection-Service style fullscreen ringer.
      //
      // ⚠ Requires Stream Dashboard config (one-time, server side):
      //   - Stream Console → your app → Push Notifications
      //   - Add a Firebase provider, name it EXACTLY 'firebase'
      //     (matching `androidPushProvider.name` below)
      //   - Upload the Firebase Admin SDK service-account JSON
      //   - Same for APNs on iOS (provider name 'apn')
      pushNotificationManagerProvider:
          StreamVideoPushNotificationManager.create(
        iosPushProvider: const StreamVideoPushProvider.apn(
          name: 'apn',
        ),
        androidPushProvider: const StreamVideoPushProvider.firebase(
          name: 'firebase',
        ),
      ),
    );
    _clientUserId = userId;
    // Install the foreground-service bridge so the mic/camera stay
    // alive when the user backgrounds the app mid-call. Without this,
    // Android 14+ silences the mic the instant the activity loses
    // focus — the peer hears nothing. The plugin's own manifest
    // declares the service + foregroundServiceType, so we only have
    // to call init once per client; it auto-starts on every join and
    // auto-stops on every leave.
    StreamBackgroundService.init(_client!);
    // Subscribe to Stream's live incoming-call channel BEFORE we
    // connect — Stream sets `state.incomingCall` the instant the
    // backend fan-outs a `ring=true` call to a foregrounded peer.
    // For backgrounded/killed peers the native push handler kicks in
    // instead; this stream only fires while the WebSocket is alive.
    await _incomingCallSub?.cancel();
    _incomingCallSub = _client!.state.incomingCall.valueStream.listen((call) {
      if (call == null) {
        // Stream cleared the incoming call — caller withdrew before
        // we answered. Surface as "ended" so the local overlay pops.
        _pendingIncomingCall = null;
        if (!_callEndedController.isClosed) {
          _callEndedController.add(null);
        }
        return;
      }
      _pendingIncomingCall = call;
      // ignore: avoid_print
      print('[StreamCallEngine] 📞 incoming Stream call · '
          'cid=${call.callCid} · type=${call.type}');
      // Listen for THIS call's lifecycle so we can detect caller-end
      // even after the incoming-call slot has been cleared (e.g. once
      // we accept). When Stream's status flips to disconnected /
      // ended, surface it through onStreamCallEnded.
      _attachEndListener(call);
      if (!_incomingCallController.isClosed) {
        _incomingCallController.add(call);
      }
    });
    try {
      await _client!.connect();
      // ignore: avoid_print
      print('[StreamCallEngine] connected as userId=$userId');
    } catch (e) {
      // ignore: avoid_print
      print('[StreamCallEngine] ❌ connect failed: $e');
    }
  }

  /// JWTs are sensitive — log only head + tail so we can verify shape
  /// (3 dot-separated base64 segments) without leaking the full token.
  static String _redactToken(String token) {
    if (token.length <= 16) return '***';
    return '${token.substring(0, 8)}…${token.substring(token.length - 6)} '
        '(len=${token.length})';
  }

  /// Tear down for tests / hot-restart. Production code doesn't need
  /// to call this — the client lives for the app's lifetime.
  Future<void> dispose() async {
    await leave();
    await _incomingCallSub?.cancel();
    _incomingCallSub = null;
    await _activeStateSub?.cancel();
    _activeStateSub = null;
    await _incomingCallController.close();
    await _callEndedController.close();
    try {
      await _client?.disconnect();
    } catch (_) {}
    _client = null;
    _clientUserId = null;
    _pendingIncomingCall = null;
  }
}
