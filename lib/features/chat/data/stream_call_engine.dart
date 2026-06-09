import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';
import 'package:stream_video_flutter/stream_video_flutter_background.dart';
import 'package:stream_video_push_notification/stream_video_push_notification.dart';

import 'chats_remote_data_source.dart';
import 'users_cache.dart';

/// Why Stream signalled that the active call ended. Lets the consumer
/// distinguish DEFINITIVE ends (which must always tear the call down)
/// from the one POSSIBLY-TRANSIENT case (a raw `Disconnected` that the
/// SDK sometimes emits during media setup and then self-recovers, which
/// is the only kind worth settle-guarding).
enum StreamCallEndReason {
  /// A remote participant that WAS present left the call (the peer hung
  /// up / left). Definitive — never a transient SDK blip.
  remoteLeft,

  /// Stream's WebSocket flipped to `Disconnected`. May be a transient
  /// media-setup blip that self-recovers, so the consumer settle-guards
  /// it within the first couple seconds of a fresh connect.
  disconnected,

  /// Reconnection permanently failed. Definitive.
  reconnectFailed,

  /// Stream cleared the incoming-call slot — the caller withdrew before
  /// we answered. Definitive.
  incomingCleared,
}

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

  /// The call currently being set up by [join] but NOT yet promoted to
  /// [_activeCall] (we only promote after `join()` resolves). Its
  /// `getOrCreate(ringing: true)` already started Stream's outgoing
  /// "Call in progress / Connecting…" foreground-service notification,
  /// so if the callee rejects DURING this window, [leave] must leave
  /// THIS ref too — otherwise that notification lingers forever because
  /// `_activeCall` was still null when teardown ran.
  Call? _inFlightCall;

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

  /// True when the active Stream call currently has at least one REMOTE
  /// (non-local) participant connected.
  ///
  /// This is the reliable discriminator the signalling layer uses to tell
  /// a REAL peer hang-up from a stale backend hangup that raced a fresh
  /// accept: when the caller deliberately ends the call they leave the
  /// media session (→ false), whereas a backend ring-timer hangup fires
  /// while the caller is still sitting in the call (→ true).
  bool get hasRemoteParticipant {
    final call = _activeCall ?? callNotifier.value;
    if (call == null) return false;
    final participants = call.state.valueOrNull?.callParticipants ?? const [];
    return participants.any((p) => !p.isLocal);
  }

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
  ///
  /// The emitted [StreamCallEndReason] tells the consumer whether the
  /// end is DEFINITIVE (a peer truly left / reconnect permanently failed
  /// / caller withdrew) or POSSIBLY-TRANSIENT (a raw `Disconnected` that
  /// Stream sometimes emits mid media-setup and then self-recovers).
  /// Only the latter should be settle-guarded — see
  /// `_handleStreamCallEnded` in CallSignalingService. Collapsing both
  /// into a bare signal was a bug: B accepting from a LOCKED screen, then
  /// A hanging up within the settle window, produced a definitive
  /// `remoteLeft` that the guard wrongly swallowed → B stuck Connected.
  Stream<StreamCallEndReason> get onStreamCallEnded =>
      _callEndedController.stream;
  final StreamController<StreamCallEndReason> _callEndedController =
      StreamController<StreamCallEndReason>.broadcast();
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
    // Drop any stale in-flight ref from a prior attempt — this attempt
    // sets its own below once the Call is created.
    _inFlightCall = null;
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
      // Track as in-flight from the moment it exists: getOrCreate below
      // starts Stream's outgoing foreground-service notification, and a
      // reject can land before we promote this to _activeCall.
      _inFlightCall = call;
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
      final getOrCreateResult = await call.getOrCreate(
        memberIds: calleeUserIds,
        ringing: shouldRing,
        video: isVideo,
        ring: const StreamRingSettings(
          autoCancelTimeout: Duration(seconds: 60),
          autoRejectTimeout: Duration(seconds: 60),
          missedCallTimeout: Duration(seconds: 60),
        ),
      );
      if (getOrCreateResult.isFailure) {
        // ignore: avoid_print
        print('[StreamCallEngine] getOrCreate FAILED: '
            '$getOrCreateResult — aborting join');
        try { await call.leave(); } catch (_) {}
        return;
      }
      if (mySeq != _callSeq) {
        try { await call.leave(); } catch (_) {}
        return;
      }
      final joinResult = await call.join(
        connectOptions: CallConnectOptions(
          camera: isVideo
              ? TrackOption.enabled()
              : TrackOption.disabled(),
          microphone: TrackOption.enabled(),
        ),
      );
      if (joinResult.isFailure) {
        // ignore: avoid_print
        print('[StreamCallEngine] call.join FAILED on outgoing: '
            '$joinResult — A has no mic, B will hear silence');
        try { await call.leave(); } catch (_) {}
        return;
      }
      // ignore: avoid_print
      print('[StreamCallEngine] call.join OK on outgoing — '
          'setting _activeCall, mic should publish now');
      if (mySeq != _callSeq) {
        try { await call.leave(); } catch (_) {}
        return;
      }
      // NOTE: We deliberately do NOT call _waitForCallSettled here.
      // For the OUTGOING caller path, Stream's call status only
      // transitions to Connected AFTER a remote participant joins —
      // which can't happen until the callee taps Accept (potentially
      // 30+ seconds after we placed the call). Waiting for Connected
      // here would always time out, we'd leave() our own call, our
      // mic would die, and when the callee finally joined they'd
      // hear silence because the caller already bowed out. Trust
      // that call.join() resolving means we're in the call as
      // participant; the `_attachPeerJoinedListener` handles the
      // moment the remote actually arrives. The settle-wait stays in
      // acceptByCid / acceptPendingIncoming because on those paths a
      // remote IS already in the call (the caller).
      _activeCall = call;
      _inFlightCall = null; // promoted — no longer "in flight"
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
    // Claim this accept ONCE for the whole retry loop. Previously each
    // attempt re-bumped `_callSeq` inside `_doAcceptByCid`, which meant a
    // terminal teardown's `_callSeq` bump was immediately overwritten by
    // the next retry — so the loop happily re-joined a call that had
    // already ended, producing a ghost Stream call with no signaling
    // state (the second "stuck Connected"). Now the loop owns one seq and
    // aborts the instant anything else (a teardown via endActiveCall, or a
    // newer call) bumps `_callSeq` past it.
    final mySeq = ++_callSeq;
    // Retry on cold-start coordinator timeouts. The Stream SDK has a
    // hardcoded 5 s ceiling in CoordinatorClientOpenApi._waitUntilConnected
    // — on a CallKit-triggered cold-start the coordinator WS often
    // isn't ready in time and the FIRST call.join() resolves but then
    // the call asynchronously emits Disconnected{reason: Failure} via
    // a TimeoutException. By the 2nd attempt the WS is up and join
    // succeeds. Up to 3 attempts × 1 s back-off = ~3 s extra in the
    // worst case, but resolves the cold-start race transparently.
    const maxAttempts = 3;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      if (mySeq != _callSeq) {
        // ignore: avoid_print
        print('[StreamCallEngine] acceptByCid superseded (call ended or a '
            'newer call started) — aborting before attempt $attempt');
        return;
      }
      final ok = await _doAcceptByCid(
        callCid: callCid,
        isVideo: isVideo,
        attempt: attempt,
        maxAttempts: maxAttempts,
        mySeq: mySeq,
      );
      if (ok) return;
      if (mySeq != _callSeq) {
        // ignore: avoid_print
        print('[StreamCallEngine] acceptByCid superseded after attempt '
            '$attempt — not retrying');
        return;
      }
      if (attempt < maxAttempts) {
        // ignore: avoid_print
        print('[StreamCallEngine] acceptByCid attempt $attempt failed '
            '— retrying after 1 s');
        await Future.delayed(const Duration(seconds: 1));
      }
    }
    // ignore: avoid_print
    print('[StreamCallEngine] acceptByCid exhausted $maxAttempts '
        'attempts for cid=$callCid');
  }

  /// Single attempt of acceptByCid. Returns true if the accept + join
  /// succeeded AND the call reached a Connected/Joined state within
  /// 6 s. Returns false on cold-start timeout, network failure, or
  /// when superseded by a newer invocation.
  Future<bool> _doAcceptByCid({
    required String callCid,
    required bool isVideo,
    required int attempt,
    required int maxAttempts,
    required int mySeq,
  }) async {
    // NOTE: do NOT bump `_callSeq` here — the seq is claimed once by the
    // [acceptByCid] loop and passed in, so a terminal teardown can abort
    // every retry. Bumping per-attempt was the ghost-call bug.
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
      if (mySeq != _callSeq) return true; // superseded — caller stops too
      await _ensureClient();
      if (mySeq != _callSeq) return true;
      final client = _client;
      if (client == null) return false;
      final parts = callCid.split(':');
      final callType = parts.length > 1 ? parts[0] : 'default';
      final callId = parts.length > 1 ? parts[1] : callCid;
      // ignore: avoid_print
      print('[StreamCallEngine] acceptByCid attempt $attempt/$maxAttempts: '
          '$callCid (type=$callType id=$callId)');

      // CRITICAL: Stream's `Call.accept()` only works on a Call ref
      // that's in `Incoming` state. A fresh ref from `client.makeCall`
      // starts in `Idle` — accept() fails with "invalid status: Idle".
      // The proper Incoming Call ref comes from Stream's
      // `state.incomingCall` (populated when the WS receives the ring
      // push). On cold-start the WS connect we just awaited might not
      // have delivered that event yet — wait briefly for it to land
      // and use it if it does. Falls through to the makeCall path only
      // if Stream still hasn't surfaced the call after 3 s (in which
      // case the accept WILL fail, but we tried).
      final waited = await _waitForPendingIncoming(callCid,
          timeout: const Duration(seconds: 3));
      if (mySeq != _callSeq) return true;
      if (waited != null) {
        // ignore: avoid_print
        print('[StreamCallEngine] acceptByCid attempt $attempt: '
            'using Stream-provided incoming Call ref (cid=${waited.callCid}) '
            'instead of fresh makeCall — accept will succeed');
        return _acceptOnCallRef(waited, isVideo: isVideo, mySeq: mySeq,
            attemptLabel: 'attempt $attempt');
      }
      // No pending incoming — Stream's WS connected after the ring
      // already happened via FCM, and the coordinator doesn't replay
      // missed ring events on reconnect, so `state.incomingCall`
      // never populates.
      //
      // Use Stream's documented `consumeIncomingCall(uuid, cid)` —
      // it calls `_client.getCall(cid)` internally then constructs
      // the Call via `_makeCallFromRinging(data, ...)` which yields
      // a Call ref in proper Incoming state. This is what the SDK
      // intends for CallKit-fired accepts where state.incomingCall
      // wasn't populated by a live WS event.
      // ignore: avoid_print
      print('[StreamCallEngine] acceptByCid attempt $attempt: '
          'no pending incoming Call — using consumeIncomingCall to '
          'fetch a proper Incoming Call ref');
      final consumeResult = await client.consumeIncomingCall(
        uuid: callCid, // any unique id; CID itself works
        cid: callCid,
      );
      if (consumeResult.isFailure) {
        // ignore: avoid_print
        print('[StreamCallEngine] acceptByCid attempt $attempt: '
            'consumeIncomingCall FAILED: $consumeResult');
        return false;
      }
      if (mySeq != _callSeq) return true;
      final call = (consumeResult as Success<Call>).data;
      // ignore: avoid_print
      print('[StreamCallEngine] acceptByCid attempt $attempt: '
          'consumeIncomingCall returned Call ref · routing through '
          '_acceptOnCallRef for accept+join');
      return _acceptOnCallRef(call,
          isVideo: isVideo, mySeq: mySeq,
          attemptLabel: 'attempt $attempt (consumed)');
    } catch (e, st) {
      // ignore: avoid_print
      print('[StreamCallEngine] acceptByCid attempt $attempt threw: $e\n$st');
      return false;
    }
  }

  /// Poll [_pendingIncomingCall] for up to [timeout] looking for a
  /// Call ref whose CID matches [expectedCid]. Returns the Call if
  /// found, null if it never arrives within the window.
  ///
  /// Used by [acceptByCid] on cold-start: after `_ensureClient`
  /// connects the Stream WS, the coordinator may take a couple of
  /// seconds to deliver the incoming-call event that populates
  /// `state.incomingCall`. Calling `.accept()` on a fresh
  /// `client.makeCall(id)` ref before that happens fails with
  /// "invalid status: Idle" because the fresh ref starts in Idle —
  /// only the Stream-provided ref is in Incoming state.
  Future<Call?> _waitForPendingIncoming(
    String expectedCid, {
    required Duration timeout,
  }) async {
    // Fast path: already populated.
    final existing = _pendingIncomingCall;
    if (existing != null && existing.callCid.value == expectedCid) {
      return existing;
    }
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 100));
      final current = _pendingIncomingCall;
      if (current != null && current.callCid.value == expectedCid) {
        return current;
      }
    }
    return null;
  }

  /// Shared accept-and-join body. Called from both acceptByCid (when
  /// it got a Stream-provided Call ref via _waitForPendingIncoming)
  /// and could be called from acceptPendingIncoming. Encapsulates the
  /// accept + join + settle-wait + listener attachment so the retry
  /// loop in acceptByCid doesn't need two near-identical code paths.
  Future<bool> _acceptOnCallRef(
    Call call, {
    required bool isVideo,
    required int mySeq,
    required String attemptLabel,
  }) async {
    try {
      final acceptResult = await call.accept();
      if (acceptResult.isFailure) {
        // ignore: avoid_print
        print('[StreamCallEngine] $attemptLabel: call.accept on '
            'Stream-provided ref FAILED: $acceptResult');
        try { await call.leave(); } catch (_) {}
        return false;
      }
      if (mySeq != _callSeq) {
        try { await call.leave(); } catch (_) {}
        return true;
      }
      final joinResult = await call.join(
        connectOptions: CallConnectOptions(
          camera: isVideo ? TrackOption.enabled() : TrackOption.disabled(),
          microphone: TrackOption.enabled(),
        ),
      );
      if (joinResult.isFailure) {
        // ignore: avoid_print
        print('[StreamCallEngine] $attemptLabel: call.join on '
            'Stream-provided ref FAILED: $joinResult');
        try { await call.leave(); } catch (_) {}
        return false;
      }
      if (mySeq != _callSeq) {
        try { await call.leave(); } catch (_) {}
        return true;
      }
      final settled = await _waitForCallSettled(call);
      if (mySeq != _callSeq) {
        try { await call.leave(); } catch (_) {}
        return true;
      }
      if (!settled) {
        // ignore: avoid_print
        print('[StreamCallEngine] $attemptLabel: Stream-provided ref '
            'did NOT settle to Connected — leaving and bailing');
        try { await call.leave(); } catch (_) {}
        return false;
      }
      _activeCall = call;
      callNotifier.value = call;
      _pendingIncomingCall = null;
      _attachEndListener(call);
      // ignore: avoid_print
      print('[StreamCallEngine] $attemptLabel: accept+join OK on '
          'Stream-provided ref — media leg up');
      return true;
    } catch (e, st) {
      // ignore: avoid_print
      print('[StreamCallEngine] $attemptLabel: _acceptOnCallRef threw: '
          '$e\n$st');
      return false;
    }
  }

  /// Wait up to 6 s for [call] to reach a steady Connected/Joined
  /// state. Returns false if the call hits Disconnected first or the
  /// 6 s window expires without success — signal to the caller that
  /// this attempt should be retried (typically the Stream SDK's
  /// cold-start coordinator timeout firing asynchronously).
  Future<bool> _waitForCallSettled(Call call) async {
    final completer = Completer<bool>();
    StreamSubscription<CallState>? sub;
    final timer = Timer(const Duration(seconds: 6), () {
      if (!completer.isCompleted) completer.complete(false);
    });
    sub = call.state.valueStream.listen((s) {
      final status = s.status;
      // Treat Joined / Connected as success.
      if (status is CallStatusConnected || status is CallStatusJoined) {
        if (!completer.isCompleted) completer.complete(true);
      } else if (status is CallStatusDisconnected ||
          status is CallStatusReconnectionFailed) {
        if (!completer.isCompleted) completer.complete(false);
      }
    });
    final result = await completer.future;
    timer.cancel();
    await sub.cancel();
    return result;
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
  ///
  /// Returns true when the accept succeeded and the call is live;
  /// false on any bail-out path (no pending ref, CID mismatch,
  /// superseded by a newer call attempt, accept/join threw). The
  /// caller uses this to decide whether to fall back to acceptByCid
  /// — WITHOUT this signal the caller used to check
  /// `hasPendingIncoming` which becomes false on BOTH success and
  /// bail, making it impossible to tell the two apart, so it would
  /// always re-run acceptByCid and tear down the just-connected call.
  Future<bool> acceptPendingIncoming({
    required bool isVideo,
    String? expectedCid,
  }) async {
    final call = _pendingIncomingCall;
    if (call == null) {
      // ignore: avoid_print
      print('[StreamCallEngine] acceptPendingIncoming: no pending call');
      return false;
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
      return false;
    }
    final mySeq = ++_callSeq;
    try {
      if (_activeCall != null) {
        await leave();
      }
      if (mySeq != _callSeq) return false;
      // ignore: avoid_print
      print('[StreamCallEngine] accept() on incoming call ${call.callCid}');
      final acceptResult = await call.accept();
      if (acceptResult.isFailure) {
        // ignore: avoid_print
        print('[StreamCallEngine] acceptPendingIncoming: '
            'call.accept FAILED: $acceptResult');
        try { await call.leave(); } catch (_) {}
        return false;
      }
      if (mySeq != _callSeq) {
        try { await call.leave(); } catch (_) {}
        return false;
      }
      final joinResult = await call.join(
        connectOptions: CallConnectOptions(
          camera: isVideo ? TrackOption.enabled() : TrackOption.disabled(),
          microphone: TrackOption.enabled(),
        ),
      );
      if (joinResult.isFailure) {
        // ignore: avoid_print
        print('[StreamCallEngine] acceptPendingIncoming: '
            'call.join FAILED: $joinResult');
        try { await call.leave(); } catch (_) {}
        return false;
      }
      if (mySeq != _callSeq) {
        try { await call.leave(); } catch (_) {}
        return false;
      }
      // Wait for the call to actually settle to Connected/Joined.
      // Same cold-start coordinator race as acceptByCid — call.join()
      // resolves before the coordinator confirms, and on a fresh WS
      // (B was minimized, so disconnectForBackground had dropped it)
      // _waitUntilConnected can time out 5 s later → call drops →
      // both A and B end up with no audio.
      final settled = await _waitForCallSettled(call);
      if (mySeq != _callSeq) {
        try { await call.leave(); } catch (_) {}
        return false;
      }
      if (!settled) {
        // ignore: avoid_print
        print('[StreamCallEngine] acceptPendingIncoming: call did NOT '
            'settle to Connected — leaving so caller can retry via '
            'acceptByCid (which has its own retry loop)');
        try { await call.leave(); } catch (_) {}
        // Also clear _pendingIncomingCall so the caller's fallback
        // doesn't loop back into acceptPendingIncoming.
        _pendingIncomingCall = null;
        return false;
      }
      _activeCall = call;
      callNotifier.value = call;
      _pendingIncomingCall = null;
      _attachEndListener(call);
      // ignore: avoid_print
      print('[StreamCallEngine] accept+join OK — media leg up');
      return true;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[StreamCallEngine] acceptPendingIncoming failed: $e\n$st');
      }
      return false;
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
    // Track whether a remote peer has EVER been present on this call.
    // Once one has, their later disappearance means "the other party
    // left" — which for a connected 1:1 is the ONLY end-signal we get:
    // Stream keeps OUR call alive when the peer leaves (it never fires a
    // Disconnected for us), and on a killed-app cold-start accept the
    // STOMP `call.hangup` may never reach us (socket not subscribed in
    // time). Watching the participant list works purely off the media
    // layer we DID join, so it survives all of that.
    var sawRemoteParticipant = false;
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

      // Remote-participant-left detection (peer hung up / left the call).
      // Fires only AFTER a remote was seen, so the transient "no remote
      // yet" window during our own join doesn't trip it; and only while
      // WE are solidly connected/joined, so a reconnect blip that
      // momentarily clears the participant list doesn't read as a leave.
      // For groups this only fires when the LAST remote leaves (call
      // emptied) — matching the last-person-out semantics.
      final hasRemote = s.callParticipants.any((p) => !p.isLocal);
      if (hasRemote) {
        sawRemoteParticipant = true;
      } else if (sawRemoteParticipant &&
          (status is CallStatusConnected || status is CallStatusJoined)) {
        // ignore: avoid_print
        print('[StreamCallEngine] remote participant left (call emptied) '
            '— firing onStreamCallEnded');
        if (!_callEndedController.isClosed) {
          _callEndedController.add(StreamCallEndReason.remoteLeft);
        }
        return;
      }
      if (status is CallStatusDisconnected) {
        final reason = status.reason;
        // Filter out reasons that are NOT real "the call ended"
        // signals. Stream emits Disconnected for several lifecycle
        // events that aren't actual hangups:
        //   * Replaced — another call took our slot (handled via
        //     latest-wins guards in join()/acceptByCid; if a stale
        //     listener does emit it, ignore here too)
        //   * Reconnection states sometimes pass through Disconnected
        //     transiently before recovering — but those are
        //     CallStatusReconnecting, not Disconnected, so they don't
        //     hit this branch
        final reasonStr = reason.toString().toLowerCase();
        final isReplaced = reasonStr.contains('replaced');
        // ignore: avoid_print
        print('[StreamCallEngine] Stream Disconnected · '
            'reason=$reason · isReplaced=$isReplaced · '
            'firing-end-event=${!isReplaced}');
        if (isReplaced) return;
        if (!_callEndedController.isClosed) {
          _callEndedController.add(StreamCallEndReason.disconnected);
        }
      } else if (status is CallStatusReconnectionFailed) {
        // ignore: avoid_print
        print('[StreamCallEngine] Stream call ReconnectionFailed — '
            'firing onStreamCallEnded');
        if (!_callEndedController.isClosed) {
          _callEndedController.add(StreamCallEndReason.reconnectFailed);
        }
      } else {
        // Log every other state transition so we can see the call's
        // lifecycle (Joining → Joined → Connected → ...) and spot any
        // unexpected transitions that lead to a teardown.
        // ignore: avoid_print
        print('[StreamCallEngine] Stream state transition · status=$status');
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
  /// TERMINAL teardown — call this (not [leave]) when the call is
  /// actually ending (hangup / reject / peer-hangup). It bumps
  /// `_callSeq` FIRST so any in-flight `join()` / `acceptByCid()` /
  /// `acceptPendingIncoming()` sees `mySeq != _callSeq` at its next
  /// checkpoint and abandons (leaving its half-joined ref) instead of
  /// finishing and re-publishing the mic AFTER we tore down — the
  /// minimize→accept→end audio leak.
  ///
  /// MUST NOT be used for the transitional teardown inside
  /// join()/acceptByCid() ("leave the prior call before starting a new
  /// one") — those captured their own `mySeq` just before and a bump
  /// here would make them self-abort. They call [leave] (no bump).
  Future<void> endActiveCall() async {
    ++_callSeq;
    await leave();
  }

  Future<void> leave() async {
    final call = _activeCall;
    // Capture + clear the in-flight ref up front so a call that's still
    // mid-`join()` (callee rejected while A was "Connecting…") gets its
    // Stream foreground-service notification stopped too — `call.leave()`
    // is the only thing that dismisses it, and `_activeCall` is null at
    // that point.
    final inflight = _inFlightCall;
    _inFlightCall = null;
    if (inflight != null && !identical(inflight, call)) {
      // ignore: avoid_print
      print('[StreamCallEngine] leave() · also leaving in-flight call '
          '${inflight.callCid.value} (connecting when teardown hit)');
      try {
        await inflight.leave();
      } catch (_) {/* already gone / never fully created */}
      await _stopCallForegroundService(inflight.callCid.value);
    }
    // Diagnostic (unconditional, release-visible) — proves whether a
    // teardown actually reached a live Call ref. If this logs
    // `activeCall=null` right after an End, the media leg we're hearing
    // was never tracked in `_activeCall` (double-join or in-flight
    // accept that finished after we cleared it).
    // ignore: avoid_print
    print('[StreamCallEngine] leave() ENTER · '
        'activeCall=${call?.callCid.value ?? "null"} · seq=$_callSeq');
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
    if (call == null) {
      // ignore: avoid_print
      print('[StreamCallEngine] leave() · no active call ref to leave — '
          'if audio is still flowing, the live call was NOT tracked here');
      return;
    }
    try {
      await call.leave();
      // ignore: avoid_print
      print('[StreamCallEngine] leave() · call.leave() OK for '
          '${call.callCid.value} — mic/audio should now be released');
    } catch (e, st) {
      // ignore: avoid_print
      print('[StreamCallEngine] leave() · call.leave() FAILED for '
          '${call.callCid.value}: $e');
      if (kDebugMode) {
        debugPrint('StreamCallEngine.leave failed: $e\n$st');
      }
    }
    // CRITICAL (Samsung "still Connected" bug): `call.leave()` alone does
    // NOT reliably tear down the call's foreground SERVICE on One UI, so
    // its ongoing "call" notification (channel `stream_call_*`) lingers on
    // the lock screen as a phantom Connected call — and once the FGS is
    // still alive, NO `cancel()` / `cancelAll()` can remove that
    // notification (the OS protects an active foreground-service notif).
    // The ONLY reliable lever is to stop the service itself, which runs
    // `stopForeground(STOP_FOREGROUND_REMOVE)` + cancels the notification
    // natively. Do it explicitly for the call CID we just left.
    await _stopCallForegroundService(call.callCid.value);
  }

  /// Force-stop the Stream call foreground service for [callCid] so its
  /// ongoing notification is removed (see the note in [leave]). Best-effort
  /// and idempotent — safe if the service already stopped.
  Future<void> _stopCallForegroundService(String callCid) async {
    try {
      final stopped = await StreamVideoFlutterBackground.stopService(
        ServiceType.call,
        callCid: callCid,
      );
      // ignore: avoid_print
      print('[StreamCallEngine] stopService(call, $callCid) → $stopped');
    } catch (e) {
      // ignore: avoid_print
      print('[StreamCallEngine] stopService(call, $callCid) failed: $e');
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
          _callEndedController.add(StreamCallEndReason.incomingCleared);
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
      // iOS-only push diagnostic — answers "does APN work?" without a
      // backend round-trip. Guarded to iOS so Android runtime is untouched.
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        await _logPushDiagnostics();
      }
    } catch (e) {
      // ignore: avoid_print
      print('[StreamCallEngine] ❌ connect failed: $e');
    }
  }

  /// One-shot iOS push diagnostic. Logs two independent facts:
  ///   1. Did iOS hand us an **APNs token**? (proves the push entitlement +
  ///      provisioning profile are working — null means no push can arrive.)
  ///   2. Is this device **registered with Stream** for call push, and is
  ///      there an `apn` provider entry? (proves Stream knows where to send
  ///      the incoming-call VoIP push.)
  /// Both are read-only lookups; nothing here changes call behaviour. iOS
  /// only — never runs on Android.
  Future<void> _logPushDiagnostics() async {
    // (1) FCM/remote APNs token — proves the push entitlement works.
    try {
      final apns = await FirebaseMessaging.instance.getAPNSToken();
      // ignore: avoid_print
      print(apns == null
          ? '[PushDiag] ❌ APN NOT WORKING — iOS APNs token is NULL. '
              '(entitlement/provisioning/paid-account issue.)'
          : '[PushDiag] ✅ APN TOKEN OK — iOS APNs token present '
              '(len=${apns.length}).');
    } catch (e) {
      // ignore: avoid_print
      print('[PushDiag] APNs token lookup threw: $e');
    }
    // (2) VoIP (PushKit) token — the token Stream actually registers for
    // CALL push. Separate from the APNs token above; delivered async by
    // PushKit, so it may be empty for a beat right after launch.
    try {
      final voip = await FlutterCallkitIncoming.getDevicePushTokenVoIP();
      // ignore: avoid_print
      print(voip == null || voip.isEmpty
          ? '[PushDiag] ⏳ VoIP (PushKit) token EMPTY so far — PushKit not yet '
              'delivered. If still empty after +delay, call push can\'t register.'
          : '[PushDiag] ✅ VoIP token present (len=${voip.length}).');
    } catch (e) {
      // ignore: avoid_print
      print('[PushDiag] VoIP token lookup threw: $e');
    }
    // (3) Stream device list — check now AND again after registration has
    // had time to settle (the VoIP token stream registers async).
    await _checkStreamDevices('at-connect');
    Future.delayed(const Duration(seconds: 10),
        () => _checkStreamDevices('+10s'));
  }

  /// Logs whether this user has any push devices registered with Stream,
  /// and whether an `apn` provider entry exists (the iOS call-push route).
  Future<void> _checkStreamDevices(String when) async {
    try {
      final devices = (await _client?.getDevices())?.getDataOrNull();
      if (devices == null) {
        // ignore: avoid_print
        print('[PushDiag/$when] ❌ getDevices() failed.');
        return;
      }
      if (devices.isEmpty) {
        // ignore: avoid_print
        print('[PushDiag/$when] ⚠ Stream has 0 registered push devices — '
            'call push will NOT be delivered.');
        return;
      }
      final hasApn = devices.any((d) =>
          d.pushProviderName == 'apn' ||
          d.pushProvider.toString().toLowerCase().contains('apn'));
      // ignore: avoid_print
      print('[PushDiag/$when] Stream devices: ${devices.length} · apn '
          'provider present: ${hasApn ? "✅ YES" : "❌ NO"}');
      for (final d in devices) {
        final tok = d.pushToken.length > 12
            ? '${d.pushToken.substring(0, 12)}…'
            : d.pushToken;
        // ignore: avoid_print
        print('[PushDiag/$when]   • provider=${d.pushProviderName ?? d.pushProvider} '
            'voip=${d.voip} disabled=${d.disabled} token=$tok');
      }
    } catch (e) {
      // ignore: avoid_print
      print('[PushDiag/$when] getDevices() threw: $e');
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
