import 'dart:async';

import 'package:flutter/foundation.dart';

import '../entities/call_log.dart';
import 'chat_settings.dart';
import 'chat_transport.dart';
import 'chats_remote_data_source.dart';
import 'repositories/call_log_repository.dart';
import 'repositories/conversations_repository.dart';
import 'stream_call_engine.dart';

/// Slice 10.2.3 — local state of an active or incoming call.
enum CallSignalState {
  idle,

  /// We pressed Call — waiting for the peer to accept.
  outgoingRinging,

  /// Peer pressed Call — waiting for us to accept/reject.
  incomingRinging,

  /// Either we accepted their invite or they accepted ours.
  connected,

  /// Either side hung up, or the invite was rejected / timed out.
  ended,
}

/// Snapshot of the currently-active call, surfaced to the UI.
class ActiveCall {
  const ActiveCall({
    required this.callId,
    required this.conversationId,
    required this.peerId,
    required this.peerName,
    required this.callType,
    required this.state,
    required this.startedAt,
    required this.callerId,
    this.connectedAt,
    this.endReason,
    this.conversationName,
    this.isGroup = false,
    this.conversationAvatarFilePath,
    this.streamCallCid,
  });

  final String callId;
  final String conversationId;

  /// The OTHER party — for outgoing calls this is the callee, for
  /// incoming this is the caller. Always "the person on the other end
  /// of this connection".
  final String peerId;
  final String peerName;

  final ChatCallType callType;
  final CallSignalState state;
  final DateTime startedAt;
  final DateTime? connectedAt;

  /// Slice 10.2.10 — userId of whoever ORIGINATED the call (the
  /// outgoing-invite sender). For outgoing this equals `settings.userId`;
  /// for incoming this equals `event.callerId`. Used on hangup events
  /// for group calls: only the caller's hangup ends the call for
  /// everyone — a callee tapping End in a group just leaves their own
  /// client (multi-party semantics, mirrors Telegram group calls).
  final String callerId;

  /// Why the call ended — populated only when [state] is
  /// [CallSignalState.ended]. Drives the snackbar / label on the
  /// caller's screen ("X is on another call" vs generic "Call ended").
  /// Values: `'busy'`, `'declined'`, `'hangup'`, or `null` when not
  /// applicable yet.
  final String? endReason;

  /// Slice 10.2.9 — name of the conversation the call belongs to.
  /// For direct calls this equals [peerName] (so the sheet behaves the
  /// same as before); for group calls this is the GROUP name so the
  /// incoming sheet on Pisey / Channary's phone shows "TEST01" with
  /// "Vibol is calling" as a subtitle, instead of just "Vibol".
  final String? conversationName;

  /// Slice 10.2.9 — true if the underlying conversation is a group.
  /// Drives the incoming-sheet header layout (group avatar cluster +
  /// "Group call" label).
  final bool isGroup;

  /// Slice 10.2.11 — local file path of the conversation's photo (set
  /// via Slice 10.3.3 / 10.3.5). Surfaced on the incoming-call sheet
  /// + call page hero so a group call to TEST01 with a custom photo
  /// shows that photo instead of just an icon.
  final String? conversationAvatarFilePath;

  /// Stream Video call CID (e.g. `default:abc123`) — opaque to the
  /// signalling layer, fed straight into `StreamCallEngine.join(...)`
  /// once both sides have accepted. Null when the backend hasn't
  /// shipped Stream integration yet — call stays signalling-only.
  final String? streamCallCid;

  ActiveCall copyWith({
    String? callId,
    CallSignalState? state,
    DateTime? connectedAt,
    String? endReason,
    String? streamCallCid,
  }) =>
      ActiveCall(
        callId: callId ?? this.callId,
        conversationId: conversationId,
        peerId: peerId,
        peerName: peerName,
        callType: callType,
        state: state ?? this.state,
        startedAt: startedAt,
        callerId: callerId,
        connectedAt: connectedAt ?? this.connectedAt,
        endReason: endReason ?? this.endReason,
        conversationName: conversationName,
        isGroup: isGroup,
        conversationAvatarFilePath: conversationAvatarFilePath,
        streamCallCid: streamCallCid ?? this.streamCallCid,
      );
}

