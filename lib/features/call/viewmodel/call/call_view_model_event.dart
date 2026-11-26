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

/// Who else is in the media call changed (internal).
final class OnCallPeerMediaEvent extends CallViewModelEvent {
  OnCallPeerMediaEvent(this.callId, this.userIds);

  final String callId;

  /// The others in the media call now (empty = nobody).
  final List<String> userIds;
}

/// Who else has a camera on changed (internal, 7.5).
final class OnCallPeerVideoEvent extends CallViewModelEvent {
  OnCallPeerVideoEvent(this.callId, this.userIds);

  final String callId;

  /// The others with a camera on now (empty = nobody).
  final List<String> userIds;
}

/// 🎙 mute / unmute.
final class OnCallToggleMicEvent extends CallViewModelEvent {}

/// 🎥 camera on / off.
final class OnCallToggleCameraEvent extends CallViewModelEvent {}

/// 🔊 loudspeaker / earpiece.
final class OnCallToggleSpeakerEvent extends CallViewModelEvent {}

/// 🔄 front / back camera.
final class OnCallFlipCameraEvent extends CallViewModelEvent {}

// ── reconnecting (Step 6.3b) ──

/// My link to the media call changed (internal).
final class OnCallMediaLinkEvent extends CallViewModelEvent {
  OnCallMediaLinkEvent(this.callId, this.link);

  final String callId;
  final MediaLink link;
}

/// "Reconnecting…" lasted too long (internal).
final class OnCallReconnectTimeoutEvent extends CallViewModelEvent {
  OnCallReconnectTimeoutEvent(this.callId);

  final String callId;
}

// ── push (Step 7.2) ──

/// The app was opened from the ring notification (or while it rang).
final class OnCallOpenedFromPushEvent extends CallViewModelEvent {
  OnCallOpenedFromPushEvent(this.callId, {this.answer = false});

  final String callId;

  /// The user tapped "Answer" (not just the notification) → the incoming
  /// screen accepts by itself (`autoAnswer`, Step 7.4).
  final bool answer;
}

/// "Answer" was tapped, but the microphone was refused on the call page →
/// back to the normal incoming screen (⛔ 📞) (Step 7.4).
final class OnCallAutoAnswerFailedEvent extends CallViewModelEvent {
  OnCallAutoAnswerFailedEvent(this.callId);

  final String callId;
}

// ── iOS CallKit (Step 7.3) ──

/// A button on the iOS CallKit screen (from `CallMedia.callKit`, internal).
final class OnCallKitActionEvent extends CallViewModelEvent {
  OnCallKitActionEvent(this.action);

  final CallKitAction action;
}
