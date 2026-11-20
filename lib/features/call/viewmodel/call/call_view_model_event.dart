part of 'call_view_model_bloc.dart';

@immutable
sealed class CallViewModelEvent {}

/// I tap 📞 / 🎥 in a chat.
final class OnCallStartEvent extends CallViewModelEvent {
  OnCallStartEvent({
    required this.conversationId,
    required this.peer,
    required this.type,
  });

  final String conversationId;
  final CallPeer peer;
  final CallType type;
}

/// Incoming call → Accept.
final class OnCallAcceptEvent extends CallViewModelEvent {}

/// Incoming call → Decline.
final class OnCallDeclineEvent extends CallViewModelEvent {}

/// The red button: cancel (still ringing) or hang up (connected).
final class OnCallHangUpEvent extends CallViewModelEvent {}

/// A live event from the server (internal).
final class OnCallLiveUpdateEvent extends CallViewModelEvent {
  OnCallLiveUpdateEvent(this.update);

  final CallUpdate update;
}

/// The caller's name / photo arrived for an incoming call (internal).
final class OnCallPeerLoadedEvent extends CallViewModelEvent {
  OnCallPeerLoadedEvent(this.callId, this.peer);

  final String callId;
  final CallPeer peer;
}

/// Our ring backstop ran out for [callId] (internal).
final class OnCallBackstopEvent extends CallViewModelEvent {
  OnCallBackstopEvent(this.callId);

  final String callId;
}

/// The "ended" screen time is over → Idle (internal).
final class OnCallClosedEvent extends CallViewModelEvent {}

/// The socket came back → ask the server where the call is (internal).
final class OnCallResyncEvent extends CallViewModelEvent {}

/// Logged out → forget everything (internal).
final class OnCallResetEvent extends CallViewModelEvent {}

// ── media (Step 6.2) ──

/// We're in the call → join the Stream call (internal).
final class OnCallMediaStartEvent extends CallViewModelEvent {
  OnCallMediaStartEvent(this.callId);

  final String callId;
}

/// The other person entered / left the media call (internal).
final class OnCallPeerMediaEvent extends CallViewModelEvent {
  OnCallPeerMediaEvent(this.callId, this.present);

  final String callId;
  final bool present;
}

/// 🎙 mute / unmute.
final class OnCallToggleMicEvent extends CallViewModelEvent {}

/// 🎥 camera on / off.
final class OnCallToggleCameraEvent extends CallViewModelEvent {}

/// 🔊 loudspeaker / earpiece.
final class OnCallToggleSpeakerEvent extends CallViewModelEvent {}

/// 🔄 front / back camera.
final class OnCallFlipCameraEvent extends CallViewModelEvent {}
