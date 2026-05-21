import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/router/config_router.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/widgets/dynamic_app_bar.dart';
import '../../../../core/widgets/dynamic_status_bar.dart';
import '../../../../shared/widgets/app_background_gradient.dart';
import '../../data/chat_seed.dart';
import '../../data/repositories/conversations_repository.dart';
import '../../data/repositories/messages_repository.dart';
import '../../entities/chat_message.dart';
import '../../entities/conversation.dart';
import '../widgets/chat_avatar.dart';
import 'message_search_page.dart';
import 'video_call_page.dart';
import 'voice_call_page.dart';

/// Slice 10.3.1 — Conversation Info / Chat Settings.
class ChatInfoPage extends StatelessWidget {
  const ChatInfoPage({super.key, required this.conversationId});

  final String conversationId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const DynamicAppBar(title: 'Info', centerTitle: false),
      body: DynamicStatusBar(
        child: Stack(
          children: [
            const AppBackgroundGradient(),
            StreamBuilder<ChatConversation?>(
              stream: GetIt.I<ConversationsRepository>()
                  .watchById(conversationId),
              builder: (context, snap) {
                final conv = snap.data;
                if (conv == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                return _Body(conversation: conv);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.conversation});
  final ChatConversation conversation;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.only(
        top: context.dynamicAppBarPadding,
        left: 16,
        right: 16,
        bottom: 32,
      ),
      children: [
        _Hero(conversation: conversation)
            .animate()
            .fadeIn()
            .slideY(begin: 0.04, end: 0, duration: 320.ms),
        const SizedBox(height: 20),
        _QuickActions(conversation: conversation)
            .animate()
            .fadeIn(delay: 60.ms)
            .slideY(begin: 0.04, end: 0, duration: 320.ms),
        const SizedBox(height: 20),
        _SharedMedia(conversationId: conversation.id)
            .animate()
            .fadeIn(delay: 120.ms)
            .slideY(begin: 0.04, end: 0, duration: 320.ms),
        const SizedBox(height: 20),
        _Settings(conversation: conversation)
            .animate()
            .fadeIn(delay: 180.ms)
            .slideY(begin: 0.04, end: 0, duration: 320.ms),
        if (conversation.isGroup) ...[
          const SizedBox(height: 20),
          _Members(conversation: conversation)
              .animate()
              .fadeIn(delay: 240.ms)
              .slideY(begin: 0.04, end: 0, duration: 320.ms),
        ],
        const SizedBox(height: 20),
        _DangerZone(conversation: conversation)
            .animate()
            .fadeIn(delay: 300.ms)
            .slideY(begin: 0.04, end: 0, duration: 320.ms),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.conversation});
  final ChatConversation conversation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        if (conversation.isGroup)
          GroupAvatarCluster(
            previews: conversation.participantPreviews,
            size: 96,
          )
        else
          ChatAvatar(
            name: conversation.name,
            size: 96,
            presence: conversation.presence,
          ),
        const SizedBox(height: 14),
        Text(
          conversation.name,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          conversation.isGroup
              ? '${conversation.totalMembers} members · ${conversation.onlineCount} online'
              : _presenceLabel(conversation.presence),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  String _presenceLabel(PresenceStatus p) {
    switch (p) {
      case PresenceStatus.online:
        return 'Online now';
      case PresenceStatus.away:
        return 'Away';
      case PresenceStatus.offline:
        return 'Offline';
    }
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.conversation});
  final ChatConversation conversation;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        children: [
          _ActionRow(
            icon: Icons.call_rounded,
            iconColor: Colors.green.shade700,
            label: 'Voice call',
            onTap: () => ConfigRouter.pushPageAnimation(
              context,
              VoiceCallPage(conversationId: conversation.id),
            ),
          ),
          const _Hairline(),
          _ActionRow(
            icon: Icons.videocam_rounded,
            iconColor: Colors.blue.shade700,
            label: 'Video call',
            onTap: () => ConfigRouter.pushPageAnimation(
              context,
              VideoCallPage(conversationId: conversation.id),
            ),
          ),
          const _Hairline(),
          _ActionRow(
            icon: Icons.search_rounded,
            iconColor: Colors.deepPurple,
            label: 'Search messages',
            onTap: () => ConfigRouter.pushPageAnimation(
              context,
              const MessageSearchPage(),
            ),
          ),
          if (conversation.isGroup) ...[
            const _Hairline(),
            _ActionRow(
              icon: Icons.person_add_alt_1_rounded,
              iconColor: Colors.orange.shade700,
              label: 'Add members',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Add-member picker would open here.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _SharedMedia extends StatelessWidget {
  const _SharedMedia({required this.conversationId});
  final String conversationId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<List<ChatMessage>>(
      future: GetIt.I<MessagesRepository>().getForConversation(conversationId),
      builder: (context, snap) {
        final media = (snap.data ?? const <ChatMessage>[])
            .where((m) =>
                m.type == ChatMessageType.image ||
                m.type == ChatMessageType.file)
            .take(6)
            .toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Row(
                children: [
                  Text(
                    'SHARED MEDIA',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  if (media.isNotEmpty)
                    TextButton(
                      onPressed: () {},
                      child: const Text('See all'),
                    ),
                ],
              ),
            ),
            _Card(
              child: media.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: Text(
                          'No shared media yet.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(8),
                      child: GridView.count(
                        crossAxisCount: 3,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        children: [
                          for (final m in media) _MediaTile(message: m),
                        ],
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _MediaTile extends StatelessWidget {
  const _MediaTile({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isImage = message.type == ChatMessageType.image;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: Container(
        color: theme.colorScheme.surfaceContainerHighest,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isImage ? Icons.image_outlined : Icons.insert_drive_file_outlined,
              color: theme.colorScheme.onSurfaceVariant,
              size: 28,
            ),
            if (!isImage && message.fileName != null) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  message.fileName!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Settings extends StatelessWidget {
  const _Settings({required this.conversation});
  final ChatConversation conversation;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        children: [
          _SwitchRow(
            icon: Icons.notifications_off_outlined,
            iconColor: Colors.amber.shade700,
            label: 'Mute notifications',
            value: conversation.isMuted,
            onChanged: (v) => GetIt.I<ConversationsRepository>()
                .setMuted(conversation.id, v),
          ),
          if (conversation.pinnedMessageId != null) ...[
            const _Hairline(),
            _ActionRow(
              icon: Icons.push_pin_outlined,
              iconColor: Colors.teal,
              label: 'View pinned message',
              onTap: () => Navigator.pop(context),
            ),
          ],
        ],
      ),
    );
  }
}

class _Members extends StatelessWidget {
  const _Members({required this.conversation});
  final ChatConversation conversation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shown = conversation.participantPreviews.take(5).toList();
    final extra = conversation.totalMembers - shown.length - 1; // -1 for self
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text(
            'MEMBERS · ${conversation.totalMembers}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ),
        _Card(
          child: Column(
            children: [
              _MemberRow(
                name: ChatSeed.currentUserName,
                role: 'You',
                presence: PresenceStatus.online,
                isAdmin: true,
              ),
              for (final p in shown) ...[
                const _Hairline(),
                _MemberRow(
                  name: p.name,
                  presence: p.presence,
                  role: null,
                  isAdmin: false,
                ),
              ],
              if (extra > 0) ...[
                const _Hairline(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: TextButton(
                    onPressed: () {},
                    child: Text('+ $extra more'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.name,
    required this.presence,
    required this.role,
    required this.isAdmin,
  });
  final String name;
  final PresenceStatus presence;
  final String? role;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          ChatAvatar(name: name, size: 40, presence: presence),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (role != null)
                  Text(
                    role!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          if (isAdmin)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
              child: Text(
                'ADMIN',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w900,
                  fontSize: 9,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DangerZone extends StatelessWidget {
  const _DangerZone({required this.conversation});
  final ChatConversation conversation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Card(
      child: Column(
        children: [
          if (conversation.isGroup) ...[
            _ActionRow(
              icon: Icons.exit_to_app_rounded,
              iconColor: theme.colorScheme.error,
              destructive: true,
              label: 'Leave group',
              onTap: () => _confirmLeave(context),
            ),
            const _Hairline(),
          ],
          _ActionRow(
            icon: Icons.cleaning_services_rounded,
            iconColor: theme.colorScheme.error,
            destructive: true,
            label: 'Clear chat history',
            onTap: () => _confirmClear(context),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLeave(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Text('Leave "${conversation.name}"?'),
        content: const Text(
            'You will stop receiving messages from this group. An admin can re-add you.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(dCtx, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!context.mounted) return;
    await GetIt.I<ConversationsRepository>().delete(conversation.id);
    if (!context.mounted) return;
    Navigator.popUntil(context, (r) => r.isFirst);
  }

  Future<void> _confirmClear(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Clear chat history?'),
        content: const Text(
            'This clears the history on your device only. Other members keep their copy.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(dCtx, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('History cleared on this device.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ── shared bits ────────────────────────────────────────────

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _Hairline extends StatelessWidget {
  const _Hairline();
  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 56,
      color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: destructive ? theme.colorScheme.error : null,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.outline,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final IconData icon;
  final Color iconColor;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
