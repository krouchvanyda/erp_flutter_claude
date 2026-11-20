import 'package:erp_mobile/core/theme/app_theme.dart';
import 'package:erp_mobile/features/call/model/call_end_reason.dart';
import 'package:erp_mobile/features/call/model/call_enums.dart';
import 'package:erp_mobile/features/call/model/call_model.dart';
import 'package:erp_mobile/features/call/model/call_peer.dart';
import 'package:erp_mobile/features/call/viewmodel/call/call_view_model_bloc.dart';
import 'package:erp_mobile/features/call/widgets/call_controls.dart';
import 'package:erp_mobile/features/call/widgets/call_status_text.dart';
import 'package:erp_mobile/features/call/widgets/call_timer_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _peer = CallPeer(name: 'Jane Doe');
const _call = CallModel(
  id: '7',
  conversationId: '42',
  callerId: '2',
  type: CallType.voice,
  status: CallStatus.ringing,
);

void main() {
  test('CallTimerText.format', () {
    expect(CallTimerText.format(Duration.zero), '00:00');
    expect(CallTimerText.format(const Duration(seconds: 75)), '01:15');
    expect(CallTimerText.format(const Duration(seconds: 3725)), '1:02:05');
    expect(CallTimerText.format(const Duration(seconds: -3)), '00:00');
  });

  test('CallStatusText.textFor: Calling… → Ringing… → ended reason', () {
    const out = CallOutgoingState(
      conversationId: '42',
      peer: _peer,
      type: CallType.voice,
    );
    expect(CallStatusText.textFor(out), 'Calling…');
    expect(CallStatusText.textFor(out.copyWith(peerRinging: true)), 'Ringing…');
    expect(
      CallStatusText.textFor(const CallIncomingState(call: _call)),
      'Incoming call',
    );
    expect(
      CallStatusText.textFor(
        const CallIncomingState(call: _call, accepting: true),
      ),
      'Connecting…',
    );
    expect(
      CallStatusText.textFor(
        const CallEndedState(
          peer: _peer,
          type: CallType.voice,
          reason: CallEndReason.busy,
        ),
      ),
      'Busy in another call',
    );
  });

  Widget host(CallViewModelState state, List<String> taps) => MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: CallControls(
        state: state,
        onAccept: () => taps.add('accept'),
        onDecline: () => taps.add('decline'),
        onHangUp: () => taps.add('hangUp'),
        onToggleMic: () => taps.add('mic'),
        onToggleSpeaker: () => taps.add('speaker'),
        onToggleCamera: () => taps.add('camera'),
        onFlipCamera: () => taps.add('flip'),
      ),
    ),
  );

  testWidgets('incoming: Decline + Accept; Accept greyed while accepting', (
    tester,
  ) async {
    final taps = <String>[];
    await tester.pumpWidget(host(const CallIncomingState(call: _call), taps));
    await tester.tap(find.byIcon(Icons.call_rounded));
    await tester.tap(find.byIcon(Icons.call_end_rounded));
    expect(taps, ['accept', 'decline']);

    taps.clear();
    await tester.pumpWidget(
      host(const CallIncomingState(call: _call, accepting: true), taps),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.call_rounded));
    expect(taps, isEmpty); // no double accept
  });

  testWidgets('in a voice call: Mute + Speaker + End (no camera)', (
    tester,
  ) async {
    final taps = <String>[];
    await tester.pumpWidget(
      host(const CallInCallState(call: _call, peer: _peer), taps),
    );
    expect(find.text('Camera'), findsNothing);
    await tester.tap(find.byIcon(Icons.mic_rounded));
    await tester.tap(find.byIcon(Icons.volume_down_rounded));
    await tester.tap(find.byIcon(Icons.call_end_rounded));
    expect(taps, ['mic', 'speaker', 'hangUp']);
  });

  test('InCall before the other person joins the media → "Connecting…"', () {
    expect(
      CallStatusText.textFor(const CallInCallState(call: _call, peer: _peer)),
      'Connecting…',
    );
  });

  testWidgets('outgoing: only End → hang up', (tester) async {
    final taps = <String>[];
    await tester.pumpWidget(
      host(
        const CallOutgoingState(
          conversationId: '42',
          peer: _peer,
          type: CallType.voice,
        ),
        taps,
      ),
    );
    expect(find.text('Accept'), findsNothing);
    await tester.tap(find.byIcon(Icons.call_end_rounded));
    expect(taps, ['hangUp']);
  });
}