/// Singleton coordinator that turns [ChatTransport] envelopes into
/// typed [ActiveCall] state transitions, and exposes the helpers the
/// call pages call (`startOutgoing`, `acceptIncoming`, `hangup`,
/// `reject`).
///
/// Demo-grade: there's no real media — once both sides reach
/// [CallSignalState.connected] the pages just show the in-call UI
/// and tick a timer. Real WebRTC would slot in here (offer/answer +
/// ICE candidates flowing through the same transport).
class CallSignalingService {
  CallSignalingService({
    required this.transport,
    required this.settings,
    required this.conversations,
    required this.callLog,
    required this.remote,
    required this.streamEngine,
  }) {
    _sub = transport.events.listen(_onEvent);
  }

  final ChatTransport transport;
  final ChatSettings settings;
  final ConversationsRepository conversations;
  final CallLogRepository callLog;
  final ChatsRemoteDataSource remote;
  final StreamCallEngine streamEngine;

  StreamSubscription<ChatTransportEvent>? _sub;
  ActiveCall? _active;
  // Maps callId → callLog entry id so we can update on accept / end.
  final Map<String, String> _logIdByCallId = {};

  /// Slice 10.2.11 — caller-only set of group callees currently joined
  /// to the active call. Populated when we (the caller) receive a
  /// CallAcceptEvent with an accepterId, drained as those callees
  /// later send CallHangupEvent. When the set drains to empty in a
  /// group call we auto-hangup so the caller isn't left alone with a
  /// running timer after everyone else has bowed out (Telegram model:
  /// last-person-out closes the call). Direct 1:1 calls ignore this
  /// — there are only two parties and either side ending is already
  /// canonical (Slice 10.2.10).
  final Set<String> _activeCallees = {};

  /// Reactive view of the active call. Null = no call in flight.
  ///
  /// Backed by a [ValueNotifier] instead of a Stream so the overlay
  /// and call pages can never miss an update between rebuilds — the
  /// notifier always replays its current value to any new listener.
  /// The previous `async*` getter created a fresh stream per access
  /// and could drop events during the resubscribe window, which made
  /// stuck `incomingRinging` states (incoming-call sheet never showing,
  /// repeat invites auto-rejected) really easy to hit.
  final ValueNotifier<ActiveCall?> activeCallListenable =
      ValueNotifier<ActiveCall?>(null);

  ActiveCall? get current => _active;

  Timer? _ringTimeout;

  Future<void> dispose() async {
    await _sub?.cancel();
    _ringTimeout?.cancel();
    activeCallListenable.dispose();
  }

  /// Slice 10.2.10 — Telegram-style call summary written to the conv's
  /// `lastMessage` so the inbox tile shows recent call history inline
  /// (no separate Calls tab required to know "Vibol called you 5 min
  /// ago"). Hooked into every end path: local hangup, peer hangup, and
  /// reject (both directions).
  Future<void> _writeCallSummary(
    ActiveCall active, {
    required ChatCallStatus finalStatus,
    required int durationSeconds,
  }) async {
    final isVideo = active.callType == ChatCallType.video;
    final emoji = isVideo ? '📹' : '📞';
    final kind = isVideo ? 'video' : 'voice';
    String body;
    switch (finalStatus) {
      case ChatCallStatus.answered:
        final m = (durationSeconds ~/ 60).toString().padLeft(1, '0');
        final s = (durationSeconds % 60).toString().padLeft(2, '0');
        body = '$emoji ${isVideo ? "Video" : "Voice"} call · $m:$s';
      case ChatCallStatus.missed:
      case ChatCallStatus.noAnswer:
        body = '$emoji Missed $kind call';
      case ChatCallStatus.rejected:
        body = '$emoji Declined $kind call';
    }
    // Slice 10.2.11 — for DIRECT calls, redirect the summary to our
    // own local direct conv with the peer (mirrors Slice 10.1.8 for
    // messages). The seed reuses ids like conv-005 across devices, so
    // writing the summary to active.conversationId on the callee
    // would land it in the WRONG local tile. For groups the conv id
    // is shared (via Slice 10.1.7 broadcast) and works as-is.
    String targetConvId = active.conversationId;
    if (!active.isGroup) {
      final me = settings.userId;
      // Find the OTHER party in this 1:1 call.
      final otherId =
          active.callerId == me ? active.peerId : active.callerId;
      final localConv = await conversations.findDirectWith(otherId);
      if (localConv != null) {
        targetConvId = localConv.id;
      }
    }
    try {
      // Use `callerId` as senderId so the inbox renders "You: 📞 …"
      // for the caller and the bare preview for the callee.
      await conversations.updateLastMessage(
        id: targetConvId,
        body: body,
        senderId: active.callerId,
        senderName: active.peerName,
        type: 'system',
        at: DateTime.now(),
      );
    } catch (_) {
      // Conv may not exist locally (e.g. seeded mismatch); swallow.
    }
  }

