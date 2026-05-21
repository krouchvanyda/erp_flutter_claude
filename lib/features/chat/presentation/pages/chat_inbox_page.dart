import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/config_router.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/widgets/dynamic_app_bar.dart';
import '../../../../core/widgets/dynamic_status_bar.dart';
import '../../../../shared/widgets/app_background_gradient.dart';
import '../../data/chat_seed.dart';
import '../../data/chat_settings.dart';
import '../../data/chat_transport.dart';
import '../../data/repositories/conversations_repository.dart';
import '../../entities/conversation.dart';
import '../widgets/chat_avatar.dart';
import 'chat_conversation_page.dart';
import 'message_search_page.dart';
import 'new_conversation_page.dart';

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
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _showIdentitySheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _IdentitySheet(),
    );
  }

  Future<void> _showRelayUrlSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _RelayUrlSheet(),
    );
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
    return result.toList();
  }

  @override
  Widget build(BuildContext context) {
    final repo = GetIt.I<ConversationsRepository>();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: DynamicAppBar(
        title: 'Messages',
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Search',
            icon: const Icon(Icons.search_rounded),
            onPressed: () => ConfigRouter.pushPageAnimation(
              context,
              const MessageSearchPage(),
            ),
          ),
          IconButton(
            tooltip: 'New message',
            icon: const Icon(Icons.edit_note_rounded),
            onPressed: () => ConfigRouter.pushPageAnimation(
              context,
              const NewConversationPage(),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Chat settings',
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (v) {
              switch (v) {
                case 'identity':
                  _showIdentitySheet(context);
                case 'relay':
                  _showRelayUrlSheet(context);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'identity',
                child: ListTile(
                  leading: Icon(Icons.switch_account_rounded),
                  title: Text('Sign in as…'),
                  subtitle: Text('Switch demo identity'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'relay',
                child: ListTile(
                  leading: Icon(Icons.cable_rounded),
                  title: Text('Relay URL…'),
                  subtitle: Text('Connect 2 devices'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
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
                    const _TransportStatusPill(),
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
          hintText: 'Search conversations',
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
        tabs: const [
          Tab(text: 'All'),
          Tab(text: 'Unread'),
          Tab(text: 'Groups'),
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
    final repo = GetIt.I<ConversationsRepository>();
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
            Text(
              conversation.isMuted ? 'Unmute' : 'Mute',
              style: TextStyle(
                color: Colors.blue.shade700,
                fontWeight: FontWeight.w800,
              ),
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
            Text(
              'Delete',
              style: TextStyle(
                color: Colors.red.shade700,
                fontWeight: FontWeight.w800,
              ),
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
                title: const Text('Delete conversation?'),
                content: Text(
                    'Remove "${conversation.name}" from your inbox. The other side keeps the conversation.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dCtx, false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.error,
                    ),
                    onPressed: () => Navigator.pop(dCtx, true),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) => repo.delete(conversation.id),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          onTap: () async {
            await GetIt.I<ConversationsRepository>().markRead(conversation.id);
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
                if (conversation.isGroup)
                  GroupAvatarCluster(
                    previews: conversation.participantPreviews,
                    size: 52,
                  )
                else
                  ChatAvatar(
                    name: conversation.name,
                    size: 52,
                    presence: conversation.presence,
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              conversation.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: hasUnread
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                              ),
                            ),
                          ),
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
                            Text(
                              _formatStamp(conversation.lastMessageAt!),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: hasUnread
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurfaceVariant,
                                fontWeight: hasUnread
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _previewFor(conversation),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: hasUnread
                                    ? theme.colorScheme.onSurface
                                    : theme.colorScheme.onSurfaceVariant,
                                fontWeight: hasUnread
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
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

  static String _previewFor(ChatConversation c) {
    if (c.lastMessageBody == null) return 'No messages yet';
    final me = GetIt.I<ChatSettings>().userId;
    final ownPrefix = c.lastMessageSenderId == me ? 'You: ' : '';
    return '$ownPrefix${c.lastMessageBody}';
  }

  static String _formatStamp(DateTime when) {
    final now = DateTime.now();
    final whenDay = DateTime(when.year, when.month, when.day);
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(whenDay).inDays;
    if (diff == 0) return DateFormat('HH:mm').format(when);
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return DateFormat('EEE').format(when);
    return DateFormat('d MMM').format(when);
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
      child: Text(
        count > 99 ? '99+' : '$count',
        style: TextStyle(
          color: theme.colorScheme.onPrimary,
          fontWeight: FontWeight.w900,
          fontSize: 11,
        ),
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
            Text(
              'No conversations',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Start a chat with a teammate or create a group.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Transport status pill ───────────────────────────────────────
//
// Sits just below the AppBar. Streams from [ChatTransport.status] so
// the user can tell at a glance whether peer messages will flow.
// Tappable: opens the Relay URL sheet directly so a misconfigured URL
// is one tap from being fixed.

class _TransportStatusPill extends StatelessWidget {
  const _TransportStatusPill();

  @override
  Widget build(BuildContext context) {
    final transport = GetIt.I<ChatTransport>();
    final settings = GetIt.I<ChatSettings>();
    return StreamBuilder<ChatTransportStatus>(
      stream: transport.status,
      initialData: transport.currentStatus,
      builder: (context, snap) {
        final status = snap.data ?? ChatTransportStatus.disconnected;
        // Hide entirely when no relay is configured AND we're idle —
        // there's nothing useful to show and the row would just
        // waste vertical space on the single-device demo.
        if (status == ChatTransportStatus.disconnected &&
            settings.relayUrl.isEmpty) {
          return const SizedBox.shrink();
        }
        final theme = Theme.of(context);
        final (label, accent, icon) = switch (status) {
          ChatTransportStatus.connected => (
              'Live · ${_shortHost(settings.relayUrl)}',
              Colors.green.shade600,
              Icons.bolt_rounded,
            ),
          ChatTransportStatus.connecting => (
              'Connecting…',
              Colors.amber.shade700,
              Icons.sync_rounded,
            ),
          ChatTransportStatus.error => (
              'Connection error — tap to fix',
              theme.colorScheme.error,
              Icons.error_outline_rounded,
            ),
          ChatTransportStatus.disconnected => (
              'Offline — tap to set a relay',
              theme.colorScheme.onSurfaceVariant,
              Icons.cloud_off_rounded,
            ),
        };
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Material(
            color: accent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(AppRadii.pill),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadii.pill),
              onTap: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (_) => const _RelayUrlSheet(),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 14, color: accent),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    if (settings.userName.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        width: 3,
                        height: 3,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.55),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        settings.userName,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: accent.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static String _shortHost(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    return '${uri.host}:${uri.port}';
  }
}

// ── Identity picker ─────────────────────────────────────────────
//
// Bottom sheet that lists everyone in the demo directory plus the
// seeded "Demo Approver" identity. Tapping a row writes the choice to
// [ChatSettings] (which persists via shared_preferences) and the
// transport reconnects with the new identity.

class _IdentitySheet extends StatefulWidget {
  const _IdentitySheet();

  @override
  State<_IdentitySheet> createState() => _IdentitySheetState();
}

class _IdentitySheetState extends State<_IdentitySheet> {
  late String _selectedId;

  @override
  void initState() {
    super.initState();
    _selectedId = GetIt.I<ChatSettings>().userId;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final everyone = [
      // Always include the seeded default so users can switch back.
      const ChatParticipantPreview(
        employeeId: ChatSeed.currentUserId,
        name: ChatSeed.currentUserName,
        presence: PresenceStatus.online,
      ),
      ...ChatSeed.peopleDirectory
          .where((p) => p.employeeId != ChatSeed.currentUserId),
    ];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Sign in as…',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Switch identity to test two-way chat. The relay routes '
              'each message to every other connected client.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: everyone.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  indent: 64,
                  color: theme.colorScheme.outlineVariant
                      .withValues(alpha: 0.4),
                ),
                itemBuilder: (_, i) {
                  final p = everyone[i];
                  final isSel = p.employeeId == _selectedId;
                  return Material(
                    color: isSel
                        ? theme.colorScheme.primaryContainer
                            .withValues(alpha: 0.4)
                        : Colors.transparent,
                    child: InkWell(
                      onTap: () async {
                        setState(() => _selectedId = p.employeeId);
                        await GetIt.I<ChatSettings>().setIdentity(
                          userId: p.employeeId,
                          userName: p.name,
                        );
                        if (context.mounted) Navigator.pop(context);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 8),
                        child: Row(
                          children: [
                            ChatAvatar(
                              name: p.name,
                              size: 40,
                              presence: p.presence,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                p.name,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (isSel)
                              Icon(
                                Icons.check_circle_rounded,
                                color: theme.colorScheme.primary,
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Relay URL sheet ─────────────────────────────────────────────

class _RelayUrlSheet extends StatefulWidget {
  const _RelayUrlSheet();

  @override
  State<_RelayUrlSheet> createState() => _RelayUrlSheetState();
}

class _RelayUrlSheetState extends State<_RelayUrlSheet> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: GetIt.I<ChatSettings>().relayUrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Chat relay URL',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Point both devices at the WebSocket relay running on your PC. '
            'Leave blank to stay offline.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _ctrl,
            autofocus: true,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'ws:// URL',
              hintText: 'ws://192.168.1.42:7777',
              prefixIcon: const Icon(Icons.cable_rounded, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final preset in const [
                ('Emulator', 'ws://10.0.2.2:7777'),
                ('Simulator', 'ws://127.0.0.1:7777'),
              ])
                ActionChip(
                  label: Text(preset.$1),
                  onPressed: () => _ctrl.text = preset.$2,
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.md),
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: () async {
                    await GetIt.I<ChatSettings>().setRelayUrl(_ctrl.text);
                    if (context.mounted) Navigator.pop(context);
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.md),
                    ),
                  ),
                  child: const Text(
                    'Save',
                    style: TextStyle(fontWeight: FontWeight.bold),
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
