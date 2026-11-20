import '../core/network/api_endpoints.dart';
import '../features/call/model/call_peer.dart';
import '../features/chat/model/conversation_model.dart';

/// Chat's conversation → the call screen's [CallPeer] (name, photo, and every
/// member's name + photo for group calls). Lives in `app/`: the only layer
/// that may know both features.
CallPeer callPeerOf(ConversationModel conversation, String? myId) => CallPeer(
  name: conversation.title(myId),
  avatarUrl: ApiEndPoint.fileUrl(conversation.avatarUrlFor(myId)),
  isGroup: conversation.isGroup,
  members: {
    for (final m in conversation.members)
      m.userId: CallMember(
        name: m.displayName,
        avatarUrl: ApiEndPoint.fileUrl(m.avatarUrl),
      ),
  },
);
