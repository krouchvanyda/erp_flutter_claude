import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/router/auth_session.dart';
import '../../model/call_config.dart';
import '../../model/call_end_reason.dart';
import '../../model/call_enums.dart';
import '../../model/call_model.dart';
import '../../model/call_peer.dart';
import '../../model/call_update.dart';
import '../../repository/call_repository.dart';

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
class CallViewModelBloc extends Bloc<CallViewModelEvent, CallViewModelState> {
  CallViewModelBloc(
    this._repository, {
    required CallPeerLoader loadPeer,
    required AuthSession session,
    this.ringBackstop = CallConfig.ringBackstop,
    this.endedScreen = CallConfig.endedScreen,
    DateTime Function()? clock,
  }) : _loadPeer = loadPeer,
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

    // Invites can come at any time → listen for the whole session.
    _queue = _repository.callsQueue().listen(_live);
    _reconnected = _repository.reconnected.listen(
      (_) => add(OnCallResyncEvent()),
    );
    _session.addListener(_onSession);
  }

  final CallRepository _repository;
  final CallPeerLoader _loadPeer;
  final AuthSession _session;
  final Duration ringBackstop;
  final Duration endedScreen;
  final DateTime Function() _now;

  /// For chat's 📞 buttons (greyed while a call is on) — `app/` passes it.
  final ValueNotifier<bool> inCall = ValueNotifier(false);

  late final StreamSubscription<CallUpdate> _queue;
  late final StreamSubscription<void> _reconnected;
  StreamSubscription<CallUpdate>? _topic; // the current call's conversation
  Timer? _backstop;
  Timer? _closing;
  String? _myId;

  /// "Ringing" for a call whose id we don't know yet (it can beat the
  /// `POST /calls` answer on a fast network).
  final Set<String> _earlyRinging = {};

  void _live(CallUpdate update) {
    if (!isClosed) add(OnCallLiveUpdateEvent(update));
  }

  void _onSession() {
    if (!_session.isAuthenticated) add(OnCallResetEvent());
  }

  Future<String?> _me() async => _myId ??= await _repository.myUserId();

  @override
  void onChange(Change<CallViewModelState> change) {
    super.onChange(change);
    inCall.value = change.nextState.isActive;
  }

  @override
  Future<void> close() async {
    _session.removeListener(_onSession);
    _stopTimers();
    await _topic?.cancel();
    await _queue.cancel();
    await _reconnected.cancel();
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
    emit(
      CallOutgoingState(
        conversationId: event.conversationId,
        peer: event.peer,
        type: event.type,
      ),
    );
    // Listen BEFORE asking, so no "ringing" / "accept" can slip past.
    _watchTopic(event.conversationId);

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
          _end(emit, CallEndReason.stillInCall);
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
    Emitter<CallViewModelState> emit,
  ) async {
    final me = await _me();
    if (call.callerId == me) return; // my own invite on the topic
    if (call.status.isOver || state.callId == call.id) return;
    if (state.isActive) {
      // Busy: no screen, no ring — the caller sees "Busy".
      _repository.reject(call.id, reason: 'busy');
      return;
    }
    _stopTimers();
    emit(CallIncomingState(call: call));
    _watchTopic(call.conversationId);
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
    final s = state;
    if (s is CallIncomingState && s.call.id == event.callId) {
      emit(s.copyWith(peer: event.peer));
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
      (call) {
        _cancelBackstop();
        emit(CallInCallState(call: call, peer: now.peer, connectedAt: _now()));
      },
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
        _cancelBackstop();
        emit(
          CallInCallState(
            call: fresh ?? call.copyWith(status: CallStatus.answered),
            peer: peer,
            connectedAt: _now(),
          ),
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
        _cancelBackstop();
        emit(CallInCallState(call: call, peer: s.peer, connectedAt: _now()));
      }
    });
  }

  void _onReset(OnCallResetEvent event, Emitter<CallViewModelState> emit) {
    _stopTimers();
    _topic?.cancel();
    _topic = null;
    _myId = null;
    emit(const CallIdleState());
  }

  // ───────────── helpers ─────────────

  /// → Ended (the screen shows why), then Idle after [endedScreen].
  void _end(
    Emitter<CallViewModelState> emit,
    CallEndReason reason, {
    String? message,
  }) {
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
    _closing?.cancel();
    _closing = null;
  }
}
