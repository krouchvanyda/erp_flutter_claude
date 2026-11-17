import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:erp_mobile/core/di/service_locator.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:get/get.dart' show Trans;

import '../../../core/router/config_router.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_font_size.dart';
import '../../../core/theme/app_label.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/widgets/dynamic_app_bar.dart';
import '../../../core/widgets/dynamic_status_bar.dart';
import '../../../shared/widgets/app_background_gradient.dart';
import '../repositories/chat_settings.dart';
import '../repositories/users_cache.dart';
import '../repositories/call_log_repository.dart';
import '../repositories/conversations_repository.dart';
import '../repositories/presence_repository.dart';
import '../models/call_log.dart';
import '../models/conversation.dart';
import '../widgets/chat_avatar.dart';
import '../widgets/chat_notification_router.dart';
import 'chat_conversation_page.dart';
import 'new_conversation_page.dart';
import 'video_call_page.dart';
import 'voice_call_page.dart';

/// Slice 10.1.1 — Chat Inbox.
///
/// Conversation list with All / Unread / Groups tabs, online dots,
/// unread badges, and swipe actions (mute / delete). Tapping a row
/// opens the chat conversation page.
class ChatInboxPage extends StatefulWidget {
  const ChatInboxPage({super.key});

  @override
  State<ChatInboxPage> createState() => _ChatInboxPageState();
}

class _ChatInboxPageState extends State<ChatInboxPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    // Refresh presence whenever the inbox opens. The `/topic/presence`
    // snapshot can be stale — a peer who came online AFTER our last
    // loadAll may not have delivered an ONLINE delta to us, leaving
    // their dot offline forever. Re-pulling the full snapshot here (the
    // same call used on boot/foreground) corrects every tile's dot at
    // once the moment the user lands on the inbox.
    unawaited(context.read<PresenceRepository>().loadAll());
    // A chat-notification tap that arrived before the inbox existed
    // (cold start / still on login) is opened now that the router has
    // settled on the signed-in screen.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => ChatNotificationRouter.inboxReady());
  }

  @override
  void dispose() {
    ChatNotificationRouter.inboxDisposed();
    _tabs.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<ChatConversation> _filter(List<ChatConversation> all, int tabIndex) {
    final q = _query.trim().toLowerCase();
    Iterable<ChatConversation> result = all;
    if (tabIndex == 1) {
      result = result.where((c) => c.unreadCount > 0);
    } else if (tabIndex == 2) {
      result = result.where((c) => c.isGroup);
    }
    if (q.isNotEmpty) {
      result = result.where((c) =>
          c.name.toLowerCase().contains(q) ||
          (c.lastMessageBody ?? '').toLowerCase().contains(q));
    }
    // Dedup by id, keeping the first occurrence (order preserved). Two
    // conversations with the same id would give their per-tile
    // `Dismissible`s the same `ValueKey(conversation.id)`, which trips
    // RenderSliverMultiBoxAdaptor's child-order assertion
    // (`indexOf(child) > index`) and crashes the whole list. The real-
    // time sync paths (group propagation 10.1.7, implicit direct-conv
    // creation 10.1.8) can momentarily surface the same id twice; this
    // is the render-boundary guard against that.
    final seen = <String>{};
    return result.where((c) => seen.add(c.id)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<ConversationsRepository>();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: DynamicAppBar(
        title: 'chatInboxTitle'.tr,
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'chatNewMessage'.tr,
            icon: const Icon(Icons.edit_note_rounded),
            onPressed: () => ConfigRouter.pushPageAnimation(
              context,
              const NewConversationPage(),
            ),
          ),
          // Settings lives here now that the bottom nav is gone.
          // pushNamed (not goNamed) keeps Chat underneath so back
          // returns to the inbox.
          IconButton(
            tooltip: 'chatSettingsTooltip'.tr,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.pushNamed(RoutePaths.settingsName),
          ),
        ],
      ),
      body: DynamicStatusBar(
        child: Stack(
          children: [
            const AppBackgroundGradient(),
            StreamBuilder<List<ChatConversation>>(
              stream: repo.watchAll(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final all = snap.data!;
                return Column(
                  children: [
                    SizedBox(height: context.dynamicAppBarPadding),
                    _SearchField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _query = v),
                    ),
                    _Tabs(controller: _tabs),
                    Expanded(
                      child: TabBarView(
                        controller: _tabs,
                        children: [
                          _List(items: _filter(all, 0)),
                          _List(items: _filter(all, 1)),
                          _List(items: _filter(all, 2)),
                          // Slice 10.2.5 — global recent calls.
                          const _RecentCallsList(),
                        ],
                      ),
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
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      decoration: BoxDecoration(
        // Use a slightly elevated surface tier — pops above the page
        // gradient in both light and dark mode (plain `surface` blends
        // into the gradient's middle stop in light mode).
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(
            alpha: isLight ? 0.5 : 0.3,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isLight ? 0.06 : 0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
        decoration: InputDecoration(
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 14, right: 8),
            child: Icon(
              Icons.search_rounded,
              color: theme.colorScheme.primary,
              size: 22,
            ),
          ),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 0, minHeight: 0),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, value, __) {
              if (value.text.isEmpty) return const SizedBox(width: 12);
              return IconButton(
                splashRadius: 18,
                padding: const EdgeInsets.only(right: 8),
                icon: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              );
            },
          ),
          hintText: 'chatSearchConversations'.tr,
          hintStyle: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            fontWeight: FontWeight.w500,
          ),
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          isCollapsed: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.controller});
  final TabController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: TabBar(
        controller: controller,
        labelColor: theme.colorScheme.onPrimary,
        unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
        labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
        unselectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        dividerColor: Colors.transparent,
        splashBorderRadius: BorderRadius.circular(AppRadii.pill),
        tabs: [
          Tab(text: 'chatTabAll'.tr),
          Tab(text: 'chatTabUnread'.tr),
          Tab(text: 'chatTabGroups'.tr),
          Tab(text: 'chatTabCalls'.tr),
        ],
      ),
    );
  }
}

