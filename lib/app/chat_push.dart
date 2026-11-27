import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/push/push_messaging.dart';
import '../core/router/auth_session.dart';
import '../features/chat/model/conversation_model.dart';
import '../features/chat/repository/chat_repository.dart';

/// Tap on a chat banner → open that chat (Step 5.7).
///
/// ```
/// the backend sends a VISIBLE push to an OFFLINE member
///   {type: "chat", conversationId: "14", title, body}
///        │ the OS draws the banner (Android channel "chat_messages", iOS alert)
///        ▼ the user taps it
/// app in background ─► PushMessaging.onOpened ─┐
/// app was killed    ─► PushMessaging.launchedBy ┤
///                                               ▼
///   logged in? ─► GET /chats/conversations/14 ─► toOpen = the conversation
///                                               ▼
///   the inbox (InboxOpenRequests) opens it and sets toOpen back to null
/// ```
///
/// Lives in `app/`: it joins `core/push` and the chat feature, and the
/// chat feature never imports push.
class ChatPushOpener {
  ChatPushOpener({required AuthSession session, required ChatRepository chat})
    : _session = session,
      _chat = chat;

  final AuthSession _session;
  final ChatRepository _chat;

  /// The chat to open now. The inbox opens it, then sets it back to null.
  ///
  /// Where the page opens (this class has no screen / context):
  /// toOpen → InboxOpenRequests (features/chat/widgets/inbox_open_requests.dart)
  ///        → InboxPage goToChat → ConfigRouter.popToFirst
  ///                             → ConfigRouter.pushPageAnimation(ConversationPage)
  final ValueNotifier<ConversationModel?> toOpen = ValueNotifier(null);

  /// A tapped chat id, waiting until we're logged in (a cold start shows the
  /// splash first; the request needs the token).
  String? _pending;
  StreamSubscription<Map<String, dynamic>>? _taps;

  /// Call once at start-up, after `runApp` (bootstrap).
  Future<void> attach(PushMessaging push) async {
    _taps = push.onOpened.listen(onTapped);
    _session.addListener(_tryOpen);
    final launched = await push.launchedBy(); // the tap that started the app
    if (launched != null) onTapped(launched);
  }

  void detach() {
    _taps?.cancel();
    _session.removeListener(_tryOpen);
  }

  /// A banner's data. Only chat pushes (calls have their own path, 7.2).
  @visibleForTesting
  void onTapped(Map<String, dynamic> data) {
    if (data['type'] != 'chat') return;
    final id = '${data['conversationId'] ?? ''}';
    if (id.isEmpty) return;
    _pending = id;
    unawaited(_tryOpen());
  }

  Future<void> _tryOpen() async {
    final id = _pending;
    if (id == null || !_session.isAuthenticated) return; // wait for login
    _pending = null;
    final result = await _chat.loadConversation(id);
    result.fold(
      // gone / not a member any more / offline → just stay on the inbox
      (error) => debugPrint('[Push] chat $id not opened: ${error.title}'),
      (conversation) => toOpen.value = conversation,
    );
  }
}
