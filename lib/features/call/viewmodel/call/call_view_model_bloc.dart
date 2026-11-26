import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/router/auth_session.dart';
import '../../model/call_config.dart';
import '../../model/call_end_reason.dart';
import '../../model/call_kit_action.dart';
import '../../model/call_enums.dart';
import '../../model/call_model.dart';
import '../../model/call_peer.dart';
import '../../model/call_sound.dart';
import '../../model/call_update.dart';
import '../../repository/call_media.dart';
import '../../repository/call_notifications.dart';
import '../../repository/call_repository.dart';
import '../../repository/call_sounds.dart';

part 'call_view_model_event.dart';
part 'call_view_model_state.dart';

/// Turns a call into a name + photo (given by `app/`, which knows chat).
typedef CallPeerLoader = Future<CallPeer?> Function(CallModel call);

/// THE call state machine (Step 6.1). ONE for the whole app: a call lives
/// longer than any page, and an invite can come on any screen.
///
/// ```mermaid
/// Idle ──start──► Outgoing ──call.accept──► InCall ──hang up / call.hangup──► Ended
///   └──call.invite──► Incoming ──Accept (POST accept)──┘
/// Outgoing ─► Ended: declined · busy · no answer · I cancel
/// Incoming ─► Ended: I decline · caller cancels · nobody answered
/// Ended ──1.5 s──► Idle
/// ```
///
/// Rules (CALL_SCENARIOS.md + flutter-chat lessons):
/// - Busy (#11, #18): an invite while [CallViewModelState.isActive] →
///   `reject(reason: busy)`, no screen.
/// - Hang up while "Calling…" (#13): if `POST /calls` hasn't answered yet,
///   the call is ended as soon as its id arrives.
/// - Backstop (#19): the callee's timer only CLOSES the screen; it never
///   sends "reject" (that would save "declined", not "missed").
///
/// Media (Step 6.2): entering InCall joins the Stream call ([CallMedia]).
/// "Connecting…" until the OTHER person is really in the media call, then the
/// timer starts at 00:00 (CALL_SCENARIOS.md #8). Every end path leaves it.
///
/// Sounds (Step 6.3a): every state change → [soundFor] → [CallSounds].
///
/// iOS CallKit (Step 7.3): logged in → [CallMedia.connectForRinging] (the
/// VoIP token reaches Stream). CallKit Accept / Decline / End →
/// [OnCallKitActionEvent] → the SAME paths as our own buttons. Every end
/// closes the CallKit screen too ([CallMedia.endRing]).
class CallViewModelBloc extends Bloc<CallViewModelEvent, CallViewModelState> {
  CallViewModelBloc(
    this._repository, {
    required CallMedia media,
    required CallPeerLoader loadPeer,
    CallSounds? sounds,
    CallNotifications? notifications,
    required AuthSession session,
    this.ringBackstop = CallConfig.ringBackstop,
    this.endedScreen = CallConfig.endedScreen,
    this.reconnectTimeout = CallConfig.reconnectTimeout,
    DateTime Function()? clock,
  }) : _media = media,
       _sounds = sounds,
       _notifications = notifications,
       _loadPeer = loadPeer,
       _session = session,
       _now = clock ?? DateTime.now,
       super(const CallIdleState()) {
    on<OnCallStartEvent>(_onStart);
    on<OnCallAcceptEvent>(_onAccept);
    on<OnCallDeclineEvent>(_onDecline);
    on<OnCallHangUpEvent>(_onHangUp);
    on<OnCallLiveUpdateEvent>(_onLiveUpdate);
    on<OnCallPeerLoadedEvent>(_onPeerLoaded);
    on<OnCallBackstopEvent>(_onBackstop);
    on<OnCallClosedEvent>(_onClosed);
    on<OnCallResyncEvent>(_onResync);
    on<OnCallResetEvent>(_onReset);
    on<OnCallMediaStartEvent>(_onMediaStart);
    on<OnCallPeerMediaEvent>(_onPeerMedia);
    on<OnCallToggleMicEvent>(_onToggleMic);
    on<OnCallToggleCameraEvent>(_onToggleCamera);
    on<OnCallToggleSpeakerEvent>(_onToggleSpeaker);
    on<OnCallFlipCameraEvent>(_onFlipCamera);
    on<OnCallMediaLinkEvent>(_onMediaLink);
    on<OnCallReconnectTimeoutEvent>(_onReconnectTimeout);
    on<OnCallOpenedFromPushEvent>(_onOpenedFromPush);
    on<OnCallAutoAnswerFailedEvent>(_onAutoAnswerFailed);
    on<OnCallKitActionEvent>(_onCallKitAction);

    // Invites can come at any time → listen for the whole session.
    _queue = _repository.callsQueue().listen(_live);
    _reconnected = _repository.reconnected.listen(
      (_) => add(OnCallResyncEvent()),
    );
    _callKit = _media.callKit.listen((action) {
      if (!isClosed) add(OnCallKitActionEvent(action));
    });
    _session.addListener(_onSession);
    _onSession(); // already logged in (auto-login ran first)
  }

