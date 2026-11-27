import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../core/network/api_endpoints.dart';
import '../../../core/widgets/app_message_banner.dart';
import '../model/conversation_model.dart';
import '../viewmodel/inbox/inbox_view_model_bloc.dart';

/// The in-app "new message" banner while the app is OPEN (Step 5.7).
///
/// ```
/// a live message from someone else (the inbox bloc's `incoming`)
///   ├─ app not on screen          → nothing (the OS push does it)
///   └─ on screen (the inbox, profile, another chat, a call…)
///                                 → 🔔 AppMessageBanner, tap → open the chat
/// (the open chat, muted chats and call lines never come here: the bloc
///  leaves them out)
/// ```
class InboxMessageBanners extends StatefulWidget {
  const InboxMessageBanners({
    super.key,
    required this.incoming,
    required this.myId,
    required this.onOpen,
    required this.child,
  });

  final Stream<InboxIncomingMessage> incoming;
  final String? Function() myId;
  final void Function(ConversationModel conversation) onOpen;
  final Widget child;

  /// "Dara: Hi" in a group, "Hi" in a direct chat.
  static String messageText(InboxIncomingMessage news) {
    final (:conversation, :message) = news;
    final text = message.previewText.isEmpty
        ? 'New message'
        : message.previewText;
    if (!conversation.isGroup) return text;
    final sender = conversation.members
        .where((m) => m.userId == message.senderId)
        .map((m) => m.displayName)
        .firstOrNull;
    return sender == null ? text : '$sender: $text';
  }

  @override
  State<InboxMessageBanners> createState() => _InboxMessageBannersState();
}

class _InboxMessageBannersState extends State<InboxMessageBanners> {
  late final StreamSubscription<InboxIncomingMessage> _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.incoming.listen(_onIncoming);
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  void _onIncoming(InboxIncomingMessage news) {
    if (!mounted) return;
    final id = news.message.id;
    // minimized → the OS push shows it (the backend sees us OFFLINE)
    final life = WidgetsBinding.instance.lifecycleState;
    if (life != AppLifecycleState.resumed) {
      debugPrint('[banner] msg $id skipped: app is $life');
      return;
    }
    // on every screen, the Chats list too (the user's choice, 5.7)
    debugPrint('[banner] msg $id shown');

    final myId = widget.myId();
    final conversation = news.conversation;
    AppMessageBanner.show(
      context,
      title: conversation.title(myId),
      message: InboxMessageBanners.messageText(news),
      imageUrl: ApiEndPoint.fileUrl(conversation.avatarUrlFor(myId)),
      onTap: () => widget.onOpen(conversation),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
