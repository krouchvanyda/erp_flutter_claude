import 'package:erp_mobile/features/call/model/call_enums.dart';
import 'package:erp_mobile/features/call/model/call_model.dart';
import 'package:erp_mobile/features/call/viewmodel/call/call_view_model_bloc.dart';
import 'package:erp_mobile/features/call/widgets/call_auto_answer.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

CallModel _call(String id) => CallModel(
  id: id,
  conversationId: '42',
  callerId: '2',
  type: CallType.voice,
  status: CallStatus.ringing,
);

void main() {
  late int answers;
  Widget host(CallViewModelState state) =>
      CallAutoAnswer(state: state, onAnswer: () => answers++);

  setUp(() => answers = 0);

  testWidgets('built ALREADY with autoAnswer → answers once (after the '
      'frame); rebuilds don\'t answer again', (tester) async {
    final s = CallIncomingState(call: _call('7'), autoAnswer: true);
    await tester.pumpWidget(host(s));
    await tester.pump();
    expect(answers, 1);

    await tester.pumpWidget(host(s.copyWith(accepting: true)));
    await tester.pumpWidget(host(s)); // e.g. a name loaded
    await tester.pump();
    expect(answers, 1);
  });

  testWidgets('a normal incoming call → nothing (the user taps Accept)', (
    tester,
  ) async {
    await tester.pumpWidget(host(CallIncomingState(call: _call('7'))));
    await tester.pump();
    expect(answers, 0);
  });

  testWidgets('autoAnswer arrives LATER (already on screen) → answers', (
    tester,
  ) async {
    final s = CallIncomingState(call: _call('7'));
    await tester.pumpWidget(host(s));
    await tester.pumpWidget(host(s.copyWith(autoAnswer: true)));
    await tester.pump();
    expect(answers, 1);
  });

  testWidgets('a NEW call with autoAnswer → answers that one too', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(CallIncomingState(call: _call('7'), autoAnswer: true)),
    );
    await tester.pump();
    await tester.pumpWidget(
      host(CallIncomingState(call: _call('8'), autoAnswer: true)),
    );
    await tester.pump();
    expect(answers, 2);
  });
}