  final CallRepository _repository;
  final CallMedia _media;
  final CallSounds? _sounds; // null = silent (tests)
  final CallNotifications? _notifications; // Android ring (7.2), null in tests
  final CallPeerLoader _loadPeer;
  final AuthSession _session;
  final Duration ringBackstop;
  final Duration endedScreen;
  final Duration reconnectTimeout;
  final DateTime Function() _now;

  /// For chat's 📞 buttons (greyed while a call is on) — `app/` passes it.
  final ValueNotifier<bool> inCall = ValueNotifier(false);

  late final StreamSubscription<CallUpdate> _queue;
  late final StreamSubscription<void> _reconnected;
  late final StreamSubscription<CallKitAction> _callKit;
  StreamSubscription<CallUpdate>? _topic; // the current call's conversation
  StreamSubscription<List<String>>? _peerMedia; // who else is in the media?
  StreamSubscription<MediaLink>? _mediaLink; // is MY media link up?
  Timer? _reconnectGiveUp;
  Timer? _backstop;
  Timer? _closing;
  String? _myId;

  /// "Ringing" for a call whose id we don't know yet (it can beat the
  /// `POST /calls` answer on a fast network).
  final Set<String> _earlyRinging = {};

  /// Calls crossed (#18): while I was calling this conversation, ITS other
  /// person called me too (I rejected theirs as busy). If the server then
  /// refuses mine ("already in an active call"), it's that crossing, not a
  /// stuck call → show "Busy in another call", like the other phone.
  String? _crossedConversationId;

  void _live(CallUpdate update) {
    if (!isClosed) add(OnCallLiveUpdateEvent(update));
  }

  bool _ringReady = false; // connectForRinging ran for this login

  void _onSession() {
    if (!_session.isAuthenticated) {
      _ringReady = false;
      add(OnCallResetEvent());
    } else if (!_ringReady) {
      _ringReady = true;
      _media.connectForRinging(); // iOS: VoIP token → Stream (Android: no-op)
    }
  }

  Future<String?> _me() async => _myId ??= await _repository.myUserId();

  @override
  void onChange(Change<CallViewModelState> change) {
    super.onChange(change);
    inCall.value = change.nextState.isActive;
    final sound = soundFor(change.currentState, change.nextState);
    if (sound != null) _sounds?.play(sound);
    // The ring notification follows the screen: answered / ended → it stops.
    final ringing = switch (change.nextState) {
      CallIncomingState(:final call) => call.id,
      _ => null,
    };
    _notifications?.onIncoming(ringing);
  }

  /// Which sound a state change makes (null = leave the player alone).
  ///
  /// | change                                  | sound          |
  /// |-----------------------------------------|----------------|
  /// | → Outgoing "Calling…"                   | — (silent)     |
  /// | Outgoing: their phone rings "Ringing…"  | ringback loop  |
  /// | → Incoming (a new call)                 | ringtone loop  |
  /// | → Incoming from "Answer" (autoAnswer)    | silence (7.4)  |
  /// | Incoming: autoAnswer refused (mic)      | ringtone loop  |
  /// | Incoming: I tap Accept                  | silence        |
  /// | → InCall "Connecting…"                  | silence        |
  /// | InCall: they're in the media (00:00)    | connected beep |
  /// | a live call → Ended (any reason)        | ended beep     |
  static CallSound? soundFor(CallViewModelState prev, CallViewModelState next) {
    switch (next) {
      case CallOutgoingState(:final peerRinging):
        final wasRinging = prev is CallOutgoingState && prev.peerRinging;
        return peerRinging && !wasRinging ? CallSound.ringback : null;
      case CallIncomingState(:final call, :final accepting, :final autoAnswer):
        if (prev is! CallIncomingState || prev.call.id != call.id) {
          // already answered on the notification → don't ring again
          return autoAnswer ? CallSound.silence : CallSound.ringtone;
        }
        if (accepting && !prev.accepting) return CallSound.silence;
        if (autoAnswer && !prev.autoAnswer) return CallSound.silence;
        // mic refused → a normal incoming call again: ring
        if (prev.autoAnswer && !autoAnswer && !accepting) {
          return CallSound.ringtone;
        }
        return null;
      case CallInCallState(:final connectedAt):
        if (prev is! CallInCallState) return CallSound.silence;
        return prev.connectedAt == null && connectedAt != null
            ? CallSound.connected
            : null;
      case CallEndedState():
        return prev.isActive ? CallSound.ended : null;
      case CallIdleState():
        return null;
    }
  }

