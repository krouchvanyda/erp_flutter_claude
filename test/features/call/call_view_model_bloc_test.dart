import 'dart:async';

import 'package:dartz/dartz.dart' show Either, Left, Right;
import 'package:erp_mobile/core/network/network_error_model.dart';
import 'package:erp_mobile/core/router/auth_session.dart';
import 'package:erp_mobile/features/call/model/call_end_reason.dart';
import 'package:erp_mobile/features/call/model/call_enums.dart';
import 'package:erp_mobile/features/call/model/call_model.dart';
import 'package:erp_mobile/features/call/model/call_peer.dart';
import 'package:erp_mobile/features/call/model/call_update.dart';
import 'package:erp_mobile/features/call/model/call_kit_action.dart';
import 'package:erp_mobile/features/call/repository/call_media.dart';
import 'package:erp_mobile/features/call/repository/call_notifications.dart';
import 'package:erp_mobile/features/call/repository/call_repository.dart';
import 'package:erp_mobile/features/call/viewmodel/call/call_view_model_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCallRepository extends Mock implements CallRepository {}

class _MockCallMedia extends Mock implements CallMedia {}

class _MockNotifications extends Mock implements CallNotifications {}

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
  streamCallCid: 'default:call-$id',
);

void main() {
  late _MockCallRepository repo;
  late StreamController<CallUpdate> queue;
  late StreamController<CallUpdate> topic;
  late StreamController<void> reconnected;
  late AuthSession session;
  late List<String> sent; // what the phone told the server
  late _MockCallMedia media;
  late StreamController<List<String>> peer; // the others in the media call
  late StreamController<MediaLink> link; // MY link to the media call
  late StreamController<CallKitAction> callKit; // iOS CallKit buttons

  setUpAll(() => registerFallbackValue(CallType.voice));

  setUp(() {
    repo = _MockCallRepository();
    queue = StreamController<CallUpdate>.broadcast();
    topic = StreamController<CallUpdate>.broadcast();
    reconnected = StreamController<void>.broadcast();
    session = AuthSession()..markAuthenticated();
    sent = [];
    media = _MockCallMedia();
    peer = StreamController<List<String>>.broadcast();
    when(() => media.peers).thenAnswer((_) => peer.stream);
    link = StreamController<MediaLink>.broadcast();
    when(() => media.link).thenAnswer((_) => link.stream);
    when(
      () => media.join(
        cid: any(named: 'cid'),
        video: any(named: 'video'),
      ),
    ).thenAnswer((_) async => (ok: true, micOn: true, cameraOn: false));
    when(() => media.leave()).thenAnswer((_) async {});
    when(() => media.signOut()).thenAnswer((_) async {});
    callKit = StreamController<CallKitAction>.broadcast();
    when(() => media.callKit).thenAnswer((_) => callKit.stream);
    when(() => media.connectForRinging()).thenAnswer((_) async {});
    when(() => media.endRing(any())).thenAnswer((_) async {});

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
    await peer.close();
    await link.close();
    await callKit.close();
  });

  CallViewModelBloc build({
    Duration backstop = const Duration(seconds: 70),
    Duration reconnectTimeout = const Duration(seconds: 30),
  }) => CallViewModelBloc(
    repo,
    media: media,
    loadPeer: (_) async => _jane$,
    session: session,
    ringBackstop: backstop,
    endedScreen: const Duration(milliseconds: 30),
    reconnectTimeout: reconnectTimeout,
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

  group('calls cross (#18, phone test Min ⇄ Rin)', () {
    test(
      'their invite arrives while MY start is pending, then the server '
      'refuses mine → "Busy in another call" (not "still in a call")',
      () async {
        final answer = Completer<Either<NetworkErrorModel, CallModel>>();
        when(() => repo.start(any(), any())).thenAnswer((_) => answer.future);
        final bloc = build();
        startCall(bloc); // me → Jane, conversation 42
        await tick();
        queue.add(
          CallInvited(_call(id: '8', callerId: _jane)),
        ); // Jane → me, 42
        await tick();
        expect(sent.last, 'reject 8 busy'); // Jane's phone: "Busy"
        answer.complete(
          const Left(
            ServerError(
              statusCode: 400,
              description: 'Caller is already in an active call',
            ),
          ),
        );
        await tick();
        expect(endedWith(bloc), CallEndReason.busy); // mine: "Busy" too
        await bloc.close();
      },
    );

    test('an invite from ANOTHER chat does not count as crossing', () async {
      final answer = Completer<Either<NetworkErrorModel, CallModel>>();
      when(() => repo.start(any(), any())).thenAnswer((_) => answer.future);
      final bloc = build();
      startCall(bloc); // conversation 42
      await tick();
      queue.add(
        CallInvited(
          const CallModel(
            id: '9',
            conversationId: '77',
            callerId: '3',
            type: CallType.voice,
            status: CallStatus.ringing,
          ),
        ),
      );
      await tick();
      answer.complete(
        const Left(
          ServerError(
            statusCode: 400,
            description: 'Caller is already in an active call',
          ),
        ),
      );
      await tick();
      expect(endedWith(bloc), CallEndReason.stillInCall);
      await bloc.close();
    });
  });

  group('opened from the ring notification (7.2)', () {
    CallModel ringingForMe() => CallModel(
      id: '7',
      conversationId: '42',
      callerId: _jane,
      type: CallType.voice,
      status: CallStatus.ringing,
      participants: const [
        CallParticipantModel(userId: _jane, status: ParticipantStatus.answered),
        CallParticipantModel(userId: _me, status: ParticipantStatus.ringing),
      ],
    );

    test(
      'still ringing for me → the incoming screen (+ "ringing" sent)',
      () async {
        when(
          () => repo.load('7'),
        ).thenAnswer((_) async => Right(ringingForMe()));
        final bloc = build();
        bloc.add(OnCallOpenedFromPushEvent('7'));
        await tick();
        expect((bloc.state as CallIncomingState).call.id, '7');
        expect(sent, ['ringing 7']);
        await bloc.close();
      },
    );

    test('the ring notification follows the screen: ringing → its id; '
        'declined → null (it stops)', () async {
      final notifications = _MockNotifications();
      final seen = <String?>[];
      when(() => notifications.onIncoming(any())).thenAnswer((i) {
        seen.add(i.positionalArguments.first as String?);
      });
      final bloc = CallViewModelBloc(
        repo,
        media: media,
        loadPeer: (_) async => _jane$,
        session: session,
        notifications: notifications,
        endedScreen: const Duration(milliseconds: 30),
      );
      queue.add(CallInvited(_call(callerId: _jane)));
      await tick();
      bloc.add(OnCallDeclineEvent());
      await tick();
      expect(seen.first, '7');
      expect(seen.last, isNull);
      await bloc.close();
    });

    test('already over (caller gave up) → stays idle', () async {
      when(
        () => repo.load('7'),
      ).thenAnswer((_) async => Right(_call(status: CallStatus.missed)));
      final bloc = build();
      bloc.add(OnCallOpenedFromPushEvent('7'));
      await tick();
      expect(bloc.state, const CallIdleState());
      await bloc.close();
    });

    test('the same call is already on screen → nothing new', () async {
      final bloc = build();
      queue.add(CallInvited(_call(callerId: _jane))); // STOMP got it first
      await tick();
      bloc.add(OnCallOpenedFromPushEvent('7'));
      await tick();
      verifyNever(() => repo.load(any()));
      expect(sent, ['ringing 7']); // only once
      await bloc.close();
    });
  });

  group('iOS CallKit (7.3)', () {
    CallModel ringingForMe() => CallModel(
      id: '7',
      conversationId: '42',
      callerId: _jane,
      type: CallType.voice,
      status: CallStatus.ringing,
      streamCallCid: 'default:erp-call-7',
      participants: const [
        CallParticipantModel(userId: _jane, status: ParticipantStatus.answered),
        CallParticipantModel(userId: _me, status: ParticipantStatus.ringing),
      ],
    );

    test('logged in → connect for ringing (VoIP token → Stream)', () async {
      final bloc = build();
      await tick();
      verify(() => media.connectForRinging()).called(1);
      await bloc.close();
    });

    test('Accept on CallKit, app was killed (no invite seen) → load → '
        'accept → in the call, ONE tap', () async {
      when(() => repo.load('7')).thenAnswer((_) async => Right(ringingForMe()));
      final bloc = build();
      callKit.add(const CallKitAction(CallKitButton.accept, '7'));
      await tick(20);
      expect(sent, ['ringing 7', 'accept 7']);
      expect(bloc.state, isA<CallInCallState>());
      verify(
        () => media.join(cid: 'default:call-7', video: false),
      ).called(1);
      await bloc.close();
    });

    test('Accept on CallKit for the call already on screen → accept, '
        'no extra load', () async {
      final bloc = build();
      queue.add(CallInvited(_call(callerId: _jane)));
      await tick();
      callKit.add(const CallKitAction(CallKitButton.accept, '7'));
      await tick(20);
      verifyNever(() => repo.load(any()));
      expect(sent, ['ringing 7', 'accept 7']);
      expect(bloc.state, isA<CallInCallState>());
      await bloc.close();
    });

    test('Accept twice (live event + the start-up check) → accepted once',
        () async {
      when(() => repo.load('7')).thenAnswer((_) async => Right(ringingForMe()));
      final bloc = build();
      callKit
        ..add(const CallKitAction(CallKitButton.accept, '7'))
        ..add(const CallKitAction(CallKitButton.accept, '7'));
      await tick(20);
      expect(sent.where((e) => e == 'accept 7'), hasLength(1));
      await bloc.close();
    });

    test('Accept too late (the call is over) → CallKit closed, no screen',
        () async {
      when(
        () => repo.load('7'),
      ).thenAnswer((_) async => Right(_call(status: CallStatus.missed)));
      final bloc = build();
      callKit.add(const CallKitAction(CallKitButton.accept, '7'));
      await tick(20);
      expect(bloc.state, const CallIdleState());
      verify(() => media.endRing('7')).called(1);
      expect(sent, isEmpty);
      await bloc.close();
    });

    test('Decline on CallKit for an unknown call → POST reject', () async {
      final bloc = build();
      callKit.add(const CallKitAction(CallKitButton.decline, '7'));
      await tick();
      expect(sent, ['reject 7 -']);
      expect(bloc.state, const CallIdleState());
      await bloc.close();
    });

    test('End on CallKit during the call → hang up (POST end)', () async {
      final bloc = build();
      queue.add(CallInvited(_call(callerId: _jane)));
      await tick();
      bloc.add(OnCallAcceptEvent());
      await tick(20);
      callKit.add(const CallKitAction(CallKitButton.end, '7'));
      await tick();
      expect(sent.last, 'end 7');
      expect(bloc.state, isA<CallEndedState>());
      await bloc.close();
    });

    test('End for a call that is not on screen → ignored', () async {
      final bloc = build();
      callKit.add(const CallKitAction(CallKitButton.end, '7'));
      await tick();
      expect(sent, isEmpty);
      await bloc.close();
    });

    test('every end closes the CallKit screen too', () async {
      final bloc = build();
      queue.add(CallInvited(_call(callerId: _jane)));
      await tick();
      bloc.add(OnCallDeclineEvent());
      await tick();
      verify(() => media.endRing('7')).called(1);
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

  group('media (6.2)', () {
    Future<CallViewModelBloc> accepted() async {
      final bloc = build();
      queue.add(CallInvited(_call(callerId: _jane)));
      await tick();
      bloc.add(OnCallAcceptEvent());
      await tick();
      return bloc;
    }

    test('InCall → "Connecting…" → join the Stream call by its cid', () async {
      final bloc = await accepted();
      final s = bloc.state as CallInCallState;
      expect(s.isConnecting, isTrue); // no timer yet
      verify(() => media.join(cid: 'default:call-7', video: false)).called(1);
      await bloc.close();
    });

    test('the other person is in the media → the timer starts (#8)', () async {
      final bloc = await accepted();
      peer.add([_jane]);
      await tick();
      expect((bloc.state as CallInCallState).connectedAt, isNotNull);
      await bloc.close();
    });

    test('join fails → end the call properly + "failed"', () async {
      when(
        () => media.join(
          cid: any(named: 'cid'),
          video: any(named: 'video'),
        ),
      ).thenAnswer((_) async => (ok: false, micOn: false, cameraOn: false));
      final bloc = await accepted();
      expect(sent.last, 'end 7'); // the other side isn't left waiting
      expect(endedWith(bloc), CallEndReason.failed);
      await bloc.close();
    });

    test('mic permission denied → InCall shows the mic off', () async {
      when(
        () => media.join(
          cid: any(named: 'cid'),
          video: any(named: 'video'),
        ),
      ).thenAnswer((_) async => (ok: true, micOn: false, cameraOn: false));
      final bloc = await accepted();
      expect((bloc.state as CallInCallState).micOn, isFalse);
      await bloc.close();
    });

    test('every end leaves the media (hang up)', () async {
      final bloc = await accepted();
      bloc.add(OnCallHangUpEvent());
      await tick();
      verify(() => media.leave()).called(greaterThanOrEqualTo(1));
      await bloc.close();
    });

    test('mute: flips at once; the SDK says no → flips back', () async {
      final answer = Completer<bool>();
      when(() => media.setMicrophone(any())).thenAnswer((_) => answer.future);
      final bloc = await accepted();
      bloc.add(OnCallToggleMicEvent());
      await tick();
      expect((bloc.state as CallInCallState).micOn, isFalse); // instant
      verify(() => media.setMicrophone(false)).called(1);
      answer.complete(false);
      await tick();
      expect((bloc.state as CallInCallState).micOn, isTrue); // put back
      await bloc.close();
    });

    test('video call: camera + loudspeaker start on', () async {
      when(() => repo.accept(any())).thenAnswer(
        (_) async => Right(
          _call(
            callerId: _jane,
            type: CallType.video,
            status: CallStatus.answered,
          ),
        ),
      );
      when(
        () => media.join(
          cid: any(named: 'cid'),
          video: any(named: 'video'),
        ),
      ).thenAnswer((_) async => (ok: true, micOn: true, cameraOn: true));
      final bloc = build();
      queue.add(CallInvited(_call(callerId: _jane, type: CallType.video)));
      await tick();
      bloc.add(OnCallAcceptEvent());
      await tick();
      final s = bloc.state as CallInCallState;
      expect(s.cameraOn, isTrue);
      expect(s.speakerOn, isTrue);
      verify(() => media.join(cid: 'default:call-7', video: true)).called(1);
      await bloc.close();
    });
  });

  group('reconnecting (6.3b)', () {
    Future<CallViewModelBloc> talking({
      Duration reconnectTimeout = const Duration(seconds: 30),
    }) async {
      final bloc = build(reconnectTimeout: reconnectTimeout);
      queue.add(CallInvited(_call(callerId: _jane)));
      await tick();
      bloc.add(OnCallAcceptEvent());
      await tick();
      peer.add([_jane]); // 00:00
      await tick();
      return bloc;
    }

    CallInCallState inCall(CallViewModelBloc bloc) =>
        bloc.state as CallInCallState;

    test('my network drops → "Reconnecting…" → back → normal', () async {
      final bloc = await talking();
      link.add(MediaLink.reconnecting);
      await tick();
      expect(inCall(bloc).reconnecting, isTrue);
      link.add(MediaLink.connected);
      await tick();
      expect(inCall(bloc).reconnecting, isFalse);
      await bloc.close();
    });

    test('no network for too long → end + "Connection lost"', () async {
      final bloc = await talking(
        reconnectTimeout: const Duration(milliseconds: 30),
      );
      link.add(MediaLink.reconnecting);
      await tick(60);
      expect(sent.last, 'end 7');
      expect(endedWith(bloc), CallEndReason.connectionLost);
      await bloc.close();
    });

    test('back in time → the give-up timer is cancelled', () async {
      final bloc = await talking(
        reconnectTimeout: const Duration(milliseconds: 40),
      );
      link.add(MediaLink.reconnecting);
      await tick(10);
      link.add(MediaLink.connected);
      await tick(60);
      expect(bloc.state, isA<CallInCallState>()); // still talking
      await bloc.close();
    });

    test('Stream gives up (lost) → "Connection lost" at once', () async {
      final bloc = await talking();
      link.add(MediaLink.lost);
      await tick();
      expect(endedWith(bloc), CallEndReason.connectionLost);
      await bloc.close();
    });

    test('THEY drop out of the media → peerAway; back → normal', () async {
      final bloc = await talking();
      final startedAt = inCall(bloc).connectedAt;
      peer.add([]);
      await tick();
      expect(inCall(bloc).peerAway, isTrue);
      peer.add([_jane]);
      await tick();
      expect(inCall(bloc).peerAway, isFalse);
      expect(inCall(bloc).connectedAt, startedAt); // the timer goes on
      await bloc.close();
    });
  });

  group('group calls (6.3c)', () {
    test('people join the media one by one → others grows, timer from the '
        'FIRST', () async {
      final bloc = build();
      queue.add(CallInvited(_call(callerId: _jane)));
      await tick();
      bloc.add(OnCallAcceptEvent());
      await tick();
      peer.add([_jane]);
      await tick();
      final first = (bloc.state as CallInCallState).connectedAt;
      peer.add([_jane, '3']);
      await tick();
      final s = bloc.state as CallInCallState;
      expect(s.others, [_jane, '3']);
      expect(s.connectedAt, first); // a 2nd person doesn't restart the timer
      await bloc.close();
    });

    test('one leaves the media, others stay → not "away"', () async {
      final bloc = build();
      queue.add(CallInvited(_call(callerId: _jane)));
      await tick();
      bloc.add(OnCallAcceptEvent());
      await tick();
      peer.add([_jane, '3']);
      await tick();
      peer.add(['3']);
      await tick();
      final s = bloc.state as CallInCallState;
      expect(s.peerAway, isFalse);
      expect(s.others, ['3']);
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
    verify(() => media.signOut()).called(1); // forget the Stream user
    await bloc.close();
  });
}
