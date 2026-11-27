import 'package:erp_mobile/features/chat/model/chat_enums.dart';
import 'package:erp_mobile/features/chat/model/conversation_model.dart';
import 'package:erp_mobile/features/chat/widgets/inbox_open_requests.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const _chat14 = ConversationModel(id: '14', type: ConversationType.direct);

/// Step 5.7: the inbox takes an "open this chat" request ONCE.
void main() {
  late ValueNotifier<ConversationModel?> requests;
  late List<String> opened;

  setUp(() {
    requests = ValueNotifier(null);
    opened = [];
  });

  Widget inbox() => InboxOpenRequests(
    requests: requests,
    onOpen: (c) => opened.add(c.id),
    child: const SizedBox(),
  );

  testWidgets('a request while the inbox is on screen → opens it once', (
    tester,
  ) async {
    await tester.pumpWidget(inbox());
    requests.value = _chat14;
    await tester.pump();

    expect(opened, ['14']);
    expect(requests.value, isNull); // taken
  });

  testWidgets(
    'a request made BEFORE the inbox was built (cold start) → opens',
    (tester) async {
      requests.value = _chat14;
      await tester.pumpWidget(inbox());
      await tester.pump(); // the first frame

      expect(opened, ['14']);
      expect(requests.value, isNull);
    },
  );

  testWidgets('after the inbox is gone → nothing happens', (tester) async {
    await tester.pumpWidget(inbox());
    await tester.pumpWidget(const SizedBox()); // logged out
    requests.value = _chat14;
    await tester.pump();

    expect(opened, isEmpty);
    expect(requests.value, _chat14); // kept for the next inbox
  });
}