  @override
  Future<void> close() async {
    _session.removeListener(_onSession);
    _stopTimers();
    await _topic?.cancel();
    await _peerMedia?.cancel();
    await _media.leave();
    await _queue.cancel();
    await _reconnected.cancel();
    await _callKit.cancel();
    inCall.dispose();
    return super.close();
  }

  // ───────────── I call ─────────────

  Future<void> _onStart(
    OnCallStartEvent event,
    Emitter<CallViewModelState> emit,
  ) async {
    if (state.isActive) return; // one call at a time
    _stopTimers();
    _earlyRinging.clear();
    _crossedConversationId = null;
    emit(
      CallOutgoingState(
        conversationId: event.conversationId,
        peer: event.peer,
        type: event.type,
      ),
    );
    // Listen BEFORE asking, so no "ringing" / "accept" can slip past.
    _watchTopic(event.conversationId);
    _media.prepare(); // warm up Stream while it rings → short "Connecting…"

    final result = await _repository.start(event.conversationId, event.type);
    final now = state;
    final stillWaiting =
        now is CallOutgoingState &&
        now.call == null &&
        now.conversationId == event.conversationId;

    result.fold(
      (error) {
        if (!stillWaiting) return;
        // The server's raw "Caller is already in an active call" means ME
        // → our own, clearer words (CallEndReason.stillInCall).
        if (error.description.contains('already in an active call')) {
          // they called me at the same moment → both phones say "Busy"
          _end(
            emit,
            _crossedConversationId == event.conversationId
                ? CallEndReason.busy
                : CallEndReason.stillInCall,
          );
        } else {
          _end(emit, CallEndReason.failed, message: error.description);
        }
      },
      (call) {
        if (!stillWaiting) {
          // I hung up while "Calling…" → end it now, or it rings for nothing.
          _repository.end(call.id);
          return;
        }
        emit(
          now.copyWith(call: call, peerRinging: _earlyRinging.remove(call.id)),
        );
        _startBackstop(call.id);
      },
    );
  }

  // ───────────── they call ─────────────

  Future<void> _onInvite(
    CallModel call,
    Emitter<CallViewModelState> emit, {
    bool autoAnswer = false,
  }) async {
    final me = await _me();
    if (call.callerId == me) return; // my own invite on the topic
    if (call.status.isOver || state.callId == call.id) return;
    if (state.isActive) {
      // Busy: no screen, no ring — the caller sees "Busy".
      _repository.reject(call.id, reason: 'busy');
      final s = state;
      if (s is CallOutgoingState && s.conversationId == call.conversationId) {
        _crossedConversationId = call.conversationId; // we called each other
      }
      return;
    }
    _stopTimers();
    emit(
      CallIncomingState(
        call: call,
        peer: CallPeer.callerOf(call), // name + photo from the invite, at once
        autoAnswer: autoAnswer,
      ),
    );
    _watchTopic(call.conversationId);
    _media.prepare(); // warm up Stream while it rings → short "Connecting…"
    _repository.ringing(call.id); // caller: "Calling…" → "Ringing…"
    _startBackstop(call.id);
    _loadPeer(call).then((peer) {
      if (peer != null && !isClosed) add(OnCallPeerLoadedEvent(call.id, peer));
    }, onError: (_) {});
  }

