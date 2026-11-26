import 'package:erp_mobile/features/call/model/call_end_reason.dart';
import 'package:erp_mobile/features/call/model/call_enums.dart';
import 'package:erp_mobile/features/call/model/call_model.dart';
import 'package:erp_mobile/features/call/model/call_peer.dart';
import 'package:erp_mobile/features/call/model/call_sound.dart';
import 'package:erp_mobile/features/call/viewmodel/call/call_view_model_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

const _peer = CallPeer(name: 'Jane Doe');
const _call = CallModel(
  id: '7',
  conversationId: '42',
  callerId: '2',
  type: CallType.voice,
  status: CallStatus.ringing,
);
const _idle = CallIdleState();
const _calling = CallOutgoingState(
  conversationId: '42',
  peer: _peer,
  type: CallType.voice,
  call: _call,
);
final _ringing = _calling.copyWith(peerRinging: true);
const _incoming = CallIncomingState(call: _call);
const _connecting = CallInCallState(call: _call, peer: _peer);
final _talking = _connecting.copyWith(connectedAt: DateTime(2026));
const _ended = CallEndedState(
  peer: _peer,
  type: CallType.voice,
  reason: CallEndReason.hungUp,
);

CallSound? _sound(CallViewModelState a, CallViewModelState b) =>
    CallViewModelBloc.soundFor(a, b);

void main() {
  test('"Calling…" is SILENT; "Ringing…" starts the ringback once', () {
    expect(_sound(_idle, _calling), isNull);
    expect(_sound(_calling, _ringing), CallSound.ringback);
    expect(_sound(_ringing, _ringing), isNull); // no restart
  });

  test('incoming → ringtone; tap Accept → silence at once', () {
    expect(_sound(_idle, _incoming), CallSound.ringtone);
    expect(
      _sound(_incoming, _incoming.copyWith(peer: _peer)), // name loaded
      isNull,
    );
    expect(
      _sound(_incoming, _incoming.copyWith(accepting: true)),
      CallSound.silence,
    );
  });

  test('"Answer" on the notification (7.4): no ring; mic refused → ring', () {
    final answered = _incoming.copyWith(autoAnswer: true);
    expect(_sound(_idle, answered), CallSound.silence); // opened by Answer
    expect(_sound(_incoming, answered), CallSound.silence); // already ringing
    expect(
      _sound(answered, answered.copyWith(autoAnswer: false)), // mic refused
      CallSound.ringtone,
    );
    expect(
      _sound(answered, answered.copyWith(accepting: true)),
      CallSound.silence,
    );
  });

  test('InCall: "Connecting…" is silent, the beep when they are really in', () {
    expect(_sound(_ringing, _connecting), CallSound.silence); // ring stops
    expect(_sound(_connecting, _talking), CallSound.connected);
    expect(_sound(_talking, _talking.copyWith(micOn: false)), isNull); // mute
  });

  test('ended beep after ANY live phase — even while "Calling…"', () {
    expect(_sound(_calling, _ended), CallSound.ended);
    expect(_sound(_incoming, _ended), CallSound.ended);
    expect(_sound(_talking, _ended), CallSound.ended);
    expect(_sound(_ended, _idle), isNull); // closing the screen: no 2nd beep
  });
}
