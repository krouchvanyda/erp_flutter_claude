import 'package:flutter/material.dart';

import '../../../core/network/api_endpoints.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/chat_time.dart';
import '../../../core/widgets/app_avatar.dart';
import '../model/chat_enums.dart';
import '../model/member_model.dart';
import '../model/message_model.dart';
import '../model/outgoing_message.dart';
import 'chat_day_divider.dart';
import 'message_bubble.dart';

/// The scrolling messages of one conversation.
///
/// `ListView(reverse: true)`: index 0 is at the BOTTOM. Our lists are
/// newest-first, so the newest message is at the bottom with NO scroll math,
/// and the list opens there by itself.
///
/// ```
/// index 3  ⟳ loading older       ← top: extentAfter < 300 → onLoadOlder
/// index 2  ── Yesterday ── + bubble
/// index 1  bubble (server)
/// index 0  bubble (outgoing 🕓)   ← bottom
/// ```
class MessageList extends StatefulWidget {
  const MessageList({
    super.key,
    required this.messages,
    required this.outgoing,
    required this.myId,
    required this.isGroup,
    required this.members,
    required this.isLoadingOlder,
    required this.onLoadOlder,
    required this.onRetry,
  });

  final List<MessageModel> messages; // newest first
  final List<OutgoingMessage> outgoing; // newest first, drawn below messages
  final String? myId;
  final bool isGroup;
  final List<MemberModel> members;
  final bool isLoadingOlder;
  final VoidCallback onLoadOlder;
  final ValueChanged<String> onRetry; // localId

  static const double maxWidth = 720;
  static const double _loadOlderBefore = 300; // px from the top
  static const Duration _runGap = Duration(minutes: 5);

  @override
  State<MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<MessageList> {
  final _scroll = ScrollController();

  @override
  void didUpdateWidget(MessageList old) {
    super.didUpdateWidget(old);
    // I just sent something while scrolled up → jump down to see it.
    final iSent = widget.outgoing.length > old.outgoing.length;
    if (iSent && _scroll.hasClients && _scroll.offset > 0) {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entries = [
      for (final o in widget.outgoing) _Entry.outgoing(o, widget.myId),
      for (final m in widget.messages) _Entry.server(m, widget.myId),
    ];
    final membersById = {for (final m in widget.members) m.userId: m};

    return NotificationListener<ScrollNotification>(
      // reverse: true → "after" is towards the TOP (older messages)
      onNotification: (n) {
        if (n.metrics.extentAfter < MessageList._loadOlderBefore) {
          widget.onLoadOlder(); // the BLoC ignores repeats
        }
        return false;
      },
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: MessageList.maxWidth),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bubbleMax = constraints.maxWidth * 0.75;
              return ListView.builder(
                controller: _scroll,
                reverse: true,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                itemCount: entries.length + (widget.isLoadingOlder ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == entries.length) {
                    return const Padding(
                      padding: EdgeInsets.all(AppSpacing.md),
                      child: Center(
                        child: SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    );
                  }
                  return _buildEntry(entries, index, membersById, bubbleMax);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildEntry(
    List<_Entry> entries,
    int index,
    Map<String, MemberModel> membersById,
    double bubbleMax,
  ) {
    final e = entries[index];
    final older = index + 1 < entries.length ? entries[index + 1] : null;
    final newer = index > 0 ? entries[index - 1] : null;

    final newDay = older == null || !ChatTime.sameDay(older.time, e.time);
    final firstInRun = newDay || !_sameRun(older, e);
    final lastInRun =
        newer == null ||
        !ChatTime.sameDay(e.time, newer.time) ||
        !_sameRun(e, newer);

    final showTheirSide = widget.isGroup && !e.isMine;
    final sender = membersById[e.senderId];

    return Column(
      key: ValueKey(e.key),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (newDay) ChatDayDivider(label: ChatTime.day(e.time)),
        Padding(
          padding: EdgeInsets.only(
            top: firstInRun && !newDay ? AppSpacing.sm + 2 : 2,
          ),
          child: MessageBubble(
            text: e.text,
            time: ChatTime.bubble(e.time),
            isMine: e.isMine,
            maxWidth: bubbleMax,
            status: e.status,
            isPlaceholder: e.isPlaceholder,
            edited: e.edited,
            firstInRun: firstInRun,
            lastInRun: lastInRun,
            senderName: showTheirSide && firstInRun
                ? (sender?.displayName ?? 'Unknown')
                : null,
            // groups: avatar on the LAST bubble of a run, an empty slot on
            // the others so the bubbles stay lined up
            leading: !showTheirSide
                ? null
                : lastInRun
                ? AppAvatar(
                    name: sender?.displayName ?? '?',
                    imageUrl: ApiEndPoint.fileUrl(sender?.avatarUrl),
                    size: 28,
                  )
                : const SizedBox.shrink(),
            onRetry: e.localId == null
                ? null
                : () => widget.onRetry(e.localId!),
          ),
        ),
      ],
    );
  }

  /// Same person, close in time → one "run" (joined bubbles, one name).
  static bool _sameRun(_Entry older, _Entry newer) =>
      older.senderId == newer.senderId &&
      newer.time.difference(older.time) < MessageList._runGap;
}

/// One row's data, from either a server message or an outgoing one, so the
/// list code above doesn't care which. (Data, not a widget.)
class _Entry {
  _Entry.server(MessageModel m, String? myId)
    : key = m.id,
      localId = null,
      senderId = m.senderId,
      isMine = m.senderId == myId,
      time = m.createdAt ?? DateTime.now(),
      text = m.deleted || m.type != MessageType.text
          ? m
                .previewText // "Message deleted", "📷 Photo" (until 5.5)
          : (m.body ?? ''),
      isPlaceholder = m.deleted || m.type != MessageType.text,
      edited = m.editedAt != null && !m.deleted,
      status = m.senderId != myId
          ? BubbleStatus.none
          : m.readByUserIds.isNotEmpty
          ? BubbleStatus.read
          : BubbleStatus.sent;

  _Entry.outgoing(OutgoingMessage o, String? myId)
    : key = o.localId,
      localId = o.localId,
      senderId = myId ?? '',
      isMine = true,
      time = o.createdAt,
      text = o.text,
      isPlaceholder = false,
      edited = false,
      status = o.failed ? BubbleStatus.failed : BubbleStatus.sending;

  final String key;
  final String? localId; // only outgoing
  final String senderId;
  final bool isMine;
  final DateTime time;
  final String text;
  final bool isPlaceholder;
  final bool edited;
  final BubbleStatus status;
}