  void _onPeerLoaded(
    OnCallPeerLoadedEvent event,
    Emitter<CallViewModelState> emit,
  ) {
    // The name can arrive AFTER the call was accepted ("Answer" accepts at
    // once, 7.4) → apply it in InCall too, or the screen keeps "?" / "…".
    switch (state) {
      case final CallIncomingState s when s.call.id == event.callId:
        emit(s.copyWith(peer: event.peer));
      case final CallInCallState s when s.call.id == event.callId:
        emit(s.copyWith(peer: event.peer));
      default:
        break;
    }
  }

  Future<void> _onAccept(
    OnCallAcceptEvent event,
    Emitter<CallViewModelState> emit,
  ) async {
    final s = state;
    if (s is! CallIncomingState || s.accepting) return;
    emit(s.copyWith(accepting: true));

    final result = await _repository.accept(s.call.id);
    final now = state;
    if (now is! CallIncomingState || now.call.id != s.call.id) return;
    result.fold(
      (error) => _end(emit, CallEndReason.failed, message: error.description),
      (call) => _enterCall(emit, call, now.peer),
    );
  }

  void _onDecline(OnCallDeclineEvent event, Emitter<CallViewModelState> emit) {
    final s = state;
    if (s is! CallIncomingState) return;
    _repository.reject(s.call.id); // result ignored: the screen closes anyway
    _end(emit, CallEndReason.declined);
  }

  // ───────────── the red button ─────────────

  void _onHangUp(OnCallHangUpEvent event, Emitter<CallViewModelState> emit) {
    switch (state) {
      case CallOutgoingState(:final call):
        if (call != null) _repository.end(call.id);
        // call == null → _onStart ends it when the id arrives
        _end(emit, CallEndReason.cancelled);
      case CallIncomingState():
        _onDecline(OnCallDeclineEvent(), emit);
      case CallInCallState(:final call):
        _repository.end(call.id);
        _end(emit, CallEndReason.hungUp);
      case CallIdleState() || CallEndedState():
        break;
    }
  }

  // ───────────── the server says ─────────────

  Future<void> _onLiveUpdate(
    OnCallLiveUpdateEvent event,
    Emitter<CallViewModelState> emit,
  ) async {
    final update = event.update;
    if (update is CallInvited) return _onInvite(update.call, emit);

    final s = state;
    if (s is CallOutgoingState && s.call == null && update is CallRinging) {
      _earlyRinging.add(update.callId); // before we know our id
      return;
    }
    if (update.callId != s.callId) return; // not the call on screen
    final me = await _me();
    if (state != s) return; // something changed while we waited

    switch ((s, update)) {
      // ── Outgoing ──
      case (final CallOutgoingState o, CallRinging(:final userId))
          when userId != me:
        emit(o.copyWith(peerRinging: true));
      case (
        CallOutgoingState(:final call?, :final peer),
        CallAccepted(call: final fresh),
      ):
        _enterCall(
          emit,
          fresh ?? call.copyWith(status: CallStatus.answered),
          peer,
        );
      case (CallOutgoingState(), CallRejected(:final reason, :final call))
          when _isOver(call):
        _end(
          emit,
          reason == 'busy' ? CallEndReason.busy : CallEndReason.declined,
        );
      case (CallOutgoingState(), CallHungUp(:final reason)):
        _end(
          emit,
          reason == 'no_answer' ? CallEndReason.noAnswer : CallEndReason.hungUp,
        );

      // ── Incoming ──
      case (
        CallIncomingState(:final accepting),
        CallAccepted(:final accepterId),
      ):
        // Me, but not from this phone → my other device answered.
        // Someone else (a group) → I keep ringing.
        if (accepterId == me && !accepting) {
          _end(emit, CallEndReason.answeredElsewhere);
        }
      case (CallIncomingState(), CallRejected(:final rejecterId, :final call))
          when rejecterId != me && _isOver(call):
        _end(emit, CallEndReason.missed);
      case (CallIncomingState(), CallHungUp(:final call)) when _isOver(call):
        _end(emit, CallEndReason.missed); // caller cancelled / no answer

      // ── In call ──
      case (CallInCallState(), CallHungUp(:final call)) when _isOver(call):
        _end(emit, CallEndReason.hungUp);
      case (CallInCallState(), CallRejected(:final call)) when _isOver(call):
        _end(emit, CallEndReason.hungUp);

      default:
        break; // a group call goes on, or an echo of my own action
    }
  }

  /// No call in the payload → a 1-to-1 call, which this event ends.
  static bool _isOver(CallModel? call) => call?.status.isOver ?? true;

  // ───────────── timers & resync ─────────────

