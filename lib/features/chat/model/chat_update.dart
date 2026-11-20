import '../../../core/realtime/realtime_event.dart';
import 'conversation_model.dart';
import 'message_model.dart';
import 'reaction_model.dart';

/// A live change from the server (Step 5.3), already turned into our models.
///
/// `RealtimeService` (core) gives `{event, payload}` JSON. This is where the
/// CHAT feature decides what each event means:
///
/// | event                                   | update                |
/// |-----------------------------------------|-----------------------|
/// | `message.send`                          | [MessageArrived]      |
/// | `message.edit`, `message.delete`        | [MessageChanged]      |
/// | `message.read`                          | [MessagesRead]        |
/// | `conversation.create` / `.update`       | [ConversationChanged] |
/// | `conversation.remove`                   | [ConversationRemoved] |
/// | `typing`                                | [TypingChanged]       |
/// | `reaction.toggle`                       | [ReactionsChanged]    |
///
/// Unknown events (calls…) → null, ignored.
sealed class ChatUpdate {
  const ChatUpdate();

  static ChatUpdate? fromRealtime(RealtimeEvent event) {
    final p = event.payloadMap;
    if (p == null) return null;
    try {
      return switch (event.event) {
        'message.send' => MessageArrived(MessageModel.fromJson(p)),
        'message.edit' ||
        'message.delete' => MessageChanged(MessageModel.fromJson(p)),
        'message.read' => MessagesRead(
          conversationId: '${p['conversationId']}',
          userId: '${p['userId']}',
          lastReadMessageId: '${p['lastReadMessageId']}',
        ),
        'conversation.create' || 'conversation.update' => ConversationChanged(
          ConversationModel.fromJson(p),
        ),
        // a ConversationDto, or just { conversationId } when deleted
        'conversation.remove' => ConversationRemoved(
          '${p['conversationId'] ?? p['id']}',
        ),
        'reaction.toggle' => ReactionsChanged(
          messageId: '${p['messageId']}',
          reactions: [
            for (final r in p['reactions'] as List? ?? const [])
              ReactionModel.fromJson(r as Map<String, dynamic>),
          ],
        ),
        'typing' => TypingChanged(
          conversationId: '${p['conversationId']}',
          userId: '${p['userId']}',
          typing: p['typing'] as bool? ?? true,
        ),
        _ => null,
      };
    } catch (_) {
      return null; // a payload we can't read must never crash the chat
    }
  }
}

final class MessageArrived extends ChatUpdate {
  const MessageArrived(this.message);
  final MessageModel message;
}

/// Edited or deleted (a deleted one comes with `deleted: true`, no body).
final class MessageChanged extends ChatUpdate {
  const MessageChanged(this.message);
  final MessageModel message;
}

/// [userId] has read everything up to [lastReadMessageId] → ✓✓.
final class MessagesRead extends ChatUpdate {
  const MessagesRead({
    required this.conversationId,
    required this.userId,
    required this.lastReadMessageId,
  });
  final String conversationId;
  final String userId;
  final String lastReadMessageId;
}

final class ConversationChanged extends ChatUpdate {
  const ConversationChanged(this.conversation);
  final ConversationModel conversation;
}

/// I left / was removed / it was deleted.
final class ConversationRemoved extends ChatUpdate {
  const ConversationRemoved(this.conversationId);
  final String conversationId;
}

/// [userId] started (true) / stopped (false) typing in [conversationId].
/// The WHO comes from the server (the sender's token), not the phone.
final class TypingChanged extends ChatUpdate {
  const TypingChanged({
    required this.conversationId,
    required this.userId,
    required this.typing,
  });
  final String conversationId;
  final String userId;
  final bool typing;
}

/// The FULL reaction list of [messageId] after someone tapped an emoji.
final class ReactionsChanged extends ChatUpdate {
  const ReactionsChanged({required this.messageId, required this.reactions});
  final String messageId;
  final List<ReactionModel> reactions;
}
