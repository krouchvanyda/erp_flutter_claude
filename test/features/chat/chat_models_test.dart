import 'package:erp_mobile/features/chat/model/chat_enums.dart';
import 'package:erp_mobile/features/chat/model/conversation_model.dart';
import 'package:erp_mobile/features/chat/model/message_model.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> direct({Map<String, dynamic>? last}) => {
  'id': 10,
  'type': 'DIRECT',
  'name': null,
  'members': [
    {'userId': 1, 'fullName': 'Me Myself', 'role': 'MEMBER'},
    {'userId': 2, 'fullName': 'Jane Doe', 'avatarUrl': '/uploads/j.jpg'},
  ],
  'lastMessage': last,
  'lastMessageAt': '2026-11-20T03:00:00Z',
  'unreadCount': 3,
};

void main() {
  test('DIRECT: title + avatar = the OTHER person', () {
    final c = ConversationModel.fromJson(direct());
    expect(c.title('1'), 'Jane Doe');
    expect(c.avatarUrlFor('1'), '/uploads/j.jpg');
    expect(c.unreadCount, 3);
    expect(c.id, '10'); // number → String
  });

  test('GROUP: title = group name; empty name → "Group"', () {
    final c = ConversationModel.fromJson({
      'id': 11,
      'type': 'GROUP',
      'name': 'Team ERP',
    });
    expect(c.isGroup, isTrue);
    expect(c.title('1'), 'Team ERP');
    expect(
      ConversationModel.fromJson({'id': 12, 'type': 'GROUP'}).title('1'),
      'Group',
    );
  });

  test('previewText per type; deleted wins', () {
    MessageModel msg(String type, {bool deleted = false}) =>
        MessageModel.fromJson({
          'id': 1,
          'senderId': 2,
          'type': type,
          'body': ' hi ',
          'deleted': deleted,
        });
    expect(msg('TEXT').previewText, 'hi');
    expect(msg('IMAGE').previewText, '📷 Photo');
    expect(msg('VOICE').previewText, '🎤 Voice message');
    expect(msg('FILE').previewText, '📎 File');
    expect(msg('TEXT', deleted: true).previewText, 'Message deleted');
  });

  test('unknown enum values fall back safely (no crash)', () {
    expect(MessageType.fromJson('STICKER'), MessageType.text);
    expect(ConversationType.fromJson(null), ConversationType.direct);
  });

  test('times are converted to LOCAL time', () {
    final c = ConversationModel.fromJson(direct());
    expect(c.lastMessageAt!.isUtc, isFalse);
  });

  test('== compares data (members, reactions, readBy sets)', () {
    final last = {
      'id': 5,
      'senderId': 2,
      'type': 'TEXT',
      'body': 'x',
      'reactions': [
        {'userId': 1, 'emoji': '👍'},
      ],
      'readByUserIds': [1],
    };
    expect(
      ConversationModel.fromJson(direct(last: last)),
      ConversationModel.fromJson(direct(last: last)),
    );
  });
}