  void _onBackstop(
    OnCallBackstopEvent event,
    Emitter<CallViewModelState> emit,
  ) {
    if (state.callId != event.callId) return;
    switch (state) {
      case CallOutgoingState(:final call?):
        _repository.end(call.id);
        _end(emit, CallEndReason.noAnswer);
      case CallIncomingState():
        // Only close. NO reject: the server marks it MISSED itself (#19).
        _end(emit, CallEndReason.missed);
      default:
        break;
    }
  }

  void _onClosed(OnCallClosedEvent event, Emitter<CallViewModelState> emit) {
    if (state is CallEndedState) emit(const CallIdleState());
  }

  /// Events during a socket drop are lost → ask where the call is now.
  Future<void> _onResync(
    OnCallResyncEvent event,
    Emitter<CallViewModelState> emit,
  ) async {
    final s = state;
    final id = s.callId;
    if (id == null) return;
    final result = await _repository.load(id);
    if (state != s) return;
    result.fold((_) {}, (call) {
      if (call.status.isOver) {
        _end(emit, switch (s) {
          CallIncomingState() => CallEndReason.missed,
          CallOutgoingState() => CallEndReason.noAnswer,
          _ => CallEndReason.hungUp,
        });
      } else if (call.status == CallStatus.answered && s is CallOutgoingState) {
        _enterCall(emit, call, s.peer);
      }
    });
  }

  void _onReset(OnCallResetEvent event, Emitter<CallViewModelState> emit) {
    _stopTimers();
    _topic?.cancel();
    _topic = null;
    _peerMedia?.cancel();
    _peerMedia = null;
    _media.signOut(); // forget the Stream user too
    _myId = null;
    emit(const CallIdleState());
  }

  // ───────────── media (6.2) ─────────────

  /// Both sides agreed → "Connecting…" and join the Stream call.
  void _enterCall(
    Emitter<CallViewModelState> emit,
    CallModel call,
    CallPeer peer,
  ) {
    _cancelBackstop();
    emit(
      CallInCallState(
        call: call,
        peer: peer,
        cameraOn: call.isVideo,
        speakerOn: call.isVideo, // video → loudspeaker, voice → earpiece
      ),
    );
    add(OnCallMediaStartEvent(call.id));
  }

  Future<void> _onMediaStart(
    OnCallMediaStartEvent event,
    Emitter<CallViewModelState> emit,
  ) async {
    final s = state;
    if (s is! CallInCallState || s.call.id != event.callId) return;
    final cid = s.call.streamCallCid ?? '';
    if (cid.isEmpty) {
      _repository.end(s.call.id);
      _end(emit, CallEndReason.failed);
      return;
    }
    // Listen first: the other person may already be in the media call.
    _peerMedia?.cancel();
    _peerMedia = _media.peers.listen((ids) {
      if (!isClosed) add(OnCallPeerMediaEvent(event.callId, ids));
    });
    _mediaLink?.cancel();
    _mediaLink = _media.link.listen((link) {
      if (!isClosed) add(OnCallMediaLinkEvent(event.callId, link));
    });

    final joined = await _media.join(cid: cid, video: s.call.isVideo);
    final now = state;
    if (now is! CallInCallState || now.call.id != event.callId) return;
    if (!joined.ok) {
      // No sound is no call: hang up properly so the other side isn't stuck.
      _repository.end(now.call.id);
      _end(emit, CallEndReason.failed);
      return;
    }
    emit(now.copyWith(micOn: joined.micOn, cameraOn: joined.cameraOn));
  }

  /// Who else is in the media call changed. The FIRST person → the timer
  /// starts. Everybody gone after that → "… is reconnecting" (we wait: the
  /// server hangs up for them if they don't come back).
  void _onPeerMedia(
    OnCallPeerMediaEvent event,
    Emitter<CallViewModelState> emit,
  ) {
    final s = state;
    if (s is! CallInCallState || s.call.id != event.callId) return;
    final ids = event.userIds;
    if (ids.isNotEmpty) {
      emit(
        s.copyWith(
          connectedAt: s.connectedAt ?? _now(),
          peerAway: false,
          others: ids,
        ),
      );
    } else if (s.connectedAt != null) {
      emit(s.copyWith(peerAway: true, others: const []));
    }
  }