  // ── Outbound (this device is the caller) ─────────────────────

  /// Place a new call. Pre-creates a local `chat_call_log` entry
  /// (status: `noAnswer`) and broadcasts a `call.invite` envelope to
  /// the peer. Returns the new `callId` so the calling page can wait
  /// on state changes via [activeCall].
  Future<ActiveCall> startOutgoing({
    required String conversationId,
    required ChatCallType callType,
  }) async {
    final conv = await conversations.findById(conversationId);
    final me = settings.userId;
    final myName = settings.userName;
    // Slice 10.2.7 — targeted call routing. Build the recipient list
    // from the conversation's participants so the relay only rings the
    // intended callee(s):
    //   * direct conv → the single other person (seeded in
    //     participantPreviews now that 10.2.7 needs that id)
    //   * group conv → every member except us
    // Empty list falls back to "ring everyone" so legacy convs that
    // never got a participantPreviews backfill still work.
    final targetIds = conv == null
        ? const <String>[]
        : conv.participantPreviews
            .where((p) => p.employeeId != me)
            .map((p) => p.employeeId)
            .toList(growable: false);

    // Peer hint for the local UI ("calling X…"). Direct convs use
    // the first (and only) participant; group convs fall back to the
    // conversation name.
    final peer = (conv != null &&
            !conv.isGroup &&
            conv.participantPreviews.isNotEmpty)
        ? _PeerHint(
            id: conv.participantPreviews.first.employeeId,
            name: conv.participantPreviews.first.name,
          )
        : (conv != null && conv.isGroup
            ? conv.participantPreviews
                .where((p) => p.employeeId != me)
                .map((p) => _PeerHint(id: p.employeeId, name: p.name))
                .firstOrNull
            : null);

    final now = DateTime.now();
    final callId = 'call-$me-${now.microsecondsSinceEpoch}';
    final logged = await callLog.logStart(
      conversationId: conversationId,
      callerId: me,
      callerName: myName,
      callType: callType,
      at: now,
    );
    _logIdByCallId[callId] = logged.id;

    final active = ActiveCall(
      callId: callId,
      conversationId: conversationId,
      peerId: peer?.id ?? 'peer-unknown',
      peerName: peer?.name ?? conv?.name ?? 'Unknown',
      callType: callType,
      state: CallSignalState.outgoingRinging,
      startedAt: now,
      callerId: me,
      conversationName: conv?.name,
      isGroup: conv?.isGroup ?? false,
      conversationAvatarFilePath: conv?.avatarFilePath,
    );
    // Slice 10.2.11 — fresh outgoing call, reset the joined-callees
    // set so leftovers from a prior call can't confuse the auto-end.
    _activeCallees.clear();
    _setActive(active);
    // Subscribe to the per-call topic so we (the caller) see every
    // callee's accept / reject / hangup. Idempotent.
    transport.subscribeConversation(conversationId);

    // POST /chats/conversations/{id}/calls and await the canonical
    // backend call id — then swap it in. The local placeholder
    // `call-<me>-<ts>` is a UUID stand-in for the period BETWEEN our
    // tap and the backend acknowledging; without the swap, the
    // caller's Accept/Reject/End buttons would call REST endpoints
    // with a non-numeric id and silently no-op (transport's
    // `int.tryParse` would fail). Fire-and-forget so the call page
    // can render the ringing UI immediately.
    unawaited(transport
        .sendCallInvite(
      callId: callId,
      conversationId: conversationId,
      callerId: me,
      callerName: myName,
      callType: callType,
      startedAt: now,
      targetIds: targetIds,
    )
        .then((response) async {
      if (response == null) return;
      final backendCallId = response['id']?.toString() ?? '';
      final streamCallCid = response['streamCallCid'] as String?;
      if (backendCallId.isEmpty) return;
      final cur = _active;
      // Only swap if this is still the same call (user might have
      // hung up before the backend responded).
      if (cur == null || cur.callId != callId) return;
      // Move the call-log mapping over so end / reject can still
      // find the right log row.
      final logId = _logIdByCallId.remove(callId);
      if (logId != null) _logIdByCallId[backendCallId] = logId;
      _setActive(cur.copyWith(
        callId: backendCallId,
        streamCallCid: streamCallCid,
      ));
      // Bring the media leg up (audio/video) once the chat side has
      // acknowledged the call. join() is idempotent + swallows
      // failures internally; if the backend hasn't shipped Stream
      // integration the call falls back to signalling-only.
      if (streamCallCid != null && streamCallCid.isNotEmpty) {
        // Pass `calleeUserIds` + `shouldRing: true` so Stream's
        // backend pushes the VoIP notification to every callee — that
        // is what triggers the native full-screen ringer on B's phone
        // when A presses Call. Without these args Stream creates the
        // call silently and nobody else's phone ever wakes up.
        unawaited(streamEngine.join(
          streamCallCid: streamCallCid,
          isVideo: callType == ChatCallType.video,
          calleeUserIds: targetIds,
          shouldRing: true,
        ));
      }
    }).catchError((Object e) {
      // POST failed — most common cause is a stale RINGING/ANSWERED
      // call row on the server (force-killed app, crash mid-call).
      // Roll back from outgoingRinging → ended so the call page
      // pops itself and the user sees the snackbar instead of being
      // stuck on "Calling…" until the 30 s ring timeout fires.
      final cur = _active;
      if (cur == null || cur.callId != callId) return;
      final message = _extractBackendMessage(e);
      final reason = (message != null &&
              message.toLowerCase().contains('already in an active call'))
          ? 'already_in_call'
          : 'failed';
      _setActive(cur.copyWith(
        state: CallSignalState.ended,
        endReason: reason,
      ));
      // Drop the active reference after the page has had a beat to
      // render the ended state.
      Future.delayed(const Duration(milliseconds: 600), () {
        if (_active?.callId == callId &&
            _active?.state == CallSignalState.ended) {
          _setActive(null);
        }
      });
    }));
    return active;
  }

