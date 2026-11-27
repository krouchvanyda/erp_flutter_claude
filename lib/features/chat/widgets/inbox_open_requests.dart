import 'package:flutter/widgets.dart';

import '../model/conversation_model.dart';

/// Opens a chat that SOMEONE ELSE asked for: a tapped push banner (5.7).
///
/// [requests] comes from `app/` (`ChatPushOpener.toOpen`). When it holds a
/// conversation, this takes it (sets it back to null, so it opens ONCE) and
/// calls [onOpen] — the same path as tapping the chat in the list. Also on
/// the first frame: the tap may have happened before the inbox was built
/// (a cold start shows the splash first).
class InboxOpenRequests extends StatefulWidget {
  const InboxOpenRequests({
    super.key,
    required this.requests,
    required this.onOpen,
    required this.child,
  });

  final ValueNotifier<ConversationModel?> requests;
  final void Function(ConversationModel conversation) onOpen;
  final Widget child;

  @override
  State<InboxOpenRequests> createState() => _InboxOpenRequestsState();
}

class _InboxOpenRequestsState extends State<InboxOpenRequests> {
  @override
  void initState() {
    super.initState();
    widget.requests.addListener(_take);
    WidgetsBinding.instance.addPostFrameCallback((_) => _take());
  }

  @override
  void dispose() {
    widget.requests.removeListener(_take);
    super.dispose();
  }

  void _take() {
    final conversation = widget.requests.value;
    if (conversation == null || !mounted) return;
    widget.requests.value = null; // taken: open it once
    widget.onOpen(conversation);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