  /// MY link: reconnecting → "Reconnecting…" + a give-up timer; connected →
  /// back to normal; lost (Stream gave up) → the call is over.
  void _onMediaLink(
    OnCallMediaLinkEvent event,
    Emitter<CallViewModelState> emit,
  ) {
    final s = state;
    if (s is! CallInCallState || s.call.id != event.callId) return;
    switch (event.link) {
      case MediaLink.reconnecting:
        if (s.reconnecting) return;
        emit(s.copyWith(reconnecting: true));
        _reconnectGiveUp?.cancel();
        _reconnectGiveUp = Timer(reconnectTimeout, () {
          if (!isClosed) add(OnCallReconnectTimeoutEvent(event.callId));
        });
      case MediaLink.connected:
        _reconnectGiveUp?.cancel();
        if (s.reconnecting) emit(s.copyWith(reconnecting: false));
      case MediaLink.lost:
        _giveUp(emit, s);
    }
  }

  void _onReconnectTimeout(
    OnCallReconnectTimeoutEvent event,
    Emitter<CallViewModelState> emit,
  ) {
    final s = state;
    if (s is CallInCallState && s.call.id == event.callId && s.reconnecting) {
      _giveUp(emit, s);
    }
  }

  /// No network for too long: tell the server (best effort — it also hangs
  /// up for us after its own 30 s) and close.
  void _giveUp(Emitter<CallViewModelState> emit, CallInCallState s) {
    _repository.end(s.call.id);
    _end(emit, CallEndReason.connectionLost);
  }

  /// Flip at once (the button reacts), then ask the SDK; it said no
  /// (e.g. permission denied) → flip back.
  Future<void> _toggle(
    Emitter<CallViewModelState> emit,
    CallInCallState Function(CallInCallState s) flipped,
    Future<bool> Function(CallInCallState next) apply,
  ) async {
    final s = state;
    if (s is! CallInCallState) return;
    final next = flipped(s);
    emit(next);
    final ok = await apply(next);
    final now = state;
    if (!ok && now is CallInCallState && now.call.id == s.call.id) {
      emit(flipped(now)); // back
    }
  }

  Future<void> _onToggleMic(
    OnCallToggleMicEvent event,
    Emitter<CallViewModelState> emit,
  ) => _toggle(
    emit,
    (s) => s.copyWith(micOn: !s.micOn),
    (next) => _media.setMicrophone(next.micOn),
  );

  Future<void> _onToggleCamera(
    OnCallToggleCameraEvent event,
    Emitter<CallViewModelState> emit,
  ) => _toggle(
    emit,
    (s) => s.copyWith(cameraOn: !s.cameraOn),
    (next) => _media.setCamera(next.cameraOn),
  );

  Future<void> _onToggleSpeaker(
    OnCallToggleSpeakerEvent event,
    Emitter<CallViewModelState> emit,
  ) => _toggle(
    emit,
    (s) => s.copyWith(speakerOn: !s.speakerOn),
    (next) => _media.setSpeaker(next.speakerOn),
  );

  Future<void> _onFlipCamera(
    OnCallFlipCameraEvent event,
    Emitter<CallViewModelState> emit,
  ) => _toggle(
    emit,
    (s) => s.copyWith(frontCamera: !s.frontCamera),
    (_) => _media.flipCamera(),
  );

  // ───────────── opened from a push (7.2) ─────────────

  /// The app was opened from the ring notification (tap / Answer), or opened
  /// while it rang. The invite over STOMP was missed (the app wasn't
  /// running), so ask the server and show the incoming screen like a live
  /// invite. Already over → nothing ("Missed call" is in the chat).
  ///
  /// "Answer" (Step 7.4) → the incoming state carries `autoAnswer: true`:
  /// the call page runs the Accept path itself (mic check → accept), so the
  /// user taps ONCE. The bloc never asks for permissions (no context here).
  Future<void> _onOpenedFromPush(
    OnCallOpenedFromPushEvent event,
    Emitter<CallViewModelState> emit,
  ) async {
    // Already ringing on screen (STOMP was first) + "Answer" → answer it.
    final s = state;
    if (s is CallIncomingState && s.call.id == event.callId) {
      if (event.answer && !s.accepting) emit(s.copyWith(autoAnswer: true));
      return;
    }
    if (state.callId == event.callId || state.isActive) return;
    final call = await _ringingForMe(event.callId);
    if (state.callId == event.callId || state.isActive) return; // raced
    if (call == null) {
      _notifications?.cancel(event.callId); // stale: stop ringing
      return;
    }
    await _onInvite(call, emit, autoAnswer: event.answer);
  }

