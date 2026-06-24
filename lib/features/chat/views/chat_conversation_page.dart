import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../../../core/router/config_router.dart';
import '../../../core/theme/app_font_size.dart';
import '../../../core/theme/app_label.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/widgets/dynamic_app_bar.dart';
import '../../../core/widgets/dynamic_status_bar.dart';
import '../../../shared/widgets/app_background_gradient.dart';
import '../repositories/active_conversation_tracker.dart';
import '../repositories/chat_settings.dart';
import '../repositories/chat_transport.dart';
import '../repositories/call_log_repository.dart';
import '../repositories/conversations_repository.dart';
import '../repositories/messages_repository.dart';
import '../repositories/presence_repository.dart';
import '../models/call_log.dart';
import '../models/chat_message.dart';
import '../models/conversation.dart';
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

  /// Single shared player for voice-message playback. One at a time — tapping
  /// a second clip stops the first. Disposed in [dispose].
  final AudioPlayer _voicePlayer = AudioPlayer();
  StreamSubscription<PlayerState>? _voicePlayerSub;

  /// Live 0..1 playback progress of the currently-playing clip, fed to that
  /// message's bubble so its waveform fills as it plays (Telegram-style).
  final ValueNotifier<double> _voiceProgress = ValueNotifier<double>(0);
  StreamSubscription<Duration>? _voicePosSub;
  Duration _voiceTotal = Duration.zero;

  /// True when the current clip ([_playingVoiceId]) is loaded but PAUSED —
  /// the position is held so the next tap resumes from there.
  bool _voicePaused = false;

  late final ConversationsRepository _convRepo;
  late final ChatTransport _transport;
  late final MessagesRepository _msgRepo;
  late final ChatSettings _settings;
  late final PresenceRepository _presence;
  StreamSubscription<ChatSettings>? _settingsSub;
  StreamSubscription<List<ChatMessage>>? _messagesSub;
  Timer? _markReadDebounce;
  int _lastMarkedReadId = 0;

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
    _convRepo = context.read<ConversationsRepository>();
    _transport = context.read<ChatTransport>();
    _msgRepo = context.read<MessagesRepository>();
    _settings = context.read<ChatSettings>();
    _presence = context.read<PresenceRepository>();
    // Refresh this conversation's peer presence on entry. The global
    // `/topic/presence` snapshot can be stale — if a peer came online
    // AFTER our last loadAll, no ONLINE delta may have reached us, so
    // their dot stays offline forever. Re-pulling on open is how the
    // user sees an up-to-date status the moment they look at the chat.
    unawaited(_refreshPeerPresence());
    // Slice 10.1.6 — register as the currently-open conversation so
    // inbound peer messages skip the unread bump (the user is
    // reading them in real time). Also clear any stale unread
    // count on entry, covering the paths that don't go through the
    // inbox tile (search results, call-page back, deep links).
    ActiveConversationTracker.instance.enter(widget.conversationId);
    unawaited(context.read<ConversationsRepository>()
        .markRead(widget.conversationId)
        .catchError((_) async => throw StateError('conv missing')));
    // Prompt 3 — pull real history from `GET /chats/conversations/{id}/messages`
    // and ask the transport to subscribe to `/topic/conversations/{id}`
    // for live updates. No-op on seed convs (`conv-001` etc.) or when
    // the backend data source hasn't been bound (demo mode).
    unawaited(_msgRepo.loadForConversation(widget.conversationId).then((_) {
      // Section 7 op #9 — once history is loaded, tell the backend
      // we've read up to the newest message. The server clears
      // unread and fans `conversation.update` to our other sessions
      // so the badge clears there too.
      _markReadDebounced();
    }));
    // Also re-mark on every fresh emission so messages arriving while
    // we're on the page don't leave a stale server-side counter
    // (TC-RS.2). Debounced inside `_markReadDebounced` so a rapid
    // burst of inbound messages collapses to one POST.
    _messagesSub =
        _msgRepo.watchForConversation(widget.conversationId).listen((_) {
      _markReadDebounced();
    });
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
    // Prompt 3 — drop the per-conv STOMP subscriptions
    // (`/topic/conversations/{id}` + `…/call`) so we don't keep them
    // alive for every chat the user has ever opened this session.
    _transport.unsubscribeConversation(widget.conversationId);
    _settingsSub?.cancel();
    _messagesSub?.cancel();
    _markReadDebounce?.cancel();
    _voicePlayerSub?.cancel();
    _voicePosSub?.cancel();
    _voicePlayer.dispose();
    _voiceProgress.dispose();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  /// Start an outgoing call from the AppBar buttons. We DON'T gate the call
  /// on mic/camera permission here: the ring sent to the callee is just a
  /// REST invite and doesn't need the mic, so the call must always be placed
  /// (otherwise the other side never rings). The native mic/camera prompt is
  /// triggered on the call page itself the moment it opens, and the call
  /// proceeds whether or not the user grants it (no mic → A simply transmits
  /// no audio). iOS-only prompt; Android unchanged.
  void _startCall({required bool isVideo}) {
    ConfigRouter.pushPageAnimation(
      context,
      isVideo
          ? VideoCallPage(conversationId: widget.conversationId)
          : VoiceCallPage(conversationId: widget.conversationId),
    );
  }

  /// Section 7 op #9 — POST /chats/conversations/{id}/read with the
  /// highest numeric message id we've seen for this conv. Debounced
  /// to one POST per second so a burst of inbound messages collapses
  /// to a single backend call. Skips when the newest id is the same
  /// as last time (idempotent).
  void _markReadDebounced() {
    _markReadDebounce?.cancel();
    _markReadDebounce = Timer(const Duration(seconds: 1), () async {
      final msgs = await _msgRepo.getForConversation(widget.conversationId);
      var maxId = 0;
      for (final m in msgs) {
        final n = int.tryParse(m.id);
        if (n != null && n > maxId) maxId = n;
      }
      if (maxId == 0 || maxId == _lastMarkedReadId) return;
      _lastMarkedReadId = maxId;
      try {
        await _convRepo.markReadRemote(widget.conversationId, maxId);
      } catch (_) {/* swallow — next emission will retry */}
    });
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

  /// Pull the current presence for this conversation's peer(s) from
  /// `GET /chats/presence?ids=…` on entry, so a dot that went stale
  /// (peer came online with no ONLINE delta delivered to us) corrects
  /// itself the moment the chat opens. Targeted to the peers in view —
  /// no full-snapshot round-trip. Swallows errors (the repo already
  /// does); the cached dot just stays as-is on failure.
  Future<void> _refreshPeerPresence() async {
    final ids = await _resolveTargetIds();
    if (ids.isEmpty) return;
    await _presence.loadFor(ids);
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
                          // Slice 10.1.9 — interleave the call log into
                          // the message timeline so call history shows
                          // inline (Telegram-style). Calls live in a
                          // separate table (`chat_call_log`), so we
                          // watch them on the side and merge by time.
                          return StreamBuilder<List<ChatCallLog>>(
                            stream: context.read<CallLogRepository>()
                                .watchAll(),
                            builder: (context, callSnap) {
                              final allCalls = callSnap.data;
                              final calls = (allCalls ?? const <ChatCallLog>[])
                                  .where((c) =>
                                      c.conversationId ==
                                      widget.conversationId)
                                  .toList(growable: false);
                              // Re-scroll whenever the combined item
                              // count grows so a new call entry pushes
                              // the view to the bottom the same way a
                              // new message does.
                              final combinedCount =
                                  messages.length + calls.length;
                              if (combinedCount != _lastMessageCount) {
                                final firstFrame = _lastMessageCount == -1;
                                _lastMessageCount = combinedCount;
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
                                      duration: const Duration(
                                          milliseconds: 220),
                                      curve: Curves.easeOut,
                                    );
                                  }
                                });
                              }
                              return _MessageList(
                                messages: messages,
                                callLogs: calls,
                                conversation: conv,
                                currentUserId: _currentUserId,
                                scrollController: _scrollCtrl,
                                highlightId: _highlightId,
                                playingVoiceId: _playingVoiceId,
                                voiceProgress: _voiceProgress,
                                voicePaused: _voicePaused,
                                typingShown: _typingShown,
                                onLongPressBubble: _showContextMenu,
                                onReact: _toggleReaction,
                                onJumpToReply: _jumpTo,
                                onTapVoice: _toggleVoice,
                                onTapImage: _openImageViewer,
                                onTapCall: _redialCall,
                              );
                            },
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
                  // Slice 10.1.9 — user-set photo wins for both groups
                  // and direct convs, matching the inbox tile (Slice
                  // 10.3.5) and call hero (Slice 10.2.11). Without
                  // this the AppBar kept rendering the participant
                  // cluster for groups even after the admin uploaded
                  // a photo (Slice 10.3.6 sync).
                  if (conv.isGroup &&
                      (conv.avatarFilePath ?? '').isEmpty &&
                      (conv.displayAvatarUrl ?? '').isEmpty)
                    GroupAvatarCluster(
                      previews: conv.participantPreviews,
                      size: 36,
                    )
                  else
                    ChatAvatar(
                      name: conv.name,
                      size: 36,
                      avatarFilePath: conv.avatarFilePath,
                      // Server-side photo (peer profile / group upload);
                      // local pick still wins inside ChatAvatar.
                      avatarUrl: conv.displayAvatarUrl,
                      // For direct convs feed `userId` so the dot
                      // tracks live `/topic/presence` updates from
                      // PresenceRepository. Groups don't show a dot.
                      userId: conv.isGroup
                          ? null
                          : conv.participantPreviews.isNotEmpty
                              ? conv.participantPreviews.first.employeeId
                              : null,
                      showStatus: !conv.isGroup,
                    ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppLabel(
                          text: conv.name,
                          fontSize: AppFontSize.value16,
                          fontWeight: FontWeight.w800,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        // Direct subtitle is presence-driven; rebuild
                        // on every PresenceRepository tick so a peer
                        // going from Online → Busy → Offline updates
                        // live without us re-opening the page.
                        AnimatedBuilder(
                          animation:
                              context.read<PresenceRepository>().revision,
                          builder: (_, __) => AppLabel(
                            text: _subtitleFor(conv),
                            fontSize: 11.5,
                            color: theme.colorScheme.onSurfaceVariant,
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
          onPressed: () => _startCall(isVideo: false),
        ),
        IconButton(
          tooltip: 'Video call',
          icon: const Icon(Icons.videocam_rounded),
          onPressed: () => _startCall(isVideo: true),
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
      // For groups, derive the online count live from the presence
      // cache rather than the (possibly stale) ConversationDto field.
      final repo = context.read<PresenceRepository>();
      final onlineNow = c.participantPreviews
          .where((p) =>
              repo.statusOf(p.employeeId).status == PresenceStatus.online)
          .length;
      return '${c.totalMembers} members · $onlineNow online';
    }
    // Direct conv — read live status of the other person.
    if (c.participantPreviews.isEmpty) return 'Offline';
    final otherId = c.participantPreviews.first.employeeId;
    final p = context.read<PresenceRepository>().statusOf(otherId);
    // `effectiveStatus` promotes a fresh-OFFLINE (last-seen < 5 min)
    // to AWAY so peers who just minimised the app show as "Away"
    // instead of jumping straight to a last-seen timestamp.
    switch (p.effectiveStatus) {
      case PresenceStatus.online:
        return 'Online';
      case PresenceStatus.busy:
        return 'In a call';
      case PresenceStatus.away:
        return p.lastSeenAt != null
            ? 'Away · last seen ${_relativeTime(p.lastSeenAt!)}'
            : 'Away';
      case PresenceStatus.offline:
        return p.lastSeenAt != null
            ? 'Last seen ${_relativeTime(p.lastSeenAt!)}'
            : 'Offline';
    }
  }

  /// Lightweight "X ago" formatter — keeps us off the `timeago` dep
  /// for the one place we need a relative timestamp.
  String _relativeTime(DateTime when) {
    final diff = DateTime.now().difference(when);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) {
      final m = diff.inMinutes;
      return '$m minute${m == 1 ? '' : 's'} ago';
    }
    if (diff.inHours < 24) {
      final h = diff.inHours;
      return '$h hour${h == 1 ? '' : 's'} ago';
    }
    final d = diff.inDays;
    if (d < 7) return '$d day${d == 1 ? '' : 's'} ago';
    return DateFormat('d MMM').format(when);
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
      // Upload to the backend FIRST and send the HOSTED url — otherwise the
      // peer receives our local device path (e.g. /data/.../img.jpg), which
      // doesn't exist on their phone, so the image never shows for them.
      // Falls back to the local path only if the upload fails (sender-only
      // preview) so the send still goes through.
      final hostedUrl =
          await _msgRepo.uploadAttachment(picked.path, fileName: picked.name);
      if (!mounted) return;
      if (hostedUrl == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Image upload failed — the recipient may not see this photo.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      await _msgRepo.send(
        ChatMessage(
          id: '',
          conversationId: widget.conversationId,
          senderId: _currentUserId,
          senderName: _currentUserName,
          type: ChatMessageType.image,
          fileUrl: hostedUrl ?? picked.path,
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

  /// Tap handler on a voice bubble. Tapping the currently-playing clip stops
  /// it; tapping any other starts playback (which then auto-advances through
  /// the sender's run — see [_onVoiceComplete]).
  Future<void> _toggleVoice(String messageId) async {
    // Same clip → pause / resume, KEEPING the position (don't restart). So
    // playing to 3s then tapping pauses at 3s (play icon shows); tapping again
    // resumes from 3s to the end.
    if (_playingVoiceId == messageId) {
      if (_voicePaused) {
        if (mounted) setState(() => _voicePaused = false);
        await _voicePlayer.play(); // resumes from the held position
      } else {
        await _voicePlayer.pause();
        if (mounted) setState(() => _voicePaused = true);
      }
      return;
    }
    await _startVoice(messageId, auto: false);
  }

  /// Stop tracking playback position and clear the waveform fill / paused flag.
  void _resetVoiceProgress() {
    _voicePosSub?.cancel();
    _voicePosSub = null;
    _voiceProgress.value = 0;
    _voicePaused = false;
  }

  /// Load + play the voice [messageId]. [auto] true means this is an
  /// auto-advance from a previous clip finishing (so we stay silent on demo /
  /// error cases instead of nagging the user with a snackbar).
  Future<void> _startVoice(String messageId, {required bool auto}) async {
    final msg = await _msgRepo.findById(messageId);
    final url = msg?.voiceUrl ?? '';
    // Demo seed clips (and empty urls) have no real audio to play.
    if (url.isEmpty || url.startsWith('demo://')) {
      if (!mounted) return;
      if (!auto) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This voice clip is a demo placeholder — no audio.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      _resetVoiceProgress();
      setState(() => _playingVoiceId = null);
      return;
    }
    try {
      await _voicePlayer.stop();
      // When this clip finishes, try to auto-advance to the next one in the
      // same sender's run. Capture [messageId] so the handler knows which
      // clip just ended.
      _voicePlayerSub?.cancel();
      _voicePlayerSub = _voicePlayer.playerStateStream.listen((s) {
        if (s.processingState == ProcessingState.completed) {
          _onVoiceComplete(messageId);
        }
      });
      final isNetwork = url.startsWith('http://') || url.startsWith('https://');
      final loaded = isNetwork
          ? await _voicePlayer.setUrl(url)
          : await _voicePlayer.setFilePath(url); // locally-recorded
      if (!mounted) return;
      // Drive the waveform fill from real playback position.
      _voiceTotal =
          loaded ?? Duration(seconds: msg?.voiceDurationSeconds ?? 0);
      _voiceProgress.value = 0;
      _voicePosSub?.cancel();
      _voicePosSub = _voicePlayer.positionStream.listen((pos) {
        final t = _voiceTotal.inMilliseconds;
        _voiceProgress.value =
            t > 0 ? (pos.inMilliseconds / t).clamp(0.0, 1.0) : 0.0;
      });
      setState(() {
        _playingVoiceId = messageId;
        _voicePaused = false;
      });
      await _voicePlayer.play();
    } catch (e) {
      if (!mounted) return;
      _resetVoiceProgress();
      setState(() => _playingVoiceId = null);
      if (!auto) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not play voice message: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// A clip finished — auto-play the NEXT voice in the SAME sender's run
  /// (Telegram-style). Stops as soon as a message from a different person
  /// appears, so:
  ///   • A sends 2–3 voices in a row → they play through automatically.
  ///   • A sends one, then the listener (or anyone else) replies → the run
  ///     ends and we do NOT auto-play that reply.
  Future<void> _onVoiceComplete(String finishedId) async {
    // `completed` can fire more than once for the same clip — ignore the
    // duplicates so we don't skip the next one in the run.
    if (_playingVoiceId != finishedId) return;
    // Detach this clip's listener right away so a repeated `completed`
    // (or one arriving during the await below) can't double-advance.
    // _startVoice re-attaches a fresh listener for the next clip.
    _voicePlayerSub?.cancel();
    _voicePlayerSub = null;
    final nextId = await _nextRunVoiceId(finishedId);
    if (!mounted) return;
    if (nextId == null) {
      _resetVoiceProgress();
      setState(() => _playingVoiceId = null);
      return;
    }
    await _startVoice(nextId, auto: true);
  }

  /// The next playable voice message that belongs to the same uninterrupted
  /// run as [finishedId] — i.e. the next voice from the SAME sender with no
  /// message from anyone else in between. Returns null when the run ends.
  Future<String?> _nextRunVoiceId(String finishedId) async {
    final msgs = await _msgRepo.getForConversation(widget.conversationId);
    // `getForConversation` is ascending by sentAt (oldest → newest).
    final idx = msgs.indexWhere((m) => m.id == finishedId);
    if (idx < 0) return null;
    final senderId = msgs[idx].senderId;
    for (var i = idx + 1; i < msgs.length; i++) {
      final m = msgs[i];
      // Anyone else sending anything (text or voice) breaks the run.
      if (m.senderId != senderId) return null;
      if (m.type != ChatMessageType.voice || m.isDeleted) continue;
      final url = m.voiceUrl ?? '';
      if (url.isEmpty || url.startsWith('demo://')) return null;
      return m.id;
    }
    return null;
  }

  /// Slice 10.1.9 — tap on an inline call entry re-opens the matching
  /// voice/video call page, same as the Calls tab / Chat Info call
  /// history shortcut.
  void _redialCall(ChatCallLog log) {
    if (log.callType == ChatCallType.video) {
      ConfigRouter.pushPageAnimation(
        context,
        VideoCallPage(conversationId: widget.conversationId),
      );
    } else {
      ConfigRouter.pushPageAnimation(
        context,
        VoiceCallPage(conversationId: widget.conversationId),
      );
    }
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

  /// Ask for the microphone BEFORE recording a voice message — on both iOS
  /// and Android. Returns true only when granted. On denial we surface a
  /// hint; if the user permanently denied it, the snackbar offers a shortcut
  /// to the OS Settings (the only place it can be re-enabled).
  Future<bool> _ensureMicPermission() async {
    var status = await Permission.microphone.status;
    if (status.isGranted) return true;
    // Not yet granted — trigger the native system prompt (covers "denied",
    // "restricted" and the never-asked first-run state on both platforms).
    if (!status.isPermanentlyDenied) {
      status = await Permission.microphone.request();
    }
    if (status.isGranted) return true;
    if (!mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
            'Microphone permission is needed to record a voice message.'),
        behavior: SnackBarBehavior.floating,
        action: status.isPermanentlyDenied
            ? SnackBarAction(label: 'Settings', onPressed: openAppSettings)
            : null,
      ),
    );
    return false;
  }

  Future<void> _showVoiceRecording() async {
    // Gate the recorder on the mic permission (iOS + Android). No prompt was
    // shown before, so a fresh install could "record" without ever asking.
    if (!await _ensureMicPermission()) return;
    if (!mounted) return;
    // Open the recorder sheet — it records to a temp .m4a and returns the
    // file path + duration on Send (null on Cancel / dismiss).
    final result = await showModalBottomSheet<_VoiceRecording>(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: false,
      builder: (_) => const _VoiceRecorderSheet(),
    );
    if (result == null || !mounted) return;
    final now = DateTime.now();
    final targetIds = await _resolveTargetIds();
    // Upload the clip so peers hear the SAME hosted file (a local path is
    // invisible on their device). Falls back to the local path on failure
    // (sender-only playback) so the send still goes through.
    final hostedUrl = await _msgRepo.uploadAttachment(
      result.path,
      fileName: 'voice_${now.millisecondsSinceEpoch}.m4a',
    );
    if (!mounted) return;
    if (hostedUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Voice upload failed — the recipient may not hear this clip.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    await _msgRepo.send(
      ChatMessage(
        id: '',
        conversationId: widget.conversationId,
        senderId: _currentUserId,
        senderName: _currentUserName,
        type: ChatMessageType.voice,
        voiceUrl: hostedUrl ?? result.path,
        voiceDurationSeconds: result.durationSeconds,
        sentAt: now,
      ),
      targetIds: targetIds,
    );
    // Body is raw preview — inbox prefixes "You: ".
    await _convRepo.updateLastMessage(
      id: widget.conversationId,
      body: '🎤 Voice message · ${_fmtVoiceDuration(result.durationSeconds)}',
      senderId: _currentUserId,
      senderName: _currentUserName,
      type: 'voice',
      at: now,
    );
  }

  static String _fmtVoiceDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

/// Result handed back by [_VoiceRecorderSheet] when the user taps Send.
class _VoiceRecording {
  const _VoiceRecording({required this.path, required this.durationSeconds});
  final String path;
  final int durationSeconds;
}

/// Modal sheet that records a voice message to a temp `.m4a` while open.
/// Pops with a [_VoiceRecording] on Send, or `null` on Cancel / dismiss
/// (discarding the file). Recording starts the instant it mounts — the mic
/// permission is already granted by the caller ([_showVoiceRecording]).
class _VoiceRecorderSheet extends StatefulWidget {
  const _VoiceRecorderSheet();

  @override
  State<_VoiceRecorderSheet> createState() => _VoiceRecorderSheetState();
}

class _VoiceRecorderSheetState extends State<_VoiceRecorderSheet> {
  final AudioRecorder _recorder = AudioRecorder();
  Timer? _ticker;
  Duration _elapsed = Duration.zero;
  String? _path;
  bool _ready = false;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );
      if (!mounted) {
        await _recorder.stop();
        return;
      }
      setState(() {
        _path = path;
        _ready = true;
      });
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _elapsed += const Duration(seconds: 1));
      });
    } catch (_) {
      if (mounted) Navigator.pop(context); // couldn't start — bail
    }
  }

  Future<void> _finish({required bool send}) async {
    if (_finishing) return;
    _finishing = true;
    _ticker?.cancel();
    String? path;
    try {
      path = await _recorder.stop();
    } catch (_) {}
    path ??= _path;
    if (!mounted) return;
    // Need at least ~1s of audio to count as a clip.
    if (send && path != null && _elapsed.inMilliseconds >= 1000) {
      Navigator.pop(
        context,
        _VoiceRecording(
          path: path,
          durationSeconds: _elapsed.inSeconds < 1 ? 1 : _elapsed.inSeconds,
        ),
      );
    } else {
      if (path != null) {
        try {
          File(path).deleteSync();
        } catch (_) {}
      }
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final m = _elapsed.inMinutes;
    final s = _elapsed.inSeconds % 60;
    final timeLabel = '$m:${s.toString().padLeft(2, '0')}';
    return Container(
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
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ).animate(onPlay: (c) => c.repeat()).fade(
                    begin: 0.3,
                    end: 1.0,
                    duration: 600.ms,
                  ),
              const SizedBox(width: 8),
              AppLabel(
                text: _ready ? 'Recording…' : 'Starting…',
                fontSize: AppFontSize.value14,
                fontWeight: FontWeight.w800,
              ),
              const Spacer(),
              AppLabel(
                text: timeLabel,
                fontSize: AppFontSize.value14,
                color: theme.colorScheme.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _finish(send: false),
                  icon: const Icon(Icons.close_rounded),
                  label: AppLabel(
                    text: 'Cancel',
                    fontSize: AppFontSize.value14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _ready ? () => _finish(send: true) : null,
                  icon: const Icon(Icons.send_rounded),
                  label: AppLabel(
                    text: 'Send',
                    fontSize: AppFontSize.value14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
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
      future: context.read<MessagesRepository>().findById(messageId),
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
                child: AppLabel(
                  text: m.body ?? '(pinned message)',
                  fontSize: AppFontSize.value12,
                  color: theme.colorScheme.onTertiaryContainer,
                  fontWeight: FontWeight.w700,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
    required this.callLogs,
    required this.conversation,
    required this.scrollController,
    required this.highlightId,
    required this.playingVoiceId,
    required this.voiceProgress,
    required this.voicePaused,
    required this.typingShown,
    required this.currentUserId,
    required this.onLongPressBubble,
    required this.onReact,
    required this.onJumpToReply,
    required this.onTapVoice,
    required this.onTapImage,
    required this.onTapCall,
  });

  final List<ChatMessage> messages;
  final List<ChatCallLog> callLogs;
  final ChatConversation conversation;
  final ScrollController scrollController;
  final String? highlightId;
  final String? playingVoiceId;
  final ValueListenable<double> voiceProgress;
  final bool voicePaused;
  final bool typingShown;
  final String currentUserId;
  final void Function(ChatMessage m) onLongPressBubble;
  final Future<void> Function(String messageId, String emoji) onReact;
  final void Function(String messageId) onJumpToReply;
  final void Function(String messageId) onTapVoice;
  final void Function(ChatMessage m) onTapImage;
  final void Function(ChatCallLog log) onTapCall;

  @override
  Widget build(BuildContext context) {
    // Slice 10.1.9 — merge messages + call log entries into a single
    // chronological stream, then weave in date separators. Call entries
    // use `startedAt` as their timeline timestamp.
    final entries = <_TimelineEntry>[];
    for (final m in messages) {
      entries.add(_TimelineEntry.message(m, m.sentAt));
    }
    for (final c in callLogs) {
      entries.add(_TimelineEntry.call(c, c.startedAt));
    }
    entries.sort((a, b) => a.at.compareTo(b.at));

    final items = <_ListItem>[];
    DateTime? lastDay;
    String? lastSenderId;
    DateTime? lastSentAt;
    for (final e in entries) {
      final day = DateTime(e.at.year, e.at.month, e.at.day);
      if (lastDay == null || !_isSameDay(lastDay, day)) {
        items.add(_ListItem.separator(day));
        // Force the next message's "showSender" so the header re-prints
        // after a day break, matching Telegram.
        lastSenderId = null;
      }
      if (e.message != null) {
        final m = e.message!;
        final groupBreak = lastSenderId != m.senderId ||
            (lastSentAt != null &&
                m.sentAt.difference(lastSentAt).inMinutes > 5);
        items.add(_ListItem.message(m, showSender: groupBreak));
        lastSenderId = m.senderId;
        lastSentAt = m.sentAt;
      } else {
        items.add(_ListItem.call(e.callLog!));
        // Call entries break the message-grouping streak so the next
        // bubble re-shows its sender header.
        lastSenderId = null;
        lastSentAt = null;
      }
      lastDay = day;
    }
    if (typingShown) {
      items.add(_ListItem.typing(conversation));
    }
    // Compute "expected readers" once per build: every conv member
    // except us. Drives the read-receipt tick logic in ChatBubble.
    final expectedReaderIds = <String>{
      for (final p in conversation.participantPreviews)
        if (p.employeeId != currentUserId) p.employeeId,
    };
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
              expectedReaderIds: expectedReaderIds,
              onLongPress: () => onLongPressBubble(item.message!),
              onReact: (e) => onReact(item.message!.id, e),
              onJumpToReply: onJumpToReply,
              onTapVoice: () => onTapVoice(item.message!.id),
              onTapImage: () => onTapImage(item.message!),
              // "Playing" (pause icon) only when actively playing — paused
              // shows the play/resume icon but keeps the filled waveform.
              isVoicePlaying:
                  playingVoiceId == item.message!.id && !voicePaused,
              voiceProgress:
                  playingVoiceId == item.message!.id ? voiceProgress : null,
              highlight: highlightId == item.message!.id,
            ),
          _ListItemKind.call => _CallEntryBubble(
              log: item.callLog!,
              isOwn: item.callLog!.callerId == currentUserId,
              onTap: () => onTapCall(item.callLog!),
            ),
          _ListItemKind.typing => TypingIndicator(
              label: '${_typingLabelFor(item.conversation!)} is typing…',
            ),
        };
      },
    );
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Safe display label for the typing indicator. Direct convs show
  /// the conv name (the other person); groups show the first
  /// participant's name, but guard the `.first` access — a freshly
  /// created group can have an empty `participantPreviews` list
  /// before the backend's refresh fills it in, which previously
  /// crashed with `Bad state: No element`.
  static String _typingLabelFor(ChatConversation c) {
    if (!c.isGroup) return c.name.isNotEmpty ? c.name : 'Someone';
    if (c.participantPreviews.isNotEmpty) {
      final first = c.participantPreviews.first.name;
      if (first.trim().isNotEmpty) return first;
    }
    return 'Someone';
  }
}

enum _ListItemKind { separator, message, call, typing }

class _ListItem {
  _ListItem._(this.kind,
      {this.day,
      this.message,
      this.callLog,
      this.showSender = false,
      this.conversation});
  final _ListItemKind kind;
  final DateTime? day;
  final ChatMessage? message;
  final ChatCallLog? callLog;
  final bool showSender;
  final ChatConversation? conversation;

  factory _ListItem.separator(DateTime day) =>
      _ListItem._(_ListItemKind.separator, day: day);
  factory _ListItem.message(ChatMessage m, {required bool showSender}) =>
      _ListItem._(_ListItemKind.message, message: m, showSender: showSender);
  factory _ListItem.call(ChatCallLog c) =>
      _ListItem._(_ListItemKind.call, callLog: c);
  factory _ListItem.typing(ChatConversation c) =>
      _ListItem._(_ListItemKind.typing, conversation: c);
}

/// Slice 10.1.9 — chronological entry shared by messages and call
/// log rows so the timeline merge stays a simple sort.
class _TimelineEntry {
  _TimelineEntry._(this.at, {this.message, this.callLog});
  final DateTime at;
  final ChatMessage? message;
  final ChatCallLog? callLog;

  factory _TimelineEntry.message(ChatMessage m, DateTime at) =>
      _TimelineEntry._(at, message: m);
  factory _TimelineEntry.call(ChatCallLog c, DateTime at) =>
      _TimelineEntry._(at, callLog: c);
}

/// Slice 10.1.9 — Telegram-style inline call-history row. Sits in the
/// message timeline at the call's `startedAt` and lets the user tap to
/// redial. Direction icon mirrors the per-conversation history shown
/// in Chat Info (Slice 10.2.5):
///   - missed / noAnswer → red `call_missed`
///   - own outgoing      → primary `call_made`
///   - incoming answered → success `call_received`
class _CallEntryBubble extends StatelessWidget {
  const _CallEntryBubble({
    required this.log,
    required this.isOwn,
    required this.onTap,
  });

  final ChatCallLog log;
  final bool isOwn;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final missed = log.status == ChatCallStatus.missed ||
        log.status == ChatCallStatus.noAnswer;
    final declined = log.status == ChatCallStatus.rejected;
    final accent = missed
        ? theme.colorScheme.error
        : (declined
            ? theme.colorScheme.error
            : (isOwn
                ? theme.colorScheme.primary
                : Colors.green.shade600));
    final iconData = missed
        ? Icons.call_missed_rounded
        : (isOwn
            ? Icons.call_made_rounded
            : Icons.call_received_rounded);
    final isVideo = log.callType == ChatCallType.video;
    String title;
    if (missed) {
      title = isVideo ? 'Missed video call' : 'Missed voice call';
    } else if (declined) {
      title = isVideo ? 'Declined video call' : 'Declined voice call';
    } else {
      title = isVideo ? 'Video call' : 'Voice call';
    }
    final subtitle = log.durationSeconds > 0
        ? log.formattedDuration()
        : _stamp(log.startedAt);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Align(
        alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
        child: Material(
          color: theme.colorScheme.surface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(AppRadii.lg),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(iconData, color: accent, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppLabel(
                        text: title,
                        fontSize: AppFontSize.value14,
                        color: missed || declined
                            ? theme.colorScheme.error
                            : theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                      const SizedBox(height: 2),
                      AppLabel(
                        text: subtitle,
                        fontSize: AppFontSize.value12,
                        color: theme.colorScheme.onSurfaceVariant,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Icon(
                    isVideo
                        ? Icons.videocam_rounded
                        : Icons.call_rounded,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _stamp(DateTime when) {
    final hh = when.hour.toString().padLeft(2, '0');
    final mm = when.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}

class _ReplyPreviewBar extends StatelessWidget {
  const _ReplyPreviewBar({required this.messageId, required this.onClose});
  final String messageId;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<ChatMessage?>(
      future: context.read<MessagesRepository>().findById(messageId),
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
                    AppLabel(
                      text: 'Replying to ${m?.senderName ?? '…'}',
                      fontSize: AppFontSize.value12,
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                    AppLabel(
                      text: m?.body ?? '',
                      fontSize: AppFontSize.value12,
                      color: theme.colorScheme.onSurfaceVariant,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
          AppLabel(
            text: 'Editing message',
            fontSize: AppFontSize.value12,
            color: theme.colorScheme.onTertiaryContainer,
            fontWeight: FontWeight.w800,
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
              child: AppLabel(text: e, fontSize: AppFontSize.value24),
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
      title: AppLabel(
        text: label,
        fontSize: AppFontSize.value14,
        color: fg,
        fontWeight: FontWeight.w700,
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
          AppLabel(
            text: label,
            fontSize: AppFontSize.value12,
            fontWeight: FontWeight.w700,
          ),
        ],
      ),
    );
  }
}
