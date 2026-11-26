part of 'call_view_model_bloc.dart';

/// The call screen's phases (Step 6.1):
///
/// ```
/// Idle ─► Outgoing ─► InCall ─► Ended ─► Idle
///    └──► Incoming ──┘    (any phase ─► Ended)
/// ```
@immutable
sealed class CallViewModelState {
  const CallViewModelState();

  /// A call is on screen and not finished → I'm busy: 📞 is greyed and a new
  /// invite is rejected with `busy`.
  bool get isActive => switch (this) {
    CallOutgoingState() || CallIncomingState() || CallInCallState() => true,
    CallIdleState() || CallEndedState() => false,
  };

  /// The server's call id, once known.
  String? get callId => switch (this) {
    CallOutgoingState(:final call) => call?.id,
    CallIncomingState(:final call) || CallInCallState(:final call) => call.id,
    CallIdleState() || CallEndedState() => null,
  };
}

/// No call.
final class CallIdleState extends CallViewModelState {
  const CallIdleState();

  @override
  bool operator ==(Object other) => other is CallIdleState;

  @override
  int get hashCode => 0;
}

/// I'm calling. [call] is null while `POST /calls` is on its way.
final class CallOutgoingState extends CallViewModelState {
  const CallOutgoingState({
    required this.conversationId,
    required this.peer,
    required this.type,
    this.call,
    this.peerRinging = false,
  });

  final String conversationId;
  final CallPeer peer;
  final CallType type;
  final CallModel? call;

  /// Their phone shows the call → "Ringing…" (else "Calling…").
  final bool peerRinging;

  CallOutgoingState copyWith({CallModel? call, bool? peerRinging}) =>
      CallOutgoingState(
        conversationId: conversationId,
        peer: peer,
        type: type,
        call: call ?? this.call,
        peerRinging: peerRinging ?? this.peerRinging,
      );

  @override
  bool operator ==(Object other) =>
      other is CallOutgoingState &&
      other.conversationId == conversationId &&
      other.peer == peer &&
      other.type == type &&
      other.call == call &&
      other.peerRinging == peerRinging;

  @override
  int get hashCode =>
      Object.hash(conversationId, peer, type, call, peerRinging);
}

/// Someone calls me. [accepting] = I tapped Accept, waiting for the server.
final class CallIncomingState extends CallViewModelState {
  const CallIncomingState({
    required this.call,
    this.peer = CallPeer.unknown,
    this.accepting = false,
    this.autoAnswer = false,
  });

  final CallModel call;
  final CallPeer peer;
  final bool accepting;

  /// The user already said yes: "Answer" on the Android ring notification
  /// (Step 7.4). The call page runs the Accept path by itself (mic check →
  /// accept) and shows "Connecting…" instead of the Accept button.
  final bool autoAnswer;

  CallIncomingState copyWith({
    CallPeer? peer,
    bool? accepting,
    bool? autoAnswer,
  }) => CallIncomingState(
    call: call,
    peer: peer ?? this.peer,
    accepting: accepting ?? this.accepting,
    autoAnswer: autoAnswer ?? this.autoAnswer,
  );

  @override
  bool operator ==(Object other) =>
      other is CallIncomingState &&
      other.call == call &&
      other.peer == peer &&
      other.accepting == accepting &&
      other.autoAnswer == autoAnswer;

  @override
  int get hashCode => Object.hash(call, peer, accepting, autoAnswer);
}

/// Both sides agreed (Accept). [connectedAt] is null while "Connecting…"
/// (the media call isn't up with the other person yet), then the timer
/// counts from it.
final class CallInCallState extends CallViewModelState {
  const CallInCallState({
    required this.call,
    required this.peer,
    this.connectedAt,
    this.micOn = true,
    this.cameraOn = false,
    this.speakerOn = false,
    this.frontCamera = true,
    this.reconnecting = false,
    this.peerAway = false,
    this.others = const [],
  });

  final CallModel call;
  final CallPeer peer;
  final DateTime? connectedAt;
  final bool micOn;
  final bool cameraOn;
  final bool speakerOn;
  final bool frontCamera;

  /// MY network dropped; Stream is trying again (6.3b).
  final bool reconnecting;

  /// THEY left the media call after it started (their network?) (6.3b).
  final bool peerAway;

  /// Who else is in the media call (user ids) — the group row / grid (6.3c).
  final List<String> others;

  bool get isConnecting => connectedAt == null;

  CallInCallState copyWith({
    DateTime? connectedAt,
    bool? micOn,
    bool? cameraOn,
    bool? speakerOn,
    bool? frontCamera,
    bool? reconnecting,
    bool? peerAway,
    List<String>? others,
  }) => CallInCallState(
    call: call,
    peer: peer,
    connectedAt: connectedAt ?? this.connectedAt,
    micOn: micOn ?? this.micOn,
    cameraOn: cameraOn ?? this.cameraOn,
    speakerOn: speakerOn ?? this.speakerOn,
    frontCamera: frontCamera ?? this.frontCamera,
    reconnecting: reconnecting ?? this.reconnecting,
    peerAway: peerAway ?? this.peerAway,
    others: others ?? this.others,
  );

  static const _ids = ListEquality<String>();

  @override
  bool operator ==(Object other) =>
      other is CallInCallState &&
      other.call == call &&
      other.peer == peer &&
      other.connectedAt == connectedAt &&
      other.micOn == micOn &&
      other.cameraOn == cameraOn &&
      other.speakerOn == speakerOn &&
      other.frontCamera == frontCamera &&
      other.reconnecting == reconnecting &&
      other.peerAway == peerAway &&
      _ids.equals(other.others, others);

  @override
  int get hashCode => Object.hash(
    call,
    peer,
    connectedAt,
    micOn,
    cameraOn,
    speakerOn,
    frontCamera,
    reconnecting,
    peerAway,
    _ids.hash(others),
  );
}

/// Over. Shown for `CallConfig.endedScreen`, then → Idle.
final class CallEndedState extends CallViewModelState {
  const CallEndedState({
    required this.peer,
    required this.type,
    required this.reason,
    this.message,
  });

  final CallPeer peer;
  final CallType type;
  final CallEndReason reason;

  /// The server's own words for [CallEndReason.failed] (e.g. "Call already
  /// ended"), shown instead of the default label.
  final String? message;

  String get text => message ?? reason.label;

  @override
  bool operator ==(Object other) =>
      other is CallEndedState &&
      other.peer == peer &&
      other.type == type &&
      other.reason == reason &&
      other.message == message;

  @override
  int get hashCode => Object.hash(peer, type, reason, message);
}