  /// The mic was refused after "Answer" → the normal incoming screen.
  void _onAutoAnswerFailed(
    OnCallAutoAnswerFailedEvent event,
    Emitter<CallViewModelState> emit,
  ) {
    final s = state;
    if (s is CallIncomingState && s.call.id == event.callId && s.autoAnswer) {
      emit(s.copyWith(autoAnswer: false));
    }
  }

  // ───────────── iOS CallKit (7.3) ─────────────

  /// A CallKit button. The app may have been KILLED a second ago (iOS
  /// starts it in the background for the VoIP push), so the STOMP invite
  /// was never seen: Accept on an unknown call loads it first.
  ///
  /// | button  | the call on screen          | unknown call                |
  /// |---------|-----------------------------|-----------------------------|
  /// | Accept  | accept (no 2nd tap)         | load → still ringing → accept |
  /// | Decline | decline                     | `POST /reject`              |
  /// | End     | hang up (= our red button)  | ignored (already over)      |
  Future<void> _onCallKitAction(
    OnCallKitActionEvent event,
    Emitter<CallViewModelState> emit,
  ) async {
    final CallKitAction(:button, :callId) = event.action;
    final onScreen = state.callId == callId;
    switch (button) {
      case CallKitButton.accept:
        if (!onScreen) {
          if (state.isActive) return; // busy: CallKit's own "end & accept"
          final call = await _ringingForMe(callId);
          if (call == null) {
            _media.endRing(callId); // too late: the call is over
            return;
          }
          if (state.isActive) return; // raced
          await _onInvite(call, emit);
        }
        if (state case CallIncomingState(:final call) when call.id == callId) {
          await _onAccept(OnCallAcceptEvent(), emit);
        }
      case CallKitButton.decline:
        if (onScreen) {
          _onDecline(OnCallDeclineEvent(), emit);
        } else {
          _repository.reject(callId); // result ignored: CallKit closed
        }
      case CallKitButton.end:
        if (onScreen) _onHangUp(OnCallHangUpEvent(), emit);
    }
  }

  /// The call [callId] if it still rings for ME (asked to the server).
  Future<CallModel?> _ringingForMe(String callId) async {
    final result = await _repository.load(callId);
    final me = await _me();
    final call = result.fold((_) => null, (c) => c);
    final ringing =
        call != null &&
        call.status == CallStatus.ringing &&
        call.participants.any(
          (p) => p.userId == me && p.status == ParticipantStatus.ringing,
        );
    return ringing ? call : null;
  }

  // ───────────── helpers ─────────────

  /// → Ended (the screen shows why), then Idle after [endedScreen].
  void _end(
    Emitter<CallViewModelState> emit,
    CallEndReason reason, {
    String? message,
  }) {
    final callId = state.callId;
    if (callId != null) _media.endRing(callId); // CallKit screen goes too
    final (peer, type) = switch (state) {
      CallOutgoingState(:final peer, :final type) => (peer, type),
      CallIncomingState(:final peer, :final call) ||
      CallInCallState(:final peer, :final call) => (peer, call.type),
      CallEndedState(:final peer, :final type) => (peer, type),
      CallIdleState() => (CallPeer.unknown, CallType.voice),
    };
    _stopTimers();
    _topic?.cancel();
    _topic = null;
    _peerMedia?.cancel();
    _peerMedia = null;
    _mediaLink?.cancel();
    _mediaLink = null;
    _media.leave(); // every end path leaves the sound / picture
    emit(
      CallEndedState(peer: peer, type: type, reason: reason, message: message),
    );
    _closing = Timer(endedScreen, () {
      if (!isClosed) add(OnCallClosedEvent());
    });
  }

  void _watchTopic(String conversationId) {
    _topic?.cancel();
    _topic = _repository.callTopic(conversationId).listen(_live);
  }

  void _startBackstop(String callId) {
    _backstop?.cancel();
    _backstop = Timer(ringBackstop, () {
      if (!isClosed) add(OnCallBackstopEvent(callId));
    });
  }

  void _cancelBackstop() {
    _backstop?.cancel();
    _backstop = null;
  }

  void _stopTimers() {
    _cancelBackstop();
    _reconnectGiveUp?.cancel();
    _reconnectGiveUp = null;
    _closing?.cancel();
    _closing = null;
  }
}