  /// Seed `_active` from an FCM `call.invite` push payload — used when
  /// the app was minimized or killed and missed the matching STOMP
  /// envelope. Once `_active` is set to `incomingRinging`, the existing
  /// [acceptIncoming] / [rejectIncoming] paths and the in-app
  /// `IncomingCallOverlay` all work identically to the WS path.
  ///
  /// Expected payload (matches `docs/FCM_BACKGROUND_CALLS_PLAN.md`):
  /// ```json
  /// { "type": "call.invite",
  ///   "callId": "...",
  ///   "conversationId": "...",
  ///   "callerId": "...",
  ///   "callerName": "...",
  ///   "callType": "voice" | "video",
  ///   "startedAt": "<ISO-8601>",
  ///   "streamCallCid": "default:..." }
  /// ```
  ///
  /// Idempotent: if `_active` is already set to the same callId (the
  /// WS event raced ahead of the push), this is a no-op so the user
  /// doesn't see the incoming sheet flash twice.
  Future<void> handleIncomingFromPush(Map<String, dynamic> data) async {
    if (data['type'] != 'call.invite') return;
    final callId = data['callId']?.toString();
    final conversationId = data['conversationId']?.toString();
    final callerId = data['callerId']?.toString();
    final callerName = data['callerName']?.toString() ?? 'Unknown';
    if (callId == null || conversationId == null || callerId == null) return;

    // Race-window dedupe — WS may have already delivered the same
    // invite by the time the user taps the notification.
    if (_active?.callId == callId) return;

    // Busy: already in a non-pending call. Surface the busy reason to
    // the caller; do NOT replace our own state.
    if (_active != null &&
        _active!.state != CallSignalState.incomingRinging &&
        _active!.state != CallSignalState.ended) {
      transport.sendCallReject(callId, reason: 'busy');
      return;
    }

    final callType = data['callType']?.toString() == 'video'
        ? ChatCallType.video
        : ChatCallType.voice;
    final startedAt =
        DateTime.tryParse(data['startedAt']?.toString() ?? '')?.toUtc() ??
            DateTime.now().toUtc();
    final streamCallCid = data['streamCallCid']?.toString();

    // Log a missed-by-default row so the inbox tile / call history
    // reflects the call attempt even if the user never opens it.
    final logged = await callLog.logStart(
      conversationId: conversationId,
      callerId: callerId,
      callerName: callerName,
      callType: callType,
      at: startedAt,
    );
    _logIdByCallId[callId] = logged.id;

    final conv = await conversations.findById(conversationId);
    _setActive(ActiveCall(
      callId: callId,
      conversationId: conversationId,
      peerId: callerId,
      peerName: callerName,
      callType: callType,
      state: CallSignalState.incomingRinging,
      startedAt: startedAt,
      callerId: callerId,
      conversationName: conv?.name,
      isGroup: conv?.isGroup ?? false,
      conversationAvatarFilePath: conv?.avatarFilePath,
      streamCallCid: streamCallCid,
    ));
    // Subscribe so the matching `call.hangup` / `call.accept` frames
    // that arrive AFTER reconnect land on this service instead of
    // disappearing into the void.
    transport.subscribeConversation(conversationId);
  }

