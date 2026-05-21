import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_radii.dart';
import '../../entities/chat_message.dart';
import 'chat_avatar.dart';

/// Slice 10.1.2 — chat bubble rendering all four content types
/// (text / voice / image / file) plus reply quotes, edited label, and
/// own-message read receipts. System messages render as italic
/// centered captions (no bubble).
class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.message,
    required this.isOwn,
    required this.showSender,
    required this.currentUserId,
    this.onReact,
    this.onLongPress,
    this.onJumpToReply,
    this.onTapVoice,
    this.isVoicePlaying = false,
    this.highlight = false,
  });

  final ChatMessage message;
  final bool isOwn;
  final bool showSender;
  final String currentUserId;
  final void Function(String emoji)? onReact;
  final VoidCallback? onLongPress;
  final void Function(String messageId)? onJumpToReply;
  final VoidCallback? onTapVoice;
  final bool isVoicePlaying;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    if (message.type == ChatMessageType.system) {
      return _SystemCaption(message: message);
    }
    final theme = Theme.of(context);
    final align = isOwn ? Alignment.centerRight : Alignment.centerLeft;
    return Align(
      alignment: align,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        child: Column(
          crossAxisAlignment:
              isOwn ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (showSender && !isOwn)
              Padding(
                padding: const EdgeInsets.only(left: 44, bottom: 4),
                child: Text(
                  message.senderName,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                  ),
                ),
              ),
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!isOwn) _LeadingAvatar(message: message, show: showSender),
                if (!isOwn) const SizedBox(width: 8),
                Flexible(
                  child: GestureDetector(
                    onLongPress: onLongPress,
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.75,
                      ),
                      decoration: BoxDecoration(
                        color: _bubbleColor(theme),
                        borderRadius: _bubbleRadius(),
                        border: highlight
                            ? Border.all(
                                color: theme.colorScheme.primary,
                                width: 2,
                              )
                            : null,
                        boxShadow: highlight
                            ? null
                            : [
                                BoxShadow(
                                  color:
                                      Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                      ),
                      child: ClipRRect(
                        borderRadius: _bubbleRadius(),
                        child: Padding(
                          padding: _bubblePadding(),
                          child: _BubbleContent(
                            message: message,
                            isOwn: isOwn,
                            onJumpToReply: onJumpToReply,
                            onTapVoice: onTapVoice,
                            isVoicePlaying: isVoicePlaying,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (message.reactions.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(
                  top: 4,
                  left: isOwn ? 0 : 44,
                  right: isOwn ? 4 : 0,
                ),
                child: _ReactionRow(
                  reactions: message.reactions,
                  currentUserId: currentUserId,
                  onReact: onReact,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _bubbleColor(ThemeData theme) {
    if (message.isDeleted) {
      return theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6);
    }
    if (isOwn) return theme.colorScheme.primary;
    return theme.colorScheme.surface;
  }

  EdgeInsets _bubblePadding() {
    if (message.type == ChatMessageType.image && !message.isDeleted) {
      return const EdgeInsets.all(4);
    }
    return const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
  }

  BorderRadius _bubbleRadius() {
    const r = AppRadii.lg;
    if (isOwn) {
      return const BorderRadius.only(
        topLeft: Radius.circular(r),
        topRight: Radius.circular(4),
        bottomLeft: Radius.circular(r),
        bottomRight: Radius.circular(r),
      );
    }
    return const BorderRadius.only(
      topLeft: Radius.circular(4),
      topRight: Radius.circular(r),
      bottomLeft: Radius.circular(r),
      bottomRight: Radius.circular(r),
    );
  }
}

class _LeadingAvatar extends StatelessWidget {
  const _LeadingAvatar({required this.message, required this.show});
  final ChatMessage message;
  final bool show;

  @override
  Widget build(BuildContext context) {
    if (!show) return const SizedBox(width: 36);
    return ChatAvatar(
      name: message.senderName,
      size: 36,
      showStatus: false,
    );
  }
}

class _BubbleContent extends StatelessWidget {
  const _BubbleContent({
    required this.message,
    required this.isOwn,
    required this.onJumpToReply,
    required this.onTapVoice,
    required this.isVoicePlaying,
  });
  final ChatMessage message;
  final bool isOwn;
  final void Function(String messageId)? onJumpToReply;
  final VoidCallback? onTapVoice;
  final bool isVoicePlaying;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (message.isDeleted) {
      return Text(
        'Message deleted',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (message.replyToId != null)
          _ReplyQuote(message: message, isOwn: isOwn, onTap: onJumpToReply),
        switch (message.type) {
          ChatMessageType.text => _TextContent(message: message, isOwn: isOwn),
          ChatMessageType.voice => _VoiceContent(
              message: message,
              isOwn: isOwn,
              isPlaying: isVoicePlaying,
              onTap: onTapVoice,
            ),
          ChatMessageType.image => _ImageContent(message: message),
          ChatMessageType.file => _FileContent(message: message, isOwn: isOwn),
          ChatMessageType.system => const SizedBox.shrink(),
        },
        const SizedBox(height: 4),
        _BubbleFooter(message: message, isOwn: isOwn),
      ],
    );
  }
}

class _ReplyQuote extends StatelessWidget {
  const _ReplyQuote({
    required this.message,
    required this.isOwn,
    required this.onTap,
  });
  final ChatMessage message;
  final bool isOwn;
  final void Function(String messageId)? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = isOwn ? theme.colorScheme.onPrimary : theme.colorScheme.primary;
    final bg = isOwn
        ? theme.colorScheme.onPrimary.withValues(alpha: 0.12)
        : theme.colorScheme.primaryContainer.withValues(alpha: 0.4);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: () {
          if (message.replyToId != null && onTap != null) {
            onTap!(message.replyToId!);
          }
        },
        borderRadius: BorderRadius.circular(AppRadii.sm),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppRadii.sm),
            border: Border(left: BorderSide(color: fg, width: 3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message.replyToSenderName ?? '',
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                message.replyToPreview ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isOwn
                      ? theme.colorScheme.onPrimary.withValues(alpha: 0.8)
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TextContent extends StatelessWidget {
  const _TextContent({required this.message, required this.isOwn});
  final ChatMessage message;
  final bool isOwn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      message.body ?? '',
      style: theme.textTheme.bodyMedium?.copyWith(
        color: isOwn ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
        height: 1.35,
      ),
    );
  }
}

class _VoiceContent extends StatelessWidget {
  const _VoiceContent({
    required this.message,
    required this.isOwn,
    required this.isPlaying,
    required this.onTap,
  });
  final ChatMessage message;
  final bool isOwn;
  final bool isPlaying;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = isOwn ? theme.colorScheme.onPrimary : theme.colorScheme.primary;
    final bg = isOwn
        ? theme.colorScheme.onPrimary.withValues(alpha: 0.15)
        : theme.colorScheme.primaryContainer.withValues(alpha: 0.5);
    final duration = message.voiceDurationSeconds ?? 0;
    final minutes = (duration ~/ 60).toString();
    final seconds = (duration % 60).toString().padLeft(2, '0');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: fg,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          _Waveform(
            isOwn: isOwn,
            isPlaying: isPlaying,
            color: fg,
          ),
          const SizedBox(width: 10),
          Text(
            '$minutes:$seconds',
            style: theme.textTheme.bodySmall?.copyWith(
              color: isOwn
                  ? theme.colorScheme.onPrimary.withValues(alpha: 0.9)
                  : theme.colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _Waveform extends StatelessWidget {
  const _Waveform({
    required this.isOwn,
    required this.isPlaying,
    required this.color,
  });
  final bool isOwn;
  final bool isPlaying;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // Static silhouette — real waveform would come from the audio file.
    const heights = [0.4, 0.7, 0.5, 0.9, 0.6, 0.8, 0.4, 0.7, 0.5, 0.9, 0.3, 0.6, 0.4, 0.5];
    return SizedBox(
      width: 110,
      height: 24,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < heights.length; i++)
            Container(
              width: 3,
              height: 22 * heights[i],
              decoration: BoxDecoration(
                color: color.withValues(alpha: isPlaying ? 0.95 : 0.55),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
    );
  }
}

class _ImageContent extends StatelessWidget {
  const _ImageContent({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: Container(
        width: 220,
        height: 160,
        color: theme.colorScheme.surfaceContainerHighest,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_outlined,
              color: theme.colorScheme.onSurfaceVariant,
              size: 40,
            ),
            const SizedBox(height: 6),
            Text(
              message.fileName ?? 'photo',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FileContent extends StatelessWidget {
  const _FileContent({required this.message, required this.isOwn});
  final ChatMessage message;
  final bool isOwn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = isOwn ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface;
    final muted = isOwn
        ? theme.colorScheme.onPrimary.withValues(alpha: 0.75)
        : theme.colorScheme.onSurfaceVariant;
    final iconBg = isOwn
        ? theme.colorScheme.onPrimary.withValues(alpha: 0.18)
        : theme.colorScheme.primaryContainer.withValues(alpha: 0.6);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
          child: Icon(
            Icons.insert_drive_file_outlined,
            color: fg,
            size: 20,
          ),
        ),
        const SizedBox(width: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 180),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message.fileName ?? 'file',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                _fileSize(message.fileSizeBytes),
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _fileSize(int? bytes) {
    if (bytes == null || bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB'];
    var size = bytes.toDouble();
    var unit = 0;
    while (size >= 1024 && unit < units.length - 1) {
      size /= 1024;
      unit++;
    }
    return '${size.toStringAsFixed(size >= 100 ? 0 : 1)} ${units[unit]}';
  }
}

class _BubbleFooter extends StatelessWidget {
  const _BubbleFooter({required this.message, required this.isOwn});
  final ChatMessage message;
  final bool isOwn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isOwn
        ? theme.colorScheme.onPrimary.withValues(alpha: 0.75)
        : theme.colorScheme.onSurfaceVariant;
    final df = DateFormat('HH:mm');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (message.editedAt != null) ...[
          Text(
            'edited · ',
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontSize: 10,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
        Text(
          df.format(message.sentAt),
          style: theme.textTheme.bodySmall?.copyWith(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (isOwn) ...[
          const SizedBox(width: 4),
          _ReadReceipt(message: message, color: color),
        ],
      ],
    );
  }
}

class _ReadReceipt extends StatelessWidget {
  const _ReadReceipt({required this.message, required this.color});
  final ChatMessage message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (message.readAt != null) {
      return Icon(Icons.done_all, size: 14, color: Colors.lightBlueAccent.shade100);
    }
    if (message.deliveredAt != null) {
      return Icon(Icons.done_all, size: 14, color: color);
    }
    return Icon(Icons.access_time_rounded, size: 12, color: color);
  }
}

class _ReactionRow extends StatelessWidget {
  const _ReactionRow({
    required this.reactions,
    required this.currentUserId,
    this.onReact,
  });
  final List<ChatReaction> reactions;
  final String currentUserId;
  final void Function(String emoji)? onReact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final r in reactions)
          InkWell(
            onTap: onReact == null ? null : () => onReact!(r.emoji),
            borderRadius: BorderRadius.circular(AppRadii.pill),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: r.employeeIds.contains(currentUserId)
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadii.pill),
                border: Border.all(
                  color: r.employeeIds.contains(currentUserId)
                      ? theme.colorScheme.primary.withValues(alpha: 0.6)
                      : theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(r.emoji, style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 4),
                  Text(
                    '${r.count}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: r.employeeIds.contains(currentUserId)
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _SystemCaption extends StatelessWidget {
  const _SystemCaption({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Center(
        child: Text(
          message.body ?? '',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }
}

/// Date separator chip used between bubbles when the calendar day changes.
class DateSeparatorChip extends StatelessWidget {
  const DateSeparatorChip({super.key, required this.day});
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
          child: Text(
            _label(day),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }

  static String _label(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(d.year, d.month, d.day);
    final diff = today.difference(that).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return DateFormat('EEEE').format(d);
    return DateFormat('EEE d MMM yyyy').format(d);
  }
}
