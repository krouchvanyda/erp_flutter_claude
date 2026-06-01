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

  /// Monotonic counter incremented on every join / accept entry.
  /// Each invocation captures its value, then re-checks at every
  /// await checkpoint — if `_callSeq` has moved on since, a newer
  /// invocation is in flight and we abandon ours (leave the half-set-
  /// up Call ref) so the newer one wins. This is the only thing that
  /// stops back-to-back call attempts from racing and producing
  /// Stream "Disconnected: Replaced" events on the brand-new call.
  int _callSeq = 0;

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

  /// Fires on the CALLER's side the first time a remote participant
  /// joins the Stream call — i.e. our peer accepted on their device.
  /// Used as a backup signal when the chat-ceremony backend never
  /// broadcasts `call.accept` to us (its own 30 s timer fired and
  /// closed the row before the callee tapped Accept). Without this,
  /// A's UI stays on "Calling…" indefinitely even though B is already
  /// in the media call.
  Stream<void> get onStreamPeerJoined => _peerJoinedController.stream;
  final StreamController<void> _peerJoinedController =
      StreamController<void>.broadcast();
  StreamSubscription<CallState>? _peerJoinedSub;

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
    // Stake our claim BEFORE any await — anything kicked off after
    // this call bumps the counter, so we'll see we've been superseded
    // at the next checkpoint and bail out. Bumping (instead of just
    // reading) also forces the prior in-flight join() to notice that
    // a newer one started.
    final mySeq = ++_callSeq;
    try {
      // CRITICAL: tear down any prior Stream call before starting a
      // new one. Stream's internal state can only host one active call
      // per client — joining a second one fires a "Disconnected:
      // Replaced" event on the previous one, and if that listener is
      // still wired up it'll bubble through `onStreamCallEnded` and
      // tear down our brand-new local signaling state for the NEW
      // call. Symptom: A taps Call, A's UI immediately ends with
      // "Call ended" even though B was never reached.
      if (_activeCall != null) {
        if (kDebugMode) {
          debugPrint('[StreamCallEngine] leaving prior Stream call '
              'before starting new one (cid=$streamCallCid)');
        }
        await leave();
      }
      if (mySeq != _callSeq) return; // superseded
      await _ensureClient();
      if (mySeq != _callSeq) return; // superseded
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
      //
      // `ring` extends Stream's server-side ring timeouts from the
      // 30 s default to 60 s. Without this extension the call is
      // auto-cancelled on the coordinator before the callee has had
      // time to: (1) notice the CallKit notification, (2) tap it,
      // (3) the app wakes up, and (4) the accept POST round-trips.
      // On a backgrounded device that whole chain easily eats 20–30 s.
      // 60 s matches what most VoIP apps (WhatsApp, Telegram) use.
      // ignore: avoid_print
      print('[StreamCallEngine] getOrCreate(callId=$callId, '
          'members=$calleeUserIds, ringing=$shouldRing, ringTimeout=60s)');
      await call.getOrCreate(
        memberIds: calleeUserIds,
        ringing: shouldRing,
        video: isVideo,
        ring: const StreamRingSettings(
          autoCancelTimeout: Duration(seconds: 60),
          autoRejectTimeout: Duration(seconds: 60),
          missedCallTimeout: Duration(seconds: 60),
        ),
      );
      if (mySeq != _callSeq) {
        // A newer join started while we were in getOrCreate — abandon
        // our half-set-up Call. Leaving it would also fire a Replaced
        // disconnect, but the newer invocation has already taken over
        // _activeCall and the listener, so it can safely ignore it.
        try { await call.leave(); } catch (_) {}
        return;
      }
      await call.join(
        connectOptions: CallConnectOptions(
          camera: isVideo
              ? TrackOption.enabled()
              : TrackOption.disabled(),
          microphone: TrackOption.enabled(),
        ),
      );
      if (mySeq != _callSeq) {
        try { await call.leave(); } catch (_) {}
        return;
      }
      _activeCall = call;
      callNotifier.value = call;
      // Caller-side path only: watch for the first remote participant
      // to join so we can flip the chat-ceremony state to connected
      // even when the backend's `call.accept` STOMP broadcast never
      // reaches us.
      if (shouldRing) {
        _attachPeerJoinedListener(call);
      }
      _attachEndListener(call);
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

  /// Subscribe to [call.state] and fire [onStreamPeerJoined] the first
  /// time a non-local participant appears. Used on the caller's side
  /// as a fallback signal when the chat-ceremony backend fails to
  /// broadcast `call.accept` to us (its own ring timer fired before
  /// the callee tapped Accept, but the callee's media leg came up
  /// anyway via the Stream-only fallback). Single-fire: we cancel the
  /// subscription as soon as a peer is seen.
  void _attachPeerJoinedListener(Call call) {
    _peerJoinedSub?.cancel();
    _peerJoinedSub = call.state.valueStream.listen((s) {
      if (s.callParticipants.any((p) => !p.isLocal)) {
        // ignore: avoid_print
        print('[StreamCallEngine] remote peer joined the Stream call '
            '— firing onStreamPeerJoined');
        if (!_peerJoinedController.isClosed) {
          _peerJoinedController.add(null);
        }
        _peerJoinedSub?.cancel();
        _peerJoinedSub = null;
      }
    });
  }

  /// Accept a Stream call directly by its CID (e.g. from a CallKit
  /// notification accept event). Used when there's no
  /// `_pendingIncomingCall` to attach to — typically because the app
  /// was minimized (Stream WS was down) or killed (no Dart isolate
  /// running) when the ring push arrived.
  ///
  /// Reconnects the Stream client if needed, then `accept()` +
  /// `join()`. Stream reconciles the call state from the coordinator.
  Future<void> acceptByCid({
    required String callCid,
    required bool isVideo,
  }) async {
    if (callCid.isEmpty) return;
    final mySeq = ++_callSeq;
    try {
      // Same protection as join(): tear down any prior Stream call so
      // Stream's "Replaced" disconnect on the OLD call doesn't fire
      // through onStreamCallEnded and kill our NEW signaling state.
      if (_activeCall != null) {
        if (kDebugMode) {
          debugPrint('[StreamCallEngine] acceptByCid: leaving prior '
              'Stream call before accepting new one (cid=$callCid)');
        }
        await leave();
      }
      if (mySeq != _callSeq) return;
      await _ensureClient();
      if (mySeq != _callSeq) return;
      final client = _client;
      if (client == null) return;
      final parts = callCid.split(':');
      final callType = parts.length > 1 ? parts[0] : 'default';
      final callId = parts.length > 1 ? parts[1] : callCid;
      // ignore: avoid_print
      print('[StreamCallEngine] acceptByCid: $callCid (type=$callType id=$callId)');
      final call = client.makeCall(
        callType: StreamCallType.fromString(callType),
        id: callId,
      );
      await call.accept();
      if (mySeq != _callSeq) {
        try { await call.leave(); } catch (_) {}
        return;
      }
      await call.join(
        connectOptions: CallConnectOptions(
          camera: isVideo ? TrackOption.enabled() : TrackOption.disabled(),
          microphone: TrackOption.enabled(),
        ),
      );
      if (mySeq != _callSeq) {
        try { await call.leave(); } catch (_) {}
        return;
      }
      _activeCall = call;
      callNotifier.value = call;
      _attachEndListener(call);
      // ignore: avoid_print
      print('[StreamCallEngine] acceptByCid: accept+join OK');
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[StreamCallEngine] acceptByCid failed: $e\n$st');
      }
    }
  }

  /// Reject a Stream call by its CID (CallKit decline path).
  Future<void> rejectByCid({required String callCid}) async {
    if (callCid.isEmpty) return;
    try {
      await _ensureClient();
      final client = _client;
      if (client == null) return;
      final parts = callCid.split(':');
      final callType = parts.length > 1 ? parts[0] : 'default';
      final callId = parts.length > 1 ? parts[1] : callCid;
      final call = client.makeCall(
        callType: StreamCallType.fromString(callType),
        id: callId,
      );
      // ignore: avoid_print
      print('[StreamCallEngine] rejectByCid: $callCid');
      await call.reject();
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[StreamCallEngine] rejectByCid failed: $e\n$st');
      }
    }
  }

  /// Accept the currently-pending incoming Stream call (the one
  /// surfaced via `onStreamIncomingCall`). MUST be called on the SAME
  /// `Call` instance Stream gave us — `client.makeCall(id)` returns
  /// a fresh reference that hasn't gone through ringing-acceptance,
  /// so `accept()` on a fresh ref would fail and audio wouldn't flow.
  Future<void> acceptPendingIncoming({
    required bool isVideo,
    String? expectedCid,
  }) async {
    final call = _pendingIncomingCall;
    if (call == null) {
      // ignore: avoid_print
      print('[StreamCallEngine] acceptPendingIncoming: no pending call');
      return;
    }
    // Guard against stale references: a Stream WS push from a PRIOR
    // call may have left _pendingIncomingCall set with the wrong CID.
    // If the caller knows which call they want to accept, verify the
    // pending one matches. Mismatch → bail out so caller's fallback
    // (`acceptByCid` with the explicit CID) runs instead.
    if (expectedCid != null &&
        expectedCid.isNotEmpty &&
        call.callCid.value != expectedCid) {
      // ignore: avoid_print
      print('[StreamCallEngine] acceptPendingIncoming: CID mismatch — '
          'pending=${call.callCid.value} expected=$expectedCid — '
          'clearing stale ref so caller falls back to acceptByCid');
      _pendingIncomingCall = null;
      return;
    }
    final mySeq = ++_callSeq;
    try {
      if (_activeCall != null) {
        await leave();
      }
      if (mySeq != _callSeq) return;
      // ignore: avoid_print
      print('[StreamCallEngine] accept() on incoming call ${call.callCid}');
      await call.accept();
      if (mySeq != _callSeq) {
        try { await call.leave(); } catch (_) {}
        return;
      }
      await call.join(
        connectOptions: CallConnectOptions(
          camera: isVideo ? TrackOption.enabled() : TrackOption.disabled(),
          microphone: TrackOption.enabled(),
        ),
      );
      if (mySeq != _callSeq) {
        try { await call.leave(); } catch (_) {}
        return;
      }
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
      // Defence-in-depth: only fire `onStreamCallEnded` when the
      // disconnect is for our CURRENT active call. If `_activeCall`
      // has been swapped for a newer Call ref (e.g. by a back-to-back
      // call attempt that won the latest-wins race in join()), the
      // old call's disconnect event arriving late on this subscription
      // must NOT bubble through — it would tear down the NEW call's
      // local signaling state.
      if (_activeCall != call) return;
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

  /// Disconnect Stream's WebSocket (but keep cached identity) when
  /// the app goes to background, IF there's no active call. Why:
  /// Stream prefers WS over FCM when a client is "online" — so a
  /// minimized peer with a live WS gets the incoming-call event in-
  /// process where we can't render UI (the app isn't visible). By
  /// dropping the WS on pause, we force Stream to use the FCM push
  /// path, which `flutter_callkit_incoming` renders as a native
  /// full-screen ringer. Reconnect on resume via [warmUp].
  ///
  /// Skipped during an active call so the audio leg isn't torn down
  /// when the user briefly backgrounds the app mid-conversation.
  Future<void> disconnectForBackground() async {
    // Detect a STALE _activeCall: if the underlying Stream call is
    // already in a disconnected state, the reference is leftover from
    // a previous ended call. Clear it eagerly so the next minimize
    // doesn't get blocked by the leak (symptom: subsequent A→B calls
    // come in over WS we can't render → A times out → "missed call").
    final stale = _activeCall;
    if (stale != null) {
      final status = stale.state.valueOrNull?.status;
      final isLive = !(status is CallStatusDisconnected ||
          status is CallStatusReconnectionFailed ||
          status is CallStatusIdle);
      if (!isLive) {
        // ignore: avoid_print
        print('[StreamCallEngine] disconnectForBackground: '
            'stale _activeCall found (status=$status) — clearing');
        try {
          await stale.leave();
        } catch (_) {}
        _activeCall = null;
        callNotifier.value = null;
      }
    }
    if (_activeCall != null) {
      // ignore: avoid_print
      print('[StreamCallEngine] disconnectForBackground: skipped '
          '(active call in flight, audio must stay alive)');
      return;
    }
    final client = _client;
    if (client == null) return;
    try {
      // ignore: avoid_print
      print('[StreamCallEngine] disconnectForBackground: dropping WS '
          'so Stream falls back to FCM push for incoming calls');
      await _incomingCallSub?.cancel();
      _incomingCallSub = null;
      await client.disconnect();
    } catch (e) {
      // ignore: avoid_print
      print('[StreamCallEngine] disconnectForBackground failed: $e');
    }
    // Null out so the next `warmUp` triggers a fresh _ensureClient
    // (re-fetch /stream-token, rebuild StreamVideo, reattach the
    // incoming-call listener). One extra HTTP per resume — acceptable.
    _client = null;
    _clientUserId = null;
    _pendingIncomingCall = null;
  }

  /// Leave the active Stream call (if any) and clear the cached
  /// handle. Safe to call multiple times. Does NOT tear down the
  /// shared client — that stays for the next call.
  Future<void> leave() async {
    final call = _activeCall;
    _activeCall = null;
    callNotifier.value = null;
    await _peerJoinedSub?.cancel();
    _peerJoinedSub = null;
    // CRITICAL: cancel the end-listener too. Without this, when we
    // leave THIS call and start a NEW one, Stream emits a "Replaced"
    // disconnect on the old call after our cancellation but before
    // its Future completes — the still-attached listener pushes it
    // into onStreamCallEnded and kills the brand-new call's state.
    await _activeStateSub?.cancel();
    _activeStateSub = null;
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
    // Reset Stream's GLOBAL singleton too. Nulling our local `_client`
    // isn't enough — Stream's internal `InstanceHolder` still holds a
    // reference to the previous client, so a fresh `StreamVideo(...)`
    // throws "already initialised". This happens after
    // `disconnectForBackground` on minimize → warmUp on resume.
    try {
      await StreamVideo.reset(disconnect: true);
    } catch (_) {/* swallow — reset has no effect if no instance */}
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
    await _peerJoinedSub?.cancel();
    _peerJoinedSub = null;
    await _incomingCallController.close();
    await _callEndedController.close();
    await _peerJoinedController.close();
    try {
      await _client?.disconnect();
    } catch (_) {}
    _client = null;
    _clientUserId = null;
    _pendingIncomingCall = null;
  }
}