  /// Pull the human-readable `message` out of a DioException body
  /// (the backend's standard envelope is `{success, message, …}`).
  /// Returns null if the error isn't a DioException with a JSON body.
  static String? _extractBackendMessage(Object e) {
    try {
      final data = (e as dynamic).response?.data;
      if (data is Map && data['message'] is String) return data['message'] as String;
    } catch (_) {}
    return null;
  }

  /// Outgoing call: peer either rejected or we cancelled before they
  /// answered. Send hangup, log as `rejected`/`noAnswer`, drop state.
  /// Same call used by both sides when they tap End — the canonical
  /// "this call is over now".
  Future<void> hangup({
    ChatCallStatus finalStatus = ChatCallStatus.answered,
  }) async {
    final active = _active;
    if (active == null) return;
    final endedAt = DateTime.now();
    // Slice 10.2.10 — tag the hangup with our own id so group-call
    // peers can tell whether to end the call for everyone (caller
    // bowed out) or just ignore (one of N callees left, group call
    // continues).
    transport.sendCallHangup(
      active.callId,
      hangerUpperId: settings.userId,
    );
    final duration = active.connectedAt == null
        ? 0
        : endedAt.difference(active.connectedAt!).inSeconds;
    final logId = _logIdByCallId.remove(active.callId);
    final resolvedStatus =
        duration > 0 ? ChatCallStatus.answered : finalStatus;
    if (logId != null) {
      await callLog.logEnded(
        id: logId,
        durationSeconds: duration,
        finalStatus: resolvedStatus,
      );
    }
    // Slice 10.2.10 — surface the call summary on the inbox tile.
    unawaited(_writeCallSummary(
      active,
      finalStatus: resolvedStatus,
      durationSeconds: duration,
    ));
    _setActive(active.copyWith(state: CallSignalState.ended));
    // Drop the active reference after a brief delay so the call page
    // can render the "ended" state before it pops itself.
    Future.delayed(const Duration(milliseconds: 600), () {
      if (_active?.callId == active.callId &&
          _active?.state == CallSignalState.ended) {
        _setActive(null);
      }
    });
  }

