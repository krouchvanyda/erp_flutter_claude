import 'package:erp_mobile/features/call/model/call_push.dart';
import 'package:erp_mobile/features/call/repository/call_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CallPush.fromData (the backend FCM data)', () {
    test('call.invite → CallPushInvite', () {
      final p = CallPush.fromData({
        'type': 'call.invite',
        'callId': '46',
        'conversationId': '3',
        'callerId': '4',
        'callerName': ' Mr Min ',
        'callType': 'video',
      });
      expect(p, isA<CallPushInvite>());
      final i = p! as CallPushInvite;
      expect(i.callId, '46');
      expect(i.conversationId, '3');
      expect(i.callerName, 'Mr Min');
      expect(i.video, isTrue);
    });

    test('call.cancel → CallPushCancel with the reason', () {
      final p = CallPush.fromData({
        'type': 'call.cancel',
        'callId': '46',
        'reason': 'accepted_elsewhere',
      });
      expect(
        p,
        isA<CallPushCancel>().having(
          (c) => c.reason,
          'reason',
          'accepted_elsewhere',
        ),
      );
    });

    test('a chat push / no callId → null (ignored)', () {
      expect(
        CallPush.fromData({'type': 'chat.message', 'callId': '1'}),
        isNull,
      );
      expect(CallPush.fromData({'type': 'call.invite'}), isNull);
    });
  });

  group('CallNotifications helpers', () {
    test('one int id per call, the same every time (cancel finds it)', () {
      expect(CallNotifications.notificationId('46'), 46);
      expect(
        CallNotifications.notificationId('abc'),
        CallNotifications.notificationId('abc'),
      );
      expect(CallNotifications.notificationId('abc'), greaterThanOrEqualTo(0));
    });

    test('payload → callId; junk → null', () {
      expect(CallNotifications.callIdOf('{"callId":"46"}'), '46');
      expect(CallNotifications.callIdOf('{"callId":46}'), '46');
      expect(CallNotifications.callIdOf('not json'), isNull);
      expect(CallNotifications.callIdOf(null), isNull);
    });
  });
}
