import 'package:erp_mobile/features/chat/repositories/call_signaling_service.dart';
import 'package:erp_mobile/features/chat/repositories/call_sound_player.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

CallSound? _sound(CallSignalState? prev, CallSignalState? next,
        {bool sameCall = true, bool appOpen = true}) =>
    CallSoundPlayer.soundFor(
        prev: prev, next: next, sameCall: sameCall, appOpen: appOpen);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every sound file is bundled', () async {
    for (final s in CallSound.values) {
      final data = await rootBundle.load(s.asset);
      expect(data.lengthInBytes, greaterThan(1000), reason: s.asset);
    }
  });

  const out = CallSignalState.outgoingRinging;
  const inc = CallSignalState.incomingRinging;
  const con = CallSignalState.connected;
  const end = CallSignalState.ended;

  test('outgoing call: silent while Calling…, ringback once Ringing…', () {
    expect(_sound(null, out, sameCall: false), isNull);
    expect(
        CallSoundPlayer.soundFor(
            prev: out,
            next: out,
            sameCall: true,
            appOpen: true,
            prevPeerRinging: false,
            nextPeerRinging: true),
        CallSound.ringback);
    // Already ringing, nothing new → no restart.
    expect(
        CallSoundPlayer.soundFor(
            prev: out,
            next: out,
            sameCall: true,
            appOpen: true,
            prevPeerRinging: true,
            nextPeerRinging: true),
        isNull);
  });

  test('cancelled while still Calling… → ended beep', () {
    expect(_sound(out, end), CallSound.ended);
  });

  test('incoming call rings only when the app is open', () {
    expect(_sound(null, inc, sameCall: false), CallSound.ringtone);
    expect(_sound(null, inc, sameCall: false, appOpen: false), isNull);
  });

  test('ringing → connected → beep', () {
    expect(_sound(out, con), CallSound.connected);
    expect(_sound(inc, con), CallSound.connected);
  });

  test('ended after ringing or connected → ended beep', () {
    expect(_sound(con, end), CallSound.ended);
    expect(_sound(out, end), CallSound.ended); // rejected / no answer
    expect(_sound(con, null, sameCall: false), CallSound.ended); // torn down
  });

  test('no double ended beep, no sound when nothing changed', () {
    expect(_sound(end, null, sameCall: false), isNull);
    expect(_sound(con, con), isNull);
    expect(_sound(null, null), isNull);
  });

  test('every sound file is registered', () {
    for (final s in CallSound.values) {
      expect(s.asset, startsWith('assets/sounds/'));
    }
    expect(CallSound.ringback.loop, isTrue);
    expect(CallSound.connected.loop, isFalse);
  });
}