  /// GET /chats/calls/{id} — recover the canonical call state from
  /// the backend. Used when the app resumes from background and
  /// might have missed `call.accept` / `call.hangup` STOMP frames
  /// while disconnected (Slice 10.2.6 — `ChatLifecycleBridge` doesn't
  /// cover call-state recovery on its own).
  ///
  /// Applies whatever the server says onto our local [_active]:
  ///   * `status: ANSWERED`     → connected (start the timer)
  ///   * `status: REJECTED`     → ended with the server's `endReason`
  ///   * `status: ENDED`        → ended (closes the page)
  ///   * `status: MISSED`/`NO_ANSWER` → ended (closes the page)
  ///   * `status: RINGING`      → leave the local state alone — the
  ///     STOMP path will catch up; we don't downgrade `connected` back
  ///     to ringing.
  ///
  /// No-op when there's no active call, when the active call's id
  /// isn't a backend id (still local placeholder pre-`sendCallInvite`
  /// response), or when the GET fails.
  Future<void> reconcileActive() async {
    final active = _active;
    if (active == null) return;
    final n = int.tryParse(active.callId);
    if (n == null) return;
    Map<String, dynamic> dto;
    try {
      dto = await remote.getCall(n);
    } catch (_) {
      return;
    }
    final status = (dto['status'] as String? ?? '').toUpperCase();
    switch (status) {
      case 'ANSWERED':
        // Already connected locally? leave the timer running.
        if (active.state == CallSignalState.connected) return;
        final answeredAt = DateTime.tryParse(
                dto['answeredAt'] as String? ?? '') ??
            DateTime.now();
        _setActive(active.copyWith(
          state: CallSignalState.connected,
          connectedAt: answeredAt,
        ));
      case 'REJECTED':
        final reason = dto['endReason'] as String? ?? 'declined';
        _setActive(active.copyWith(
          state: CallSignalState.ended,
          endReason: reason,
        ));
        Future.delayed(const Duration(milliseconds: 600), () {
          if (_active?.callId == active.callId &&
              _active?.state == CallSignalState.ended) {
            _setActive(null);
          }
        });
      case 'ENDED':
      case 'MISSED':
      case 'NO_ANSWER':
        _setActive(active.copyWith(state: CallSignalState.ended));
        Future.delayed(const Duration(milliseconds: 600), () {
          if (_active?.callId == active.callId &&
              _active?.state == CallSignalState.ended) {
            _setActive(null);
          }
        });
      default:
        // RINGING / unknown — keep local state, STOMP will reconcile.
        return;
    }
  }

  // ── Incoming (peer is the caller, we're the callee) ──────────

  /// Callee tapped Accept on the incoming sheet.
  Future<void> acceptIncoming() async {
    final active = _active;
    if (active == null || active.state != CallSignalState.incomingRinging) {
      return;
    }
    // Slice 10.2.11 — tag with our id so the caller can track which
    // callees are currently joined and auto-end when the last one
    // leaves a group call.
    //
    // Await the POST response so we can:
    //   * pick up the latest `streamCallCid` from the canonical DTO
    //     (the invite may not have included it on some backends)
    //   * skip the Stream join + state transition entirely if the
    //     server returned 4xx (call already ended on its side)
    final response = await transport.sendCallAccept(
      active.callId,
      accepterId: settings.userId,
    );
    if (response == null) {
      // Accept failed — surface as "ended" so the page pops itself.
      _setActive(active.copyWith(
        state: CallSignalState.ended,
        endReason: 'hangup',
      ));
      return;
    }
    final connectedAt = DateTime.now();
    final logId = _logIdByCallId[active.callId];
    if (logId != null) await callLog.logAnswered(logId);
    // Use the cid from the response if present; otherwise stick
    // with whatever the invite carried.
    final streamCallCid = (response['streamCallCid'] as String?) ??
        active.streamCallCid;
    _setActive(
      active.copyWith(
        state: CallSignalState.connected,
        connectedAt: connectedAt,
        streamCallCid: streamCallCid,
      ),
    );
    // Bring the media leg up — audio + (for video calls) camera.
    // `shouldRing: false` because we're the CALLEE accepting an
    // invite — the call has already been ringing us. Re-firing the
    // ring from this side would push the VoIP notification to
    // ourselves + the caller (loop).
    if (streamCallCid != null && streamCallCid.isNotEmpty) {
      unawaited(streamEngine.join(
        streamCallCid: streamCallCid,
        isVideo: active.callType == ChatCallType.video,
        shouldRing: false,
      ));
    }
  }

  /// Callee tapped Reject — tell the caller, log as rejected, drop.
  Future<void> rejectIncoming() async {
    final active = _active;
    if (active == null) return;
    transport.sendCallReject(active.callId, reason: 'declined');
    final logId = _logIdByCallId.remove(active.callId);
    if (logId != null) {
      await callLog.logEnded(
        id: logId,
        durationSeconds: 0,
        finalStatus: ChatCallStatus.rejected,
      );
    }
    // Slice 10.2.10 — leave a "📞 Missed/Declined call" tile preview.
    unawaited(_writeCallSummary(
      active,
      finalStatus: ChatCallStatus.rejected,
      durationSeconds: 0,
    ));
    _setActive(null);
  }

  // ── Inbound transport events ─────────────────────────────────

