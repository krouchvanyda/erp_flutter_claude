import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get_it/get_it.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/router/config_router.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/widgets/dynamic_app_bar.dart';
import '../../../../core/widgets/dynamic_status_bar.dart';
import '../../../../shared/widgets/app_background_gradient.dart';
import '../../data/active_conversation_tracker.dart';
import '../../data/chat_settings.dart';
import '../../data/repositories/conversations_repository.dart';
import '../../data/repositories/messages_repository.dart';
import '../../entities/chat_message.dart';
import '../../entities/conversation.dart';
import '../widgets/chat_avatar.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/typing_indicator.dart';
import 'chat_info_page.dart';
import 'image_viewer_page.dart';
import 'video_call_page.dart';
import 'voice_call_page.dart';

/// Slice 10.1.2 — Chat Conversation page.
///
/// Paginated message list (newest at bottom), reply quotes, reactions,
/// typing indicator, optimistic sends, and text / voice / image / file
/// attachment surfaces.
class ChatConversationPage extends StatefulWidget {
  const ChatConversationPage({super.key, required this.conversationId});

  final String conversationId;

  @override
  State<ChatConversationPage> createState() => _ChatConversationPageState();
}

class _ChatConversationPageState extends State<ChatConversationPage> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  String? _replyingToId;
  ChatMessage? _editing;
  String? _highlightId;
  String? _playingVoiceId;
  bool _typingShown = false; // demo: simulated remote-typing

  late final ConversationsRepository _convRepo;
  late final MessagesRepository _msgRepo;
  late final ChatSettings _settings;
  StreamSubscription<ChatSettings>? _settingsSub;

  // Tracks the last message count we rendered so the page can auto-
  // scroll to the latest bubble on initial load AND whenever a new
  // message lands (sent or received). Without this, opening a chat
  // shows the OLDEST messages at the top and the newest ones below
  // the fold — the user has to scroll down manually every time.
  int _lastMessageCount = -1;

  String get _currentUserId => _settings.userId;
  String get _currentUserName => _settings.userName;

  @override
  void initState() {
    super.initState();
    _convRepo = GetIt.I<ConversationsRepository>();
    _msgRepo = GetIt.I<MessagesRepository>();
    _settings = GetIt.I<ChatSettings>();
    // Slice 10.1.6 — register as the currently-open conversation so
    // inbound peer messages skip the unread bump (the user is
    // reading them in real time). Also clear any stale unread
    // count on entry, covering the paths that don't go through the
    // inbox tile (search results, call-page back, deep links).
    ActiveConversationTracker.instance.enter(widget.conversationId);
    unawaited(GetIt.I<ConversationsRepository>()
        .markRead(widget.conversationId)
        .catchError((_) async => throw StateError('conv missing')));
    // Rebuild the page when identity changes so "isOwn" bubbles flip
    // sides instantly.
    _settingsSub = _settings.watch().listen((_) {
      if (mounted) setState(() {});
    });
    // Demo: flash a typing indicator every 30s.
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _typingShown = true);
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _typingShown = false);
      });
    });
  }

  @override
  void dispose() {
    ActiveConversationTracker.instance.leave(widget.conversationId);
    _settingsSub?.cancel();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  /// Slice 10.1.8 — compute the recipient list for a message in the
  /// current conversation. Direct: the other person; group: every member
  /// except us. The transport tags the wire envelope with this list and
  /// every peer's `bootChatTransport` drops messages whose targetIds
  /// don't include them. Empty list (e.g. no participants loaded yet)
  /// falls back to broadcast for back-compat.
  Future<List<String>> _resolveTargetIds() async {
    final conv = await _convRepo.findById(widget.conversationId);
    if (conv == null) return const <String>[];
    final me = _currentUserId;
    return conv.participantPreviews
        .where((p) => p.employeeId != me)
        .map((p) => p.employeeId)
        .toList(growable: false);
  }

  Future<void> _send() async {
    final body = _inputCtrl.text.trim();
    if (body.isEmpty) return;
    if (_editing != null) {
      await _msgRepo.edit(_editing!.id, body);
      _editing = null;
    } else {
      ChatMessage? replyTo;
      if (_replyingToId != null) {
        replyTo = await _msgRepo.findById(_replyingToId!);
      }
      final now = DateTime.now();
      final targetIds = await _resolveTargetIds();
      await _msgRepo.send(
        ChatMessage(
          id: '',
          conversationId: widget.conversationId,
          senderId: _currentUserId,
          senderName: _currentUserName,
          type: ChatMessageType.text,
          body: body,
          sentAt: now,
          replyToId: replyTo?.id,
          replyToSenderName: replyTo?.senderName,
          replyToPreview: replyTo?.body,
        ),
        targetIds: targetIds,
      );
      // The inbox tile renders its own "You: " prefix from
      // `senderId == me`, so the body must NOT carry one too —
      // otherwise the inbox would show "You: You: hi" (Slice 10.1.8).
      await _convRepo.updateLastMessage(
        id: widget.conversationId,
        body: body,
        senderId: _currentUserId,
        senderName: _currentUserName,
        at: now,
      );
    }
    _inputCtrl.clear();
    _replyingToId = null;
    if (mounted) setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent + 200,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(context),
      body: DynamicStatusBar(
        child: Stack(
          children: [
            const AppBackgroundGradient(),
            StreamBuilder<ChatConversation?>(
              stream: _convRepo.watchById(widget.conversationId),
              builder: (context, convSnap) {
                if (!convSnap.hasData || convSnap.data == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                final conv = convSnap.data!;
                return Column(
                  children: [
                    SizedBox(height: context.dynamicAppBarPadding),
                    if (conv.pinnedMessageId != null)
                      _PinnedBanner(messageId: conv.pinnedMessageId!),
                    Expanded(
                      child: StreamBuilder<List<ChatMessage>>(
                        stream: _msgRepo
                            .watchForConversation(widget.conversationId),
                        builder: (context, msgSnap) {
                          if (!msgSnap.hasData) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }
                          final messages = msgSnap.data!;
                          // Auto-scroll to the latest bubble on first
                          // load and whenever the count grows (sent or
                          // received). Skip the animation on the very
                          // first frame — jump straight to the bottom
                          // so the user never sees a flash of oldest-
                          // first content.
                          if (messages.length != _lastMessageCount) {
                            final firstFrame = _lastMessageCount == -1;
                            _lastMessageCount = messages.length;
                            WidgetsBinding.instance
                                .addPostFrameCallback((_) {
                              if (!mounted || !_scrollCtrl.hasClients) {
                                return;
                              }
                              final target =
                                  _scrollCtrl.position.maxScrollExtent;
                              if (firstFrame) {
                                _scrollCtrl.jumpTo(target);
                              } else {
                                _scrollCtrl.animateTo(
                                  target,
                                  duration:
                                      const Duration(milliseconds: 220),
                                  curve: Curves.easeOut,
                                );
                              }
                            });
                          }
                          return _MessageList(
                            messages: messages,
                            conversation: conv,
                            currentUserId: _currentUserId,
                            scrollController: _scrollCtrl,
                            highlightId: _highlightId,
                            playingVoiceId: _playingVoiceId,
                            typingShown: _typingShown,
                            onLongPressBubble: _showContextMenu,
                            onReact: _toggleReaction,
                            onJumpToReply: _jumpTo,
                            onTapVoice: _toggleVoice,
                            onTapImage: _openImageViewer,
                          );
                        },
                      ),
                    ),
                    if (_replyingToId != null) _ReplyPreviewBar(
                      messageId: _replyingToId!,
                      onClose: () => setState(() => _replyingToId = null),
                    ),
                    if (_editing != null) _EditPreviewBar(
                      onClose: () {
                        _editing = null;
                        _inputCtrl.clear();
                        setState(() {});
                      },
                    ),
                    _InputRow(
                      controller: _inputCtrl,
                      onSend: _send,
                      onAttach: _showAttachSheet,
                      onMic: _showVoiceRecording,
                      editing: _editing != null,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final theme = Theme.of(context);
    return AppBar(
      backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.92),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleSpacing: 0,
      title: StreamBuilder<ChatConversation?>(
        stream: _convRepo.watchById(widget.conversationId),
        builder: (context, snap) {
          final conv = snap.data;
          if (conv == null) return const SizedBox.shrink();
          return InkWell(
            borderRadius: BorderRadius.circular(AppRadii.md),
            onTap: () => ConfigRouter.pushPageAnimation(
              context,
              ChatInfoPage(conversationId: conv.id),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (conv.isGroup)
                    GroupAvatarCluster(
                      previews: conv.participantPreviews,
                      size: 36,
                    )
                  else
                    ChatAvatar(
                      name: conv.name,
                      size: 36,
                      presence: conv.presence,
                    ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          conv.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          _subtitleFor(conv),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      actions: [
        IconButton(
          tooltip: 'Voice call',
          icon: const Icon(Icons.call_rounded),
          onPressed: () => ConfigRouter.pushPageAnimation(
            context,
            VoiceCallPage(conversationId: widget.conversationId),
          ),
        ),
        IconButton(
          tooltip: 'Video call',
          icon: const Icon(Icons.videocam_rounded),
          onPressed: () => ConfigRouter.pushPageAnimation(
            context,
            VideoCallPage(conversationId: widget.conversationId),
          ),
        ),
        IconButton(
          tooltip: 'Info',
          icon: const Icon(Icons.more_vert_rounded),
          onPressed: () => ConfigRouter.pushPageAnimation(
            context,
            ChatInfoPage(conversationId: widget.conversationId),
          ),
        ),
      ],
    );
  }

  String _subtitleFor(ChatConversation c) {
    if (c.isGroup) {
      return '${c.totalMembers} members · ${c.onlineCount} online';
    }
    switch (c.presence) {
      case PresenceStatus.online:
        return 'Online';
      case PresenceStatus.away:
        return 'Away';
      case PresenceStatus.offline:
        return 'Offline';
    }
  }

  Future<void> _toggleReaction(String messageId, String emoji) async {
    await _msgRepo.toggleReaction(
      messageId: messageId,
      emoji: emoji,
      employeeId: _currentUserId,
    );
  }

  void _jumpTo(String messageId) {
    setState(() => _highlightId = messageId);
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _highlightId = null);
    });
  }

  /// Slice 10.1.5 — open the full-screen image viewer for the tapped
  /// bubble. Pushed onto the root navigator so the chrome (call buttons,
  /// input bar, etc.) is hidden, just like a system gallery.
  void _openImageViewer(ChatMessage m) {
    ConfigRouter.pushPageAnimation(context, ImageViewerPage(message: m));
  }

  /// Slice 10.1.5 — pick an image via the OS picker (camera or
  /// gallery) and send it as a real `ChatMessageType.image` message.
  /// `fileUrl` is the local absolute path, which the image bubble
  /// reads via `Image.file()` and the viewer reads via `FileImage`.
  Future<void> _sendPickedImage(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 88,
      );
      if (picked == null || !mounted) return;
      final file = File(picked.path);
      if (!await file.exists()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not read the picked image.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      final size = await file.length();
      final now = DateTime.now();
      final targetIds = await _resolveTargetIds();
      await _msgRepo.send(
        ChatMessage(
          id: '',
          conversationId: widget.conversationId,
          senderId: _currentUserId,
          senderName: _currentUserName,
          type: ChatMessageType.image,
          fileUrl: picked.path,
          fileName: picked.name,
          fileSizeBytes: size,
          sentAt: now,
        ),
        targetIds: targetIds,
      );
      // Body is the raw preview ("📷 Photo") — the inbox tile prepends
      // "You: " on its own when sender matches the current user.
      await _convRepo.updateLastMessage(
        id: widget.conversationId,
        body: '📷 Photo',
        senderId: _currentUserId,
        senderName: _currentUserName,
        type: 'image',
        at: now,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not send image: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _toggleVoice(String messageId) {
    setState(() {
      _playingVoiceId = _playingVoiceId == messageId ? null : messageId;
    });
  }

  Future<void> _showContextMenu(ChatMessage m) async {
    HapticFeedback.lightImpact();
    final theme = Theme.of(context);
    final isOwn = m.senderId == _currentUserId;
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              _EmojiQuickBar(
                onSelect: (e) async {
                  Navigator.pop(sheetCtx);
                  await _toggleReaction(m.id, e);
                },
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              _ActionTile(
                icon: Icons.reply_rounded,
                label: 'Reply',
                onTap: () {
                  Navigator.pop(sheetCtx);
                  setState(() => _replyingToId = m.id);
                },
              ),
              if (m.type == ChatMessageType.text)
                _ActionTile(
                  icon: Icons.copy_rounded,
                  label: 'Copy text',
                  onTap: () async {
                    await Clipboard.setData(
                        ClipboardData(text: m.body ?? ''));
                    if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                  },
                ),
              if (isOwn && m.type == ChatMessageType.text)
                _ActionTile(
                  icon: Icons.edit_outlined,
                  label: 'Edit',
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    setState(() {
                      _editing = m;
                      _inputCtrl.text = m.body ?? '';
                    });
                  },
                ),
              _ActionTile(
                icon: m.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                label: m.isPinned ? 'Unpin' : 'Pin to conversation',
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  await _msgRepo.setPinned(m.id, !m.isPinned);
                  await _convRepo.setPinnedMessage(
                    widget.conversationId,
                    m.isPinned ? null : m.id,
                  );
                },
              ),
              if (isOwn)
                _ActionTile(
                  icon: Icons.delete_outline,
                  label: 'Delete',
                  destructive: true,
                  onTap: () async {
                    Navigator.pop(sheetCtx);
                    await _msgRepo.softDelete(m.id);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAttachSheet() async {
    final theme = Theme.of(context);
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 4,
                children: [
                  _AttachTile(
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    color: theme.colorScheme.primary,
                    onTap: () async {
                      Navigator.pop(sheetCtx);
                      await _sendPickedImage(ImageSource.camera);
                    },
                  ),
                  _AttachTile(
                    icon: Icons.image_rounded,
                    label: 'Gallery',
                    color: Colors.green.shade600,
                    onTap: () async {
                      Navigator.pop(sheetCtx);
                      await _sendPickedImage(ImageSource.gallery);
                    },
                  ),
                  _AttachTile(
                    icon: Icons.insert_drive_file_rounded,
                    label: 'File',
                    color: Colors.orange.shade700,
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      _attachStub('File picker');
                    },
                  ),
                  _AttachTile(
                    icon: Icons.location_on_rounded,
                    label: 'Location',
                    color: Colors.red,
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      _attachStub('Map share');
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _attachStub(String what) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('$what would open here.'),
      ),
    );
  }

  Future<void> _showVoiceRecording() async {
    final theme = Theme.of(context);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ).animate(onPlay: (c) => c.repeat()).fade(
                      begin: 0.3,
                      end: 1.0,
                      duration: 600.ms,
                    ),
                const SizedBox(width: 8),
                Text(
                  'Recording…',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Text(
                  '0:03',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(sheetCtx),
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () async {
                      Navigator.pop(sheetCtx);
                      final now = DateTime.now();
                      final targetIds = await _resolveTargetIds();
                      await _msgRepo.send(
                        ChatMessage(
                          id: '',
                          conversationId: widget.conversationId,
                          senderId: _currentUserId,
                          senderName: _currentUserName,
                          type: ChatMessageType.voice,
                          voiceUrl: 'demo://voice/new-clip.m4a',
                          voiceDurationSeconds: 3,
                          sentAt: now,
                        ),
                        targetIds: targetIds,
                      );
                      // Body is raw preview — inbox prefixes "You: ".
                      await _convRepo.updateLastMessage(
                        id: widget.conversationId,
                        body: '🎤 Voice message · 0:03',
                        senderId: _currentUserId,
                        senderName: _currentUserName,
                        type: 'voice',
                        at: now,
                      );
                    },
                    icon: const Icon(Icons.send_rounded),
                    label: const Text('Send'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PinnedBanner extends StatelessWidget {
  const _PinnedBanner({required this.messageId});
  final String messageId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<ChatMessage?>(
      future: GetIt.I<MessagesRepository>().findById(messageId),
      builder: (context, snap) {
        if (!snap.hasData || snap.data == null) return const SizedBox.shrink();
        final m = snap.data!;
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border(
              left: BorderSide(color: theme.colorScheme.tertiary, width: 3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.push_pin_rounded,
                size: 16,
                color: theme.colorScheme.tertiary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  m.body ?? '(pinned message)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onTertiaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.messages,
    required this.conversation,
    required this.scrollController,
    required this.highlightId,
    required this.playingVoiceId,
    required this.typingShown,
    required this.currentUserId,
    required this.onLongPressBubble,
    required this.onReact,
    required this.onJumpToReply,
    required this.onTapVoice,
    required this.onTapImage,
  });

  final List<ChatMessage> messages;
  final ChatConversation conversation;
  final ScrollController scrollController;
  final String? highlightId;
  final String? playingVoiceId;
  final bool typingShown;
  final String currentUserId;
  final void Function(ChatMessage m) onLongPressBubble;
  final Future<void> Function(String messageId, String emoji) onReact;
  final void Function(String messageId) onJumpToReply;
  final void Function(String messageId) onTapVoice;
  final void Function(ChatMessage m) onTapImage;

  @override
  Widget build(BuildContext context) {
    // Build the linear list with date separators woven in.
    final items = <_ListItem>[];
    DateTime? lastDay;
    String? lastSenderId;
    DateTime? lastSentAt;
    for (var i = 0; i < messages.length; i++) {
      final m = messages[i];
      final day = DateTime(m.sentAt.year, m.sentAt.month, m.sentAt.day);
      if (lastDay == null || !_isSameDay(lastDay, day)) {
        items.add(_ListItem.separator(day));
      }
      final groupBreak = lastSenderId != m.senderId ||
          (lastSentAt != null && m.sentAt.difference(lastSentAt).inMinutes > 5);
      items.add(_ListItem.message(m, showSender: groupBreak));
      lastDay = day;
      lastSenderId = m.senderId;
      lastSentAt = m.sentAt;
    }
    if (typingShown) {
      items.add(_ListItem.typing(conversation));
    }
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      itemCount: items.length,
      itemBuilder: (_, idx) {
        final item = items[idx];
        return switch (item.kind) {
          _ListItemKind.separator => DateSeparatorChip(day: item.day!),
          _ListItemKind.message => ChatBubble(
              message: item.message!,
              isOwn: item.message!.senderId == currentUserId,
              showSender: item.showSender,
              currentUserId: currentUserId,
              onLongPress: () => onLongPressBubble(item.message!),
              onReact: (e) => onReact(item.message!.id, e),
              onJumpToReply: onJumpToReply,
              onTapVoice: () => onTapVoice(item.message!.id),
              onTapImage: () => onTapImage(item.message!),
              isVoicePlaying: playingVoiceId == item.message!.id,
              highlight: highlightId == item.message!.id,
            ),
          _ListItemKind.typing => TypingIndicator(
              label:
                  '${item.conversation!.isGroup ? item.conversation!.participantPreviews.first.name : item.conversation!.name} is typing…',
            ),
        };
      },
    );
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

enum _ListItemKind { separator, message, typing }

class _ListItem {
  _ListItem._(this.kind,
      {this.day, this.message, this.showSender = false, this.conversation});
  final _ListItemKind kind;
  final DateTime? day;
  final ChatMessage? message;
  final bool showSender;
  final ChatConversation? conversation;

  factory _ListItem.separator(DateTime day) =>
      _ListItem._(_ListItemKind.separator, day: day);
  factory _ListItem.message(ChatMessage m, {required bool showSender}) =>
      _ListItem._(_ListItemKind.message, message: m, showSender: showSender);
  factory _ListItem.typing(ChatConversation c) =>
      _ListItem._(_ListItemKind.typing, conversation: c);
}

class _ReplyPreviewBar extends StatelessWidget {
  const _ReplyPreviewBar({required this.messageId, required this.onClose});
  final String messageId;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<ChatMessage?>(
      future: GetIt.I<MessagesRepository>().findById(messageId),
      builder: (context, snap) {
        final m = snap.data;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
          child: Row(
            children: [
              Container(width: 3, height: 36, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Replying to ${m?.senderName ?? '…'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      m?.body ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: onClose,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EditPreviewBar extends StatelessWidget {
  const _EditPreviewBar({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.5),
      child: Row(
        children: [
          Icon(Icons.edit_rounded, size: 16, color: theme.colorScheme.tertiary),
          const SizedBox(width: 8),
          Text(
            'Editing message',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onTertiaryContainer,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

class _InputRow extends StatelessWidget {
  const _InputRow({
    required this.controller,
    required this.onSend,
    required this.onAttach,
    required this.onMic,
    required this.editing,
  });
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  final VoidCallback onMic;
  final bool editing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              icon: const Icon(Icons.attach_file_rounded),
              onPressed: onAttach,
              tooltip: 'Attach',
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                ),
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText: 'Message…',
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    isDense: true,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (_, value, __) {
                final hasText = value.text.trim().isNotEmpty;
                return Material(
                  color: hasText
                      ? theme.colorScheme.primary
                      : theme.colorScheme.surfaceContainerHighest,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: hasText ? onSend : onMic,
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(
                        hasText
                            ? (editing ? Icons.check_rounded : Icons.send_rounded)
                            : Icons.mic_rounded,
                        color: hasText
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _EmojiQuickBar extends StatelessWidget {
  const _EmojiQuickBar({required this.onSelect});
  final void Function(String emoji) onSelect;

  @override
  Widget build(BuildContext context) {
    const emojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (final e in emojis)
          InkWell(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            onTap: () => onSelect(e),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Text(e, style: const TextStyle(fontSize: 24)),
            ),
          ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = destructive ? theme.colorScheme.error : theme.colorScheme.onSurface;
    return ListTile(
      leading: Icon(icon, color: fg),
      title: Text(
        label,
        style: TextStyle(color: fg, fontWeight: FontWeight.w700),
      ),
      onTap: onTap,
    );
  }
}

class _AttachTile extends StatelessWidget {
  const _AttachTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.md),
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
