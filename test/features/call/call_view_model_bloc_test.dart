import 'dart:async';

import 'package:dartz/dartz.dart' show Either, Left, Right;
import 'package:erp_mobile/core/network/network_error_model.dart';
import 'package:erp_mobile/core/router/auth_session.dart';
import 'package:erp_mobile/features/call/model/call_end_reason.dart';
import 'package:erp_mobile/features/call/model/call_enums.dart';
import 'package:erp_mobile/features/call/model/call_model.dart';
import 'package:erp_mobile/features/call/model/call_peer.dart';
import 'package:erp_mobile/features/call/model/call_update.dart';
import 'package:erp_mobile/features/call/repository/call_repository.dart';
import 'package:erp_mobile/features/call/viewmodel/call/call_view_model_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCallRepository extends Mock implements CallRepository {}

const _me = '1';
const _jane = '2';
const _jane$ = CallPeer(name: 'Jane Doe');

CallModel _call({
  String id = '7',
  String callerId = _me,
  CallStatus status = CallStatus.ringing,
  CallType type = CallType.voice,
}) => CallModel(
  id: id,
  conversationId: '42',
  callerId: callerId,
  type: type,
  status: status,
);

void main() {
  late _MockCallRepository repo;
  late StreamController<CallUpdate> queue;
  late StreamController<CallUpdate> topic;
  late StreamController<void> reconnected;
  late AuthSession session;
  late List<String> sent; // what the phone told the server

  setUpAll(() => registerFallbackValue(CallType.voice));

  setUp(() {
    repo = _MockCallRepository();
    queue = StreamController<CallUpdate>.broadcast();
    topic = StreamController<CallUpdate>.broadcast();
    reconnected = StreamController<void>.broadcast();
    session = AuthSession()..markAuthenticated();
    sent = [];

    when(() => repo.myUserId()).thenAnswer((_) async => _me);
    when(() => repo.callsQueue()).thenAnswer((_) => queue.stream);
    when(() => repo.callTopic(any())).thenAnswer((_) => topic.stream);
    when(() => repo.reconnected).thenAnswer((_) => reconnected.stream);
    when(() => repo.start(any(), any())).thenAnswer((_) async {
      sent.add('start');
      return Right(_call());
    });
    when(() => repo.ringing(any())).thenAnswer((i) async {
      sent.add('ringing ${i.positionalArguments.first}');
    });
    when(() => repo.accept(any())).thenAnswer((i) async {
      sent.add('accept ${i.positionalArguments.first}');
      return Right(_call(callerId: _jane, status: CallStatus.answered));
    });
    when(() => repo.reject(any(), reason: any(named: 'reason'))).thenAnswer((
      i,
    ) async {
      final reason = i.namedArguments[#reason] as String?;
      sent.add('reject ${i.positionalArguments.first} ${reason ?? '-'}');
      return Right(_call(status: CallStatus.rejected));
    });
    when(() => repo.end(any())).thenAnswer((i) async {
      sent.add('end ${i.positionalArguments.first}');
      return Right(_call(status: CallStatus.ended));
    });
  });

  tearDown(() async {
    await queue.close();
    await topic.close();
    await reconnected.close();
  });

  CallViewModelBloc build({Duration backstop = const Duration(seconds: 70)}) =>
      CallViewModelBloc(
        repo,
        loadPeer: (_) async => _jane$,
        session: session,
        ringBackstop: backstop,
        endedScreen: const Duration(milliseconds: 30),
      );

  Future<void> tick([int ms = 0]) =>
      Future<void>.delayed(Duration(milliseconds: ms));

  void startCall(CallViewModelBloc bloc) => bloc.add(
    OnCallStartEvent(conversationId: '42', peer: _jane$, type: CallType.voice),
  );

  CallEndReason? endedWith(CallViewModelBloc bloc) => switch (bloc.state) {
    CallEndedState(:final reason) => reason,
    _ => null,
  };

  group('I call', () {
    test('Calling… → Ringing… → InCall when they accept', () async {
      final bloc = build();
      startCall(bloc);
      await tick();
      expect(bloc.state, isA<CallOutgoingState>());
      expect((bloc.state as CallOutgoingState).call?.id, '7');
      expect((bloc.state as CallOutgoingState).peerRinging, isFalse);
      expect(bloc.inCall.value, isTrue); // chat's 📞 greyed

      topic.add(const CallRinging('7', userId: _jane));
      await tick();
      expect((bloc.state as CallOutgoingState).peerRinging, isTrue);

      topic.add(const CallAccepted('7', accepterId: _jane));
      await tick();
      expect(bloc.state, isA<CallInCallState>());
      await bloc.close();
    });

    test('my own invite echoed on the topic is ignored', () async {
      final bloc = build();
      startCall(bloc);
      await tick();
      topic.add(CallInvited(_call()));
      await tick();
      expect(bloc.state, isA<CallOutgoingState>());
      expect(sent, ['start']); // no busy-reject of my own call
      await bloc.close();
    });

    test('"ringing" that beats the POST answer is not lost', () async {
      final answer = Completer<Either<NetworkErrorModel, CallModel>>();
      when(() => repo.start(any(), any())).thenAnswer((_) => answer.future);
      final bloc = build();
      startCall(bloc);
      await tick();
      topic.add(const CallRinging('7', userId: _jane)); // id not known yet
      await tick();
      answer.complete(Right(_call()));
      await tick();
      expect((bloc.state as CallOutgoingState).peerRinging, isTrue);
      await bloc.close();
    });

    test('they decline → "Call declined" → Idle', () async {
      final bloc = build();
      startCall(bloc);
      await tick();
      topic.add(
        CallRejected(
          '7',
          rejecterId: _jane,
          call: _call(status: CallStatus.rejected),
        ),
      );
      await tick();
      expect(endedWith(bloc), CallEndReason.declined);
      expect(bloc.inCall.value, isFalse);
      await tick(50);
      expect(bloc.state, const CallIdleState());
      await bloc.close();
    });

    test('they are busy → "Busy in another call" (#11)', () async {
      final bloc = build();
      startCall(bloc);
      await tick();
      topic.add(
        CallRejected(
          '7',
          rejecterId: _jane,
          reason: 'busy',
          call: _call(status: CallStatus.rejected),
        ),
      );
      await tick();
      expect(endedWith(bloc), CallEndReason.busy);
      await bloc.close();
    });

    test('server gives up (no_answer) → "No answer" (#10, #19)', () async {
      final bloc = build();
      startCall(bloc);
      await tick();
      topic.add(
        CallHungUp(
          '7',
          hangerUpperId: _me,
          reason: 'no_answer',
          call: _call(status: CallStatus.missed),
        ),
      );
      await tick();
      expect(endedWith(bloc), CallEndReason.noAnswer);
      await bloc.close();
    });

    test('I hang up while it rings → end + "Call cancelled" (#13)', () async {
      final bloc = build();
      startCall(bloc);
      await tick();
      bloc.add(OnCallHangUpEvent());
      await tick();
      expect(sent, ['start', 'end 7']);
      expect(endedWith(bloc), CallEndReason.cancelled);
      await bloc.close();
    });

    test('I hang up BEFORE the POST answers → ended when the id arrives '
        '(#13)', () async {
      final answer = Completer<Either<NetworkErrorModel, CallModel>>();
      when(() => repo.start(any(), any())).thenAnswer((_) => answer.future);
      final bloc = build();
      startCall(bloc);
      await tick();
      bloc.add(OnCallHangUpEvent());
      await tick();
      expect(endedWith(bloc), CallEndReason.cancelled);

      answer.complete(Right(_call()));
      await tick();
      verify(() => repo.end('7')).called(1); // else it rings for nothing
      expect(endedWith(bloc), CallEndReason.cancelled);
      await bloc.close();
    });

    test('start fails → "failed" with the server message', () async {
      when(() => repo.start(any(), any())).thenAnswer(
        (_) async => const Left(
          ServerError(
            statusCode: 403,
            description: 'You are not a member of this conversation',
          ),
        ),
      );
      final bloc = build();
      startCall(bloc);
      await tick();
      expect(endedWith(bloc), CallEndReason.failed);
      expect(
        (bloc.state as CallEndedState).text,
        'You are not a member of this conversation',
      );
      await bloc.close();
    });

    test('"Caller is already in an active call" → our clearer words', () async {
      when(() => repo.start(any(), any())).thenAnswer(
        (_) async => const Left(
          ServerError(
            statusCode: 400,
            description: 'Caller is already in an active call',
          ),
        ),
      );
      final bloc = build();
      startCall(bloc);
      await tick();
      expect(endedWith(bloc), CallEndReason.stillInCall);
      expect(
        (bloc.state as CallEndedState).text,
        "You're still in another call. Try again in a moment.",
      );
      await bloc.close();
    });

    test('backstop: nothing from the server → end + "No answer"', () async {
      final bloc = build(backstop: const Duration(milliseconds: 30));
      startCall(bloc);
      await tick(60);
      expect(sent, ['start', 'end 7']);
      expect(endedWith(bloc), CallEndReason.noAnswer);
      await bloc.close();
    });

    test('a second start while in a call is ignored', () async {
      final bloc = build();
      startCall(bloc);
      await tick();
      startCall(bloc);
      await tick();
      expect(sent, ['start']);
      await bloc.close();
    });
  });

  group('they call', () {
    test('invite → Incoming + "ringing" sent + name loaded', () async {
      final bloc = build();
      queue.add(CallInvited(_call(callerId: _jane)));
      await tick();
      final s = bloc.state as CallIncomingState;
      expect(s.call.id, '7');
      expect(s.peer, _jane$);
      expect(sent, ['ringing 7']); // caller: "Calling…" → "Ringing…"
      await bloc.close();
    });

    test('Accept → accept sent → InCall', () async {
      final bloc = build();
      queue.add(CallInvited(_call(callerId: _jane)));
      await tick();
      bloc.add(OnCallAcceptEvent());
      await tick();
      expect(sent, ['ringing 7', 'accept 7']);
      expect(bloc.state, isA<CallInCallState>());
      await bloc.close();
    });

    test('Accept fails ("Call already ended") → failed', () async {
      when(() => repo.accept(any())).thenAnswer(
        (_) async => const Left(
          ServerError(statusCode: 400, description: 'Call already ended'),
        ),
      );
      final bloc = build();
      queue.add(CallInvited(_call(callerId: _jane)));
      await tick();
      bloc.add(OnCallAcceptEvent());
      await tick();
      expect((bloc.state as CallEndedState).text, 'Call already ended');
      await bloc.close();
    });

    test('Decline → reject (no reason) + "Call declined"', () async {
      final bloc = build();
      queue.add(CallInvited(_call(callerId: _jane)));
      await tick();
      bloc.add(OnCallDeclineEvent());
      await tick();
      expect(sent, ['ringing 7', 'reject 7 -']);
      expect(endedWith(bloc), CallEndReason.declined);
      await bloc.close();
    });

    test('caller cancels → "Missed call" at once (#13)', () async {
      final bloc = build();
      queue.add(CallInvited(_call(callerId: _jane)));
      await tick();
      topic.add(
        CallHungUp(
          '7',
          hangerUpperId: _jane,
          call: _call(callerId: _jane, status: CallStatus.ended),
        ),
      );
      await tick();
      expect(endedWith(bloc), CallEndReason.missed);
      await bloc.close();
    });

    test('backstop only CLOSES — it never sends reject (#19)', () async {
      final bloc = build(backstop: const Duration(milliseconds: 30));
      queue.add(CallInvited(_call(callerId: _jane)));
      await tick(60);
      expect(endedWith(bloc), CallEndReason.missed);
      expect(sent, ['ringing 7']); // no "reject" → the server saves MISSED
      await bloc.close();
    });

    test('my other device answered → "Answered on another device"', () async {
      final bloc = build();
      queue.add(CallInvited(_call(callerId: _jane)));
      await tick();
      topic.add(const CallAccepted('7', accepterId: _me));
      await tick();
      expect(endedWith(bloc), CallEndReason.answeredElsewhere);
      await bloc.close();
    });

    test('group: someone ELSE accepts → I keep ringing', () async {
      final bloc = build();
      queue.add(CallInvited(_call(callerId: _jane)));
      await tick();
      topic.add(const CallAccepted('7', accepterId: '3'));
      await tick();
      expect(bloc.state, isA<CallIncomingState>());
      await bloc.close();
    });
  });

  group('busy (#11, #18)', () {
    test('an invite while I call someone → reject busy, no screen', () async {
      final bloc = build();
      startCall(bloc);
      await tick();
      queue.add(CallInvited(_call(id: '8', callerId: '3')));
      await tick();
      expect(sent, ['start', 'reject 8 busy']);
      expect((bloc.state as CallOutgoingState).call?.id, '7');
      await bloc.close();
    });

    test('both call each other at once → both see "Busy" (#18)', () async {
      final bloc = build();
      startCall(bloc); // me → Jane (call 7)
      await tick();
      queue.add(CallInvited(_call(id: '8', callerId: _jane))); // Jane → me
      await tick();
      expect(sent.last, 'reject 8 busy'); // my phone tells Jane "busy"
      topic.add(
        CallRejected(
          '7',
          rejecterId: _jane,
          reason: 'busy',
          call: _call(status: CallStatus.rejected),
        ),
      ); // Jane's phone did the same to me
      await tick();
      expect(endedWith(bloc), CallEndReason.busy);
      await tick(50);
      startCall(bloc); // and the next call works
      await tick();
      expect(bloc.state, isA<CallOutgoingState>());
      await bloc.close();
    });
  });

  group('in call', () {
    Future<CallViewModelBloc> connected() async {
      final bloc = build();
      startCall(bloc);
      await tick();
      topic.add(const CallAccepted('7', accepterId: _jane));
      await tick();
      return bloc;
    }

    test('they hang up → "Call ended"', () async {
      final bloc = await connected();
      topic.add(
        CallHungUp(
          '7',
          hangerUpperId: _jane,
          call: _call(status: CallStatus.ended),
        ),
      );
      await tick();
      expect(endedWith(bloc), CallEndReason.hungUp);
      await bloc.close();
    });

    test('I hang up → end sent → "Call ended"', () async {
      final bloc = await connected();
      bloc.add(OnCallHangUpEvent());
      await tick();
      expect(sent.last, 'end 7');
      expect(endedWith(bloc), CallEndReason.hungUp);
      await bloc.close();
    });

    test('group: one person leaves, the call goes on', () async {
      final bloc = await connected();
      topic.add(
        CallHungUp(
          '7',
          hangerUpperId: '3',
          call: _call(status: CallStatus.answered),
        ),
      );
      await tick();
      expect(bloc.state, isA<CallInCallState>());
      await bloc.close();
    });

    test('reconnected → GET the call → it ended meanwhile → close', () async {
      when(
        () => repo.load('7'),
      ).thenAnswer((_) async => Right(_call(status: CallStatus.ended)));
      final bloc = await connected();
      reconnected.add(null);
      await tick();
      expect(endedWith(bloc), CallEndReason.hungUp);
      await bloc.close();
    });
  });

  test('events for another call are ignored', () async {
    final bloc = build();
    startCall(bloc);
    await tick();
    topic.add(const CallAccepted('99', accepterId: _jane));
    await tick();
    expect(bloc.state, isA<CallOutgoingState>());
    await bloc.close();
  });

  test('logout → Idle at once', () async {
    final bloc = build();
    startCall(bloc);
    await tick();
    session.markLoggedOut();
    await tick();
    expect(bloc.state, const CallIdleState());
    await bloc.close();
  });
}