  Future<void> _onEvent(ChatTransportEvent event) async {
    switch (event) {
      case CallInviteEvent(:final callId, :final conversationId, :final callerId, :final callerName, :final callType, :final startedAt, :final targetIds):
        // Ignore self-echo if it ever happens.
        if (callerId == settings.userId) return;
        // Routing note: with the real backend, invites land on
        // `/user/queue/calls` — a per-user channel. If a frame
        // arrives here it's already addressed to us, so we must NOT
        // client-side-filter by `targetIds` (decoded from
        // ChatCallDto.participants). The participants array at
        // invite time can lag (callees not yet marshalled), which
        // would falsely drop the invite. `targetIds` is kept on the
        // event for the legacy LAN-relay broadcast path only.
        // ignore: unused_local_variable
        final _ = targetIds; // intentionally unused on the real backend
        // A new invite while we're in another non-pending call (in an
        // ongoing connected call, or our own outgoing invite) → busy
        // signal back. Replace stale `incomingRinging`/`ended` states
        // instead of auto-rejecting forever so the next attempt from
        // the same caller actually rings through.
        final prior = _active;
        if (prior != null &&
            prior.state != CallSignalState.incomingRinging &&
            prior.state != CallSignalState.ended) {
          // Slice 10.2.4 — explicit busy reason so the caller can show
          // "X is on another call" instead of a generic "Call ended".
          transport.sendCallReject(callId, reason: 'busy');
          return;
        }
        if (prior != null) {
          // Drop the prior log row so we don't leak entries.
          _logIdByCallId.remove(prior.callId);
        }
        final logged = await callLog.logStart(
          conversationId: conversationId,
          callerId: callerId,
          callerName: callerName,
          callType: callType,
          at: startedAt,
        );
        _logIdByCallId[callId] = logged.id;
        // Slice 10.2.9 — look up the local conv so the incoming sheet
        // can show the GROUP name (e.g. "TEST01") with "Vibol is
        // calling" as a subtitle, instead of just "Vibol". Direct
        // calls keep showing the caller's name as the header.
        final conv = await conversations.findById(conversationId);
        _setActive(ActiveCall(
          callId: callId,
          conversationId: conversationId,
          peerId: callerId,
          peerName: callerName,
          callType: callType,
          state: CallSignalState.incomingRinging,
          startedAt: startedAt,
          callerId: callerId,
          conversationName: conv?.name,
          isGroup: conv?.isGroup ?? false,
          conversationAvatarFilePath: conv?.avatarFilePath,
        ));
        // Subscribe to `/topic/conversations/{convId}/call` so the
        // accept / reject / hangup frames that come AFTER the invite
        // land here — without this, the per-call topic is only
        // attached when the user opens the chat page, which may not
        // happen before the call wraps up. Idempotent: no-op if
        // already subscribed.
        transport.subscribeConversation(conversationId);
      case CallAcceptEvent(:final callId, :final accepterId):
        // Peer accepted our outgoing invite — transition to connected.
        final active = _active;
        if (active == null || active.callId != callId) return;
        // Slice 10.2.8 — only the original caller should react to an
        // accept event. In a group call every callee shares the same
        // callId, so without this guard one callee tapping Accept
        // would yank every OTHER callee straight from incomingRinging
        // into connected, closing their incoming sheet without them
        // ever choosing. Each callee gets to accept independently.
        // Slice 10.2.11 extends this: once we (the caller) are in
        // `connected`, subsequent group accepts still need to count
        // toward the active-callee set so we know when the last
        // callee leaves and can auto-end.
        if (active.state != CallSignalState.outgoingRinging &&
            active.state != CallSignalState.connected) {
          return;
        }
        if (accepterId != null) _activeCallees.add(accepterId);
        if (active.state == CallSignalState.connected) {
          // Already connected (another callee joined first). Nothing
          // to transition — the joiner is now tracked.
          return;
        }
        final connectedAt = DateTime.now();
        final logId = _logIdByCallId[callId];
        if (logId != null) await callLog.logAnswered(logId);
        _setActive(active.copyWith(
          state: CallSignalState.connected,
          connectedAt: connectedAt,
        ));
      case CallRejectEvent(:final callId, :final reason):
        final active = _active;
        if (active == null || active.callId != callId) return;
        final logId = _logIdByCallId.remove(callId);
        if (logId != null) {
          await callLog.logEnded(
            id: logId,
            durationSeconds: 0,
            finalStatus: ChatCallStatus.rejected,
          );
        }
        // Slice 10.2.10 — caller-side summary on the inbox tile.
        unawaited(_writeCallSummary(
          active,
          finalStatus: ChatCallStatus.rejected,
          durationSeconds: 0,
        ));
        _setActive(active.copyWith(
          state: CallSignalState.ended,
          endReason: reason ?? 'declined',
        ));
        Future.delayed(const Duration(milliseconds: 600), () {
          if (_active?.callId == active.callId &&
              _active?.state == CallSignalState.ended) {
            _setActive(null);
          }
        });
      case CallHangupEvent(:final callId, :final hangerUpperId):
        final active = _active;
        if (active == null || active.callId != callId) return;
        // Slice 10.2.10 — multi-party group call semantics. When the
        // hangup is from one of the OTHER callees in a group call
        // (not the caller, not us), it means that one peer just left.
        // The rest of us stay connected — the call continues, our
        // timer keeps ticking. Only the caller's hangup ends the call
        // for everyone. Direct calls (1:1) keep the old "either side
        // ends it" behaviour because there's nobody else to stay
        // connected with. Pre-10.2.10 clients on the wire don't send
        // hangerUpperId, so null falls back to the old behaviour.
        if (active.isGroup &&
            hangerUpperId != null &&
            hangerUpperId != active.callerId &&
            hangerUpperId != settings.userId) {
          // Slice 10.2.11 — if WE are the caller, the callee that
          // just left was tracked in `_activeCallees`; drain them.
          // When the set hits empty the call has no remaining
          // participants and we auto-hangup so the caller isn't left
          // alone with a running timer (mirrors Telegram's
          // last-person-out behaviour for group calls).
          final iAmCaller = active.callerId == settings.userId;
          if (iAmCaller) {
            _activeCallees.remove(hangerUpperId);
            if (_activeCallees.isEmpty) {
              unawaited(hangup(finalStatus: ChatCallStatus.answered));
            }
          }
          return;
        }
        final endedAt = DateTime.now();
        final duration = active.connectedAt == null
            ? 0
            : endedAt.difference(active.connectedAt!).inSeconds;
        final logId = _logIdByCallId.remove(callId);
        final resolvedStatus = duration > 0
            ? ChatCallStatus.answered
            : ChatCallStatus.noAnswer;
        if (logId != null) {
          await callLog.logEnded(
            id: logId,
            durationSeconds: duration,
            finalStatus: resolvedStatus,
          );
        }
        // Slice 10.2.10 — surface the call summary on the inbox tile.
        unawaited(_writeCallSummary(
          active,
          finalStatus: resolvedStatus,
          durationSeconds: duration,
        ));
        _setActive(active.copyWith(state: CallSignalState.ended));
        Future.delayed(const Duration(milliseconds: 600), () {
          if (_active?.callId == active.callId &&
              _active?.state == CallSignalState.ended) {
            _setActive(null);
          }
        });
      default:
        // Chat-message + conversation-create events handled elsewhere.
        break;
    }
  }

  void _setActive(ActiveCall? next) {
    final prev = _active;
    _active = next;
    activeCallListenable.value = next;
    // (Re)start the 30s safety timeout whenever we enter
    // incomingRinging, so a stuck invite (sheet never shown, peer
    // never answered) eventually clears itself and stops auto-
    // rejecting follow-up invites.
    _ringTimeout?.cancel();
    if (next != null && next.state == CallSignalState.incomingRinging) {
      _ringTimeout = Timer(const Duration(seconds: 30), () {
        if (_active?.callId == next.callId &&
            _active?.state == CallSignalState.incomingRinging) {
          unawaited(rejectIncoming());
        }
      });
    }

    // Tear down the Stream media leg the moment the call leaves
    // `connected` (either ENDED in place or fully cleared to null).
    // Covers every termination path — local End, peer hangup, busy,
    // missed, accept-failed — without each caller having to
    // remember to call `streamEngine.leave()` itself.
    final wasLive = prev?.state == CallSignalState.connected;
    final stillLive = next?.state == CallSignalState.connected;
    if (wasLive && !stillLive) {
      unawaited(streamEngine.leave());
    }
  }
}

class _PeerHint {
  const _PeerHint({required this.id, required this.name});
  final String id;
  final String name;
}
