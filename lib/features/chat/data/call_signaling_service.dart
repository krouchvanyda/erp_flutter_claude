import 'dart:async';

import 'package:flutter/foundation.dart';

import '../entities/call_log.dart';
import 'chat_settings.dart';
import 'chat_transport.dart';
import 'repositories/call_log_repository.dart';
import 'repositories/conversations_repository.dart';

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
    this.connectedAt,
    this.endReason,
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

  /// Why the call ended — populated only when [state] is
  /// [CallSignalState.ended]. Drives the snackbar / label on the
  /// caller's screen ("X is on another call" vs generic "Call ended").
  /// Values: `'busy'`, `'declined'`, `'hangup'`, or `null` when not
  /// applicable yet.
  final String? endReason;

  ActiveCall copyWith({
    CallSignalState? state,
    DateTime? connectedAt,
    String? endReason,
  }) =>
      ActiveCall(
        callId: callId,
        conversationId: conversationId,
        peerId: peerId,
        peerName: peerName,
        callType: callType,
        state: state ?? this.state,
        startedAt: startedAt,
        connectedAt: connectedAt ?? this.connectedAt,
        endReason: endReason ?? this.endReason,
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
  }) {
    _sub = transport.events.listen(_onEvent);
  }

  final ChatTransport transport;
  final ChatSettings settings;
  final ConversationsRepository conversations;
  final CallLogRepository callLog;

  StreamSubscription<ChatTransportEvent>? _sub;
  ActiveCall? _active;
  // Maps callId → callLog entry id so we can update on accept / end.
  final Map<String, String> _logIdByCallId = {};

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
    );
    _setActive(active);

    transport.sendCallInvite(
      callId: callId,
      conversationId: conversationId,
      callerId: me,
      callerName: myName,
      callType: callType,
      startedAt: now,
      targetIds: targetIds,
    );
    return active;
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
    transport.sendCallHangup(active.callId);
    final duration = active.connectedAt == null
        ? 0
        : endedAt.difference(active.connectedAt!).inSeconds;
    final logId = _logIdByCallId.remove(active.callId);
    if (logId != null) {
      await callLog.logEnded(
        id: logId,
        durationSeconds: duration,
        finalStatus: duration > 0 ? ChatCallStatus.answered : finalStatus,
      );
    }
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

  // ── Incoming (peer is the caller, we're the callee) ──────────

  /// Callee tapped Accept on the incoming sheet.
  Future<void> acceptIncoming() async {
    final active = _active;
    if (active == null || active.state != CallSignalState.incomingRinging) {
      return;
    }
    transport.sendCallAccept(active.callId);
    final connectedAt = DateTime.now();
    final logId = _logIdByCallId[active.callId];
    if (logId != null) await callLog.logAnswered(logId);
    _setActive(
      active.copyWith(
        state: CallSignalState.connected,
        connectedAt: connectedAt,
      ),
    );
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
    _setActive(null);
  }

  // ── Inbound transport events ─────────────────────────────────

  Future<void> _onEvent(ChatTransportEvent event) async {
    switch (event) {
      case CallInviteEvent(:final callId, :final conversationId, :final callerId, :final callerName, :final callType, :final startedAt, :final targetIds):
        // Ignore self-echo if it ever happens (shouldn't — the relay
        // filters the originating socket).
        if (callerId == settings.userId) return;
        // Slice 10.2.7 — drop invites that weren't addressed to us.
        // Empty targetIds = pre-10.2.7 caller, ring through for
        // backward compatibility.
        if (targetIds.isNotEmpty && !targetIds.contains(settings.userId)) {
          return;
        }
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
        _setActive(ActiveCall(
          callId: callId,
          conversationId: conversationId,
          peerId: callerId,
          peerName: callerName,
          callType: callType,
          state: CallSignalState.incomingRinging,
          startedAt: startedAt,
        ));
      case CallAcceptEvent(:final callId):
        // Peer accepted our outgoing invite — transition to connected.
        final active = _active;
        if (active == null || active.callId != callId) return;
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
      case CallHangupEvent(:final callId):
        final active = _active;
        if (active == null || active.callId != callId) return;
        final endedAt = DateTime.now();
        final duration = active.connectedAt == null
            ? 0
            : endedAt.difference(active.connectedAt!).inSeconds;
        final logId = _logIdByCallId.remove(callId);
        if (logId != null) {
          await callLog.logEnded(
            id: logId,
            durationSeconds: duration,
            finalStatus: duration > 0
                ? ChatCallStatus.answered
                : ChatCallStatus.noAnswer,
          );
        }
        _setActive(active.copyWith(state: CallSignalState.ended));
        Future.delayed(const Duration(milliseconds: 600), () {
          if (_active?.callId == active.callId &&
              _active?.state == CallSignalState.ended) {
            _setActive(null);
          }
        });
      default:
        // Chat-message events handled elsewhere.
        break;
    }
  }

  void _setActive(ActiveCall? next) {
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
  }
}

class _PeerHint {
  const _PeerHint({required this.id, required this.name});
  final String id;
  final String name;
}
