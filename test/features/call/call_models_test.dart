import 'package:erp_mobile/core/realtime/realtime_event.dart';
import 'package:erp_mobile/features/call/model/call_enums.dart';
import 'package:erp_mobile/features/call/model/call_model.dart';
import 'package:erp_mobile/features/call/model/call_peer.dart';
import 'package:erp_mobile/features/call/model/call_update.dart';
import 'package:erp_mobile/features/call/repository/call_media.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart'
    show
        CallStatusConnected,
        CallStatusReconnecting,
        CallStatusReconnectionFailed,
        CallStatusIdle;
import 'package:flutter_test/flutter_test.dart';

const _dto = {
  'id': 7,
  'conversationId': 42,
  'callerId': 1,
  'type': 'VIDEO',
  'status': 'RINGING',
  'startedAt': '2026-11-20T03:00:00Z',
  'streamCallCid': 'default:call-7',
  'participants': [
    {'userId': 1, 'status': 'ANSWERED'},
    {'userId': 2, 'status': 'RINGING'},
  ],
};

CallUpdate? _parse(String event, Object? payload) =>
    CallUpdate.fromRealtime(RealtimeEvent(event: event, payload: payload));

void main() {
  test('CallModel.fromJson: ids → String, enums, participants', () {
    final c = CallModel.fromJson(_dto);
    expect(c.id, '7');
    expect(c.conversationId, '42');
    expect(c.callerId, '1');
    expect(c.isVideo, isTrue);
    expect(c.status, CallStatus.ringing);
    expect(c.streamCallCid, 'default:call-7');
    expect(c.participants.map((p) => p.userId), ['1', '2']);
    expect(c, CallModel.fromJson(_dto)); // hand-written ==
  });

  test('enums: unknown values fall back safely', () {
    expect(CallType.fromJson('HOLOGRAM'), CallType.voice);
    expect(CallStatus.fromJson('???'), CallStatus.ended); // never stuck
    expect(CallStatus.ringing.isOver, isFalse);
    expect(CallStatus.answered.isOver, isFalse);
    expect(CallStatus.missed.isOver, isTrue);
    expect(CallType.video.toJson(), 'VIDEO');
  });

  group('CallUpdate.fromRealtime', () {
    test('call.invite → CallInvited(ChatCallDto)', () {
      final u = _parse('call.invite', _dto) as CallInvited;
      expect(u.callId, '7');
      expect(u.call.isVideo, isTrue);
    });

    test('call.ringing → CallRinging(userId)', () {
      final u = _parse('call.ringing', {
        'callId': 7,
        'userId': 2,
        'conversationId': 42,
      });
      expect(u, isA<CallRinging>().having((r) => r.userId, 'userId', '2'));
    });

    test('call.accept / reject / hangup carry the call', () {
      final accept =
          _parse('call.accept', {'callId': 7, 'accepterId': 2, 'call': _dto})
              as CallAccepted;
      expect(accept.accepterId, '2');
      expect(accept.call?.id, '7');

      final reject =
          _parse('call.reject', {
                'callId': 7,
                'rejecterId': 2,
                'reason': 'busy',
                'call': {..._dto, 'status': 'REJECTED'},
              })
              as CallRejected;
      expect(reject.reason, 'busy');
      expect(reject.call?.status.isOver, isTrue);

      final hangup =
          _parse('call.hangup', {
                'callId': 7,
                'hangerUpperId': 1,
                'reason': 'no_answer',
              })
              as CallHungUp;
      expect(hangup.reason, 'no_answer');
      expect(hangup.call, isNull);
    });

    test('unknown event / bad payload → null (never a crash)', () {
      expect(_parse('message.send', {'id': 1}), isNull);
      expect(_parse('call.invite', 'oops'), isNull);
      expect(
        _parse('call.accept', {'callId': 7, 'call': 'not a map'}),
        isA<CallAccepted>(),
      );
    });
  });

  test('CallMedia.linkOf: Stream status → connected / reconnecting / lost', () {
    expect(CallMedia.linkOf(CallStatusConnected()), MediaLink.connected);
    expect(
      CallMedia.linkOf(const CallStatusReconnecting(attempt: 1)),
      MediaLink.reconnecting,
    );
    expect(CallMedia.linkOf(CallStatusReconnectionFailed()), MediaLink.lost);
    expect(CallMedia.linkOf(CallStatusIdle()), isNull);
  });

  test('CallPeer: members are part of ==; unknown id → empty member', () {
    const a = CallPeer(
      name: 'Team',
      isGroup: true,
      members: {'2': CallMember(name: 'Dara Sok')},
    );
    const b = CallPeer(
      name: 'Team',
      isGroup: true,
      members: {'2': CallMember(name: 'Dara Sok')},
    );
    expect(a, b);
    expect(a.member('2').firstName, 'Dara');
    expect(a.member('99').name, '');
  });

  test('WHO is calling comes with the call: callerName + callerAvatarUrl '
      '→ CallPeer.callerOf (photo → full URL)', () {
    final call = CallModel.fromJson({
      'id': 7,
      'conversationId': 3,
      'callerId': 2,
      'type': 'VOICE',
      'status': 'RINGING',
      'callerName': ' Mr Bin ',
      'callerAvatarUrl': '/uploads/avatars/2.jpg',
    });
    expect(call.callerName, ' Mr Bin ');
    final peer = CallPeer.callerOf(call);
    expect(peer.name, 'Mr Bin');
    expect(peer.avatarUrl, endsWith('/uploads/avatars/2.jpg'));
    expect(peer.avatarUrl, startsWith('http'));
    expect(peer.isGroup, isFalse);

    // an old backend (no name) → empty: the chat lookup fills it in
    final old = CallModel.fromJson({'id': 7, 'callerId': 2});
    expect(CallPeer.callerOf(old), CallPeer.unknown);
  });
}