class _List extends StatelessWidget {
  const _List({required this.items});
  final List<ChatConversation> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _EmptyState();
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 96),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (_, i) {
        return _Tile(conversation: items[i])
            .animate()
            .fadeIn(delay: (i * 40).clamp(0, 240).ms)
            .slideY(begin: 0.04, end: 0, duration: 280.ms);
      },
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.conversation});
  final ChatConversation conversation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final repo = context.read<ConversationsRepository>();
    final hasUnread = conversation.unreadCount > 0;
    return Dismissible(
      key: ValueKey(conversation.id),
      background: Container(
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          children: [
            Icon(
              conversation.isMuted
                  ? Icons.notifications_active_outlined
                  : Icons.notifications_off_outlined,
              color: Colors.blue.shade700,
            ),
            const SizedBox(width: 8),
            AppLabel(
              text: conversation.isMuted ? 'chatUnmute'.tr : 'chatMute'.tr,
              fontSize: AppFontSize.value14,
              color: Colors.blue.shade700,
              fontWeight: FontWeight.w800,
            ),
          ],
        ),
      ),
      secondaryBackground: Container(
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            AppLabel(
              text: 'chatDelete'.tr,
              fontSize: AppFontSize.value14,
              color: Colors.red.shade700,
              fontWeight: FontWeight.w800,
            ),
            const SizedBox(width: 8),
            Icon(Icons.delete_outline, color: Colors.red.shade700),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          await repo.setMuted(conversation.id, !conversation.isMuted);
          return false; // never actually dismiss
        }
        return await showDialog<bool>(
              context: context,
              builder: (dCtx) => AlertDialog(
                title: AppLabel(
                  text: 'chatDeleteConversationTitle'.tr,
                  fontSize: AppFontSize.value18,
                  fontWeight: FontWeight.w800,
                ),
                content: AppLabel(
                  text: 'chatDeleteConversationBody'.trParams({'name': conversation.name}),
                  fontSize: AppFontSize.value14,
                  maxLines: 4,
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dCtx, false),
                    child: AppLabel(
                      text: 'commonCancelAction'.tr,
                      fontSize: AppFontSize.value14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.error,
                    ),
                    onPressed: () => Navigator.pop(dCtx, true),
                    child: AppLabel(
                      text: 'chatDelete'.tr,
                      fontSize: AppFontSize.value14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) {
        // Hit the backend so the conversation actually goes away —
        // not just locally. For groups the server enforces admin-only
        // (returns 403); for direct convs either party may delete.
        // The Dismissible animation has already torn the local row
        // out, so on failure we reconcile via loadInbox so the tile
        // pops back in, and surface a snackbar explaining why.
        unawaited(repo.deleteRemote(conversation.id).catchError((Object e) {
          if (!context.mounted) return;
          final msg = e is DioException && e.response?.statusCode == 403
              ? 'chatDeleteGroupAdminOnly'.tr
              : 'chatDeleteConversationFailed'.tr;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              behavior: SnackBarBehavior.floating,
            ),
          );
          // Re-fetch the inbox so the row the Dismissible removed
          // reappears — the server still has it.
          unawaited(repo.loadInbox());
        }));
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          onTap: () async {
            await context.read<ConversationsRepository>().markRead(conversation.id);
            if (!context.mounted) return;
            await ConfigRouter.pushPageAnimation(
              context,
              ChatConversationPage(conversationId: conversation.id),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(AppRadii.lg),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                // Slice 10.3.5 — user-set photo wins for both groups
                // and direct convs. Groups fall back to the 3-avatar
                // cluster; direct convs fall back to the initials
                // gradient (handled inside ChatAvatar). A server-side
                // `avatarUrl` also counts as a photo, so a group with
                // an uploaded photo (no local file) renders it too.
                if (conversation.isGroup &&
                    (conversation.avatarFilePath ?? '').isEmpty &&
                    (conversation.displayAvatarUrl ?? '').isEmpty)
                  GroupAvatarCluster(
                    previews: conversation.participantPreviews,
                    size: 52,
                  )
                else
                  ChatAvatar(
                    name: conversation.name,
                    size: 52,
                    avatarFilePath: conversation.avatarFilePath,
                    // Server-side photo — peer's profile avatar for
                    // direct convs, uploaded group photo otherwise.
                    // A local pick still wins inside ChatAvatar.
                    avatarUrl: conversation.displayAvatarUrl,
                    // For direct convs feed the other person's id so
                    // the dot tracks live presence from
                    // PresenceRepository (rebuilds on every
                    // `/topic/presence` STOMP frame). Groups don't
                    // show a dot.
                    userId: conversation.isGroup
                        ? null
                        : conversation.participantPreviews.isNotEmpty
                            ? conversation
                                .participantPreviews.first.employeeId
                            : null,
                    showStatus: !conversation.isGroup,
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: AppLabel(
                              text: conversation.name,
                              fontSize: AppFontSize.value16,
                              fontWeight: hasUnread
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Direct conv: live "· Away" / "· In a call"
                          // pill that ticks on every PresenceRepository
                          // revision. Group convs skip it (their
                          // online-count belongs in the chat header).
                          if (!conversation.isGroup &&
                              conversation.participantPreviews.isNotEmpty)
                            _PresenceInline(
                              userId: conversation
                                  .participantPreviews.first.employeeId,
                            ),
                          const Spacer(),
                          const SizedBox(width: 8),
                          if (conversation.isMuted)
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Icon(
                                Icons.notifications_off_outlined,
                                size: 14,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          if (conversation.lastMessageAt != null)
                            AppLabel(
                              text: _formatStamp(conversation.lastMessageAt!),
                              fontSize: AppFontSize.value11,
                              color: hasUnread
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant,
                              fontWeight: hasUnread
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Expanded(
                            child: AppLabel(
                              text: _previewFor(conversation),
                              fontSize: AppFontSize.value12,
                              color: hasUnread
                                  ? theme.colorScheme.onSurface
                                  : theme.colorScheme.onSurfaceVariant,
                              fontWeight: hasUnread
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (hasUnread) ...[
                            const SizedBox(width: 8),
                            _UnreadBadge(count: conversation.unreadCount),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Inbox tile preview composed from the conversation's `lastMessage`
  /// payload. Mirrors the backend spec:
  ///   text   → "You: hi" / "hi"
  ///   image  → "You: 📷 Photo" / "📷 Photo"
  ///   voice  → "You: 🎤 Voice · 0:05" / "🎤 Voice · 0:05"
  ///   file   → "You: 📎 File" / "📎 File"
  ///   deleted → "Message deleted"
  ///   no last message → "No message yet"  (brand-new conv)
  ///
  /// Single "You:" prefix is enforced here so callers must NEVER also
  /// prepend "You:" to the lastMessageBody they save into the conv —
  /// otherwise tiles would render "You: You: hi".
  static String _previewFor(ChatConversation c) {
    // A truly empty conv has no lastMessageAt — use that as the
    // canonical "no messages ever" signal so we don't accidentally
    // hit this branch for a deleted-only message or a voice/image
    // with empty body.
    if (c.lastMessageAt == null) return 'chatNoMessageYet'.tr;
    final body = c.lastMessageBody;
    if (body == null && c.lastMessageType == 'text') return 'chatNoMessageYet'.tr;

    // Heuristic for soft-delete: backend sends body "Message deleted"
    // OR no body with type=text. The conv doesn't currently carry a
    // separate `deleted` flag on its last-message snapshot — if/when
    // it does, swap to that.
    if (body == 'Message deleted') return 'chatMessageDeleted'.tr;

    // Sender prefix:
    //   * own message       → "You: ..."
    //   * group / other     → "<FirstName>: ..." so members can tell
    //                          who said what without opening the chat
    //   * direct / other    → no prefix (tile title is already the
    //                          other person's name)
    final me = GetIt.I<ChatSettings>().userId;
    final isOwn = c.lastMessageSenderId == me;
    String prefix = '';
    if (isOwn) {
      prefix = 'chatPreviewYouPrefix'.tr;
    } else if (c.isGroup) {
      final senderName = (c.lastMessageSenderName ?? '').trim();
      if (senderName.isNotEmpty) {
        // First word only so a long full-name doesn't crowd out the
        // body on narrow tiles.
        final first = senderName.split(RegExp(r'\s+')).first;
        prefix = '$first: ';
      }
    }
    final type = c.lastMessageType;
    if (type == 'image') return '$prefix${'chatPreviewPhoto'.tr}';
    if (type == 'file') return '$prefix${'chatPreviewFile'.tr}';
    if (type == 'voice') {
      // We don't carry duration on the conv snapshot today; fall back
      // to a label without timing. Real duration shows in the bubble.
      return '$prefix${'chatPreviewVoice'.tr}';
    }
    return '$prefix${body ?? ''}';
  }

  static String _formatStamp(DateTime when) {
    final now = DateTime.now();
    final whenDay = DateTime(when.year, when.month, when.day);
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(whenDay).inDays;
    if (diff == 0) return DateFormat('HH:mm').format(when);
    if (diff == 1) return 'chatYesterday'.tr;
    if (diff < 7) return DateFormat('EEE').format(when);
    return DateFormat('d MMM').format(when);
  }
}

/// Tiny inline presence pill rendered next to the conversation name
/// on direct-conv inbox tiles. Reads from [PresenceRepository] and
/// rebuilds on every revision tick so the label flips live as peers
/// go Online / Busy / Away. Renders nothing for online + offline so
/// the tile stays clean — the avatar dot already conveys those.
class _PresenceInline extends StatelessWidget {
  const _PresenceInline({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final repo = context.read<PresenceRepository>();
    return AnimatedBuilder(
      animation: repo.revision,
      builder: (_, __) {
        final p = repo.statusOf(userId);
        final (String? label, Color color) = switch (p.effectiveStatus) {
          PresenceStatus.online => (null, Colors.transparent),
          PresenceStatus.busy => ('chatPresenceInCall'.tr, const Color(0xFFE2A03F)),
          PresenceStatus.away => ('chatPresenceAway'.tr, const Color(0xFFE2A03F)),
          PresenceStatus.offline => (null, Colors.transparent),
        };
        if (label == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(left: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppLabel(
                text: '· ',
                fontSize: AppFontSize.value12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              AppLabel(
                text: label,
                fontSize: AppFontSize.value11,
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      alignment: Alignment.center,
      child: AppLabel(
        text: count > 99 ? '99+' : '$count',
        fontSize: AppFontSize.value11,
        color: theme.colorScheme.onPrimary,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.chat_bubble_outline_rounded,
                size: 36,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            AppLabel(
              text: 'chatEmptyConversationsTitle'.tr,
              fontSize: AppFontSize.value16,
              fontWeight: FontWeight.w800,
            ),
            const SizedBox(height: 6),
            AppLabel(
              text: 'chatEmptyConversationsBody'.tr,
              fontSize: AppFontSize.value12,
              color: theme.colorScheme.onSurfaceVariant,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}


// ── Slice 10.2.5 — Recent Calls tab ─────────────────────────────
//
// 4th tab on the inbox. Lists every entry from `chat_call_log`,
// newest first, with direction + missed icons and a tap target that
// re-opens the matching voice/video call page.

class _RecentCallsList extends StatelessWidget {
  const _RecentCallsList();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ChatCallLog>>(
      stream: context.read<CallLogRepository>().watchAll(),
      builder: (context, snap) {
        final logs = snap.data ?? const <ChatCallLog>[];
        if (logs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.call_outlined,
                    size: 36,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 12),
                  AppLabel(
                    text: 'chatEmptyCallsTitle'.tr,
                    fontSize: AppFontSize.value16,
                    fontWeight: FontWeight.w800,
                  ),
                  const SizedBox(height: 6),
                  AppLabel(
                    text: 'chatEmptyCallsBody'.tr,
                    fontSize: AppFontSize.value12,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
          itemCount: logs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 4),
          itemBuilder: (_, i) {
            return _RecentCallTile(log: logs[i])
                .animate()
                .fadeIn(delay: (i * 40).clamp(0, 240).ms)
                .slideY(begin: 0.04, end: 0, duration: 280.ms);
          },
        );
      },
    );
  }
}

class _RecentCallTile extends StatelessWidget {
  const _RecentCallTile({required this.log});
  final ChatCallLog log;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final me = context.read<ChatSettings>().userId;
    final isOutgoing = log.callerId == me;
    final isMissed = log.status == ChatCallStatus.missed ||
        log.status == ChatCallStatus.noAnswer ||
        (log.status == ChatCallStatus.rejected && !isOutgoing);
    final isVideo = log.callType == ChatCallType.video;
    final accent = isMissed
        ? theme.colorScheme.error
        : (isOutgoing ? Colors.blue.shade700 : Colors.green.shade700);
    // For now we surface the caller's display name; once participant
    // metadata is on the log row we'd flip to "the other party".
    final peerName = isOutgoing ? log.callerName : log.callerName;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        onTap: () => ConfigRouter.pushPageAnimation(
          context,
          isVideo
              ? VideoCallPage(conversationId: log.conversationId)
              : VoiceCallPage(conversationId: log.conversationId),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  ChatAvatar(
                    name: peerName,
                    size: 44,
                    // Matches the displayed caller name above; resolves
                    // their profile photo from the directory cache.
                    avatarUrl: UsersCache.instance.avatarOf(log.callerId),
                    showStatus: false,
                  ),
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.colorScheme.surface,
                        width: 2,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      isVideo ? Icons.videocam : Icons.call,
                      size: 9,
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppLabel(
                      text: peerName,
                      fontSize: AppFontSize.value16,
                      fontWeight: FontWeight.w700,
                      color: isMissed ? theme.colorScheme.error : null,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          isMissed
                              ? Icons.call_missed_rounded
                              : (isOutgoing
                                  ? Icons.call_made_rounded
                                  : Icons.call_received_rounded),
                          size: 13,
                          color: accent,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: AppLabel(
                            text: _subtitle(log, isMissed, isOutgoing),
                            fontSize: AppFontSize.value12,
                            color: theme.colorScheme.onSurfaceVariant,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              AppLabel(
                text: _formatStamp(log.startedAt),
                fontSize: AppFontSize.value11,
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _subtitle(ChatCallLog log, bool isMissed, bool isOutgoing) {
    if (isMissed) return 'chatCallMissed'.tr;
    if (log.durationSeconds > 0) {
      return '${isOutgoing ? 'chatCallOutgoing'.tr : 'chatCallIncoming'.tr} · ${log.formattedDuration()}';
    }
    return isOutgoing ? 'chatCallOutgoing'.tr : 'chatCallIncoming'.tr;
  }

  static String _formatStamp(DateTime when) {
    final now = DateTime.now();
    final whenDay = DateTime(when.year, when.month, when.day);
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(whenDay).inDays;
    if (diff == 0) return DateFormat('HH:mm').format(when);
    if (diff == 1) return 'chatYesterday'.tr;
    if (diff < 7) return DateFormat('EEE').format(when);
    return DateFormat('d MMM').format(when);
  }
}
