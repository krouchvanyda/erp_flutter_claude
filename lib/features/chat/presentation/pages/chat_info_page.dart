import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get_it/get_it.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/router/config_router.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/widgets/dynamic_app_bar.dart';
import '../../../../core/widgets/dynamic_status_bar.dart';
import '../../../../shared/widgets/app_background_gradient.dart';
import '../../data/chat_seed.dart';
import '../../data/chat_settings.dart';
import '../../data/repositories/conversations_repository.dart';
import '../../data/repositories/messages_repository.dart';
import '../../entities/chat_message.dart';
import '../../entities/conversation.dart';
import '../widgets/chat_avatar.dart';
import 'image_viewer_page.dart';
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
    final isGroup = conversation.isGroup;
    final hasPhoto = (conversation.avatarFilePath ?? '').isNotEmpty;
    return Column(
      children: [
        // Slice 10.3.3 — group avatar is tappable (admin only).
        // A custom photo wins over the participant cluster.
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: isGroup
                    ? () => _showChangePhotoSheet(context, conversation)
                    : null,
                customBorder: const CircleBorder(),
                child: SizedBox(
                  width: 96,
                  height: 96,
                  child: isGroup
                      ? (hasPhoto
                          ? ChatAvatar(
                              name: conversation.name,
                              size: 96,
                              avatarFilePath: conversation.avatarFilePath,
                              showStatus: false,
                            )
                          : GroupAvatarCluster(
                              previews: conversation.participantPreviews,
                              size: 96,
                            ))
                      : ChatAvatar(
                          name: conversation.name,
                          size: 96,
                          presence: conversation.presence,
                        ),
                ),
              ),
            ),
            if (isGroup)
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.colorScheme.surface,
                    width: 2,
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.camera_alt_rounded,
                  size: 14,
                  color: theme.colorScheme.onPrimary,
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        // Slice 10.3.3 — group name is tappable (admin only) → opens
        // the rename sheet. Pencil icon makes the affordance obvious.
        InkWell(
          onTap: isGroup
              ? () => _showRenameSheet(context, conversation)
              : null,
          borderRadius: BorderRadius.circular(AppRadii.md),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    conversation.name,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                if (isGroup) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          isGroup
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
              onTap: () => _showAddMembersSheet(context, conversation),
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
    final url = message.fileUrl ?? '';
    final isLocalFile = isImage &&
        url.isNotEmpty &&
        !url.startsWith('http') &&
        !url.startsWith('demo://');

    Widget cover;
    if (isLocalFile) {
      cover = Image.file(
        File(url),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _stubBox(context, message, isImage),
      );
    } else if (isImage && (url.startsWith('http://') || url.startsWith('https://'))) {
      cover = Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _stubBox(context, message, isImage),
      );
    } else {
      cover = _stubBox(context, message, isImage);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest,
        child: InkWell(
          // Slice 10.1.5 — tapping an image tile opens the same
          // viewer as tapping the bubble. File tiles fall through to
          // the snackbar (downloading is a follow-up slice).
          onTap: isImage
              ? () => ConfigRouter.pushPageAnimation(
                    context,
                    ImageViewerPage(message: message),
                  )
              : () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('File download would run here.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  ),
          child: SizedBox.expand(child: cover),
        ),
      ),
    );
  }

  static Widget _stubBox(BuildContext context, ChatMessage message, bool isImage) {
    final theme = Theme.of(context);
    return Container(
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
                name: GetIt.I<ChatSettings>().userName,
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

// ── Slice 10.3.2 — Add Members ───────────────────────────────────
//
// Top-level helper invoked from the "Add members" action row + (later)
// from "Add" trailing button on the members section header. Opens a
// modal sheet whose state is owned by [_AddMembersSheet] so the
// controller / selection set live with the sheet's State instead of
// leaking through the outer function (same pattern as _ReAuthSheet).

Future<void> _showAddMembersSheet(
  BuildContext context,
  ChatConversation conversation,
) async {
  final picks = await showModalBottomSheet<List<ChatParticipantPreview>>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _AddMembersSheet(conversation: conversation),
  );
  if (picks == null || picks.isEmpty || !context.mounted) return;
  await GetIt.I<ConversationsRepository>().addMembers(
    id: conversation.id,
    people: picks,
  );
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        picks.length == 1
            ? '${picks.first.name} added to the group.'
            : '${picks.length} members added.',
      ),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

class _AddMembersSheet extends StatefulWidget {
  const _AddMembersSheet({required this.conversation});
  final ChatConversation conversation;

  @override
  State<_AddMembersSheet> createState() => _AddMembersSheetState();
}

class _AddMembersSheetState extends State<_AddMembersSheet> {
  final _searchCtrl = TextEditingController();
  final Set<String> _selected = {};
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<ChatParticipantPreview> get _candidates {
    final me = GetIt.I<ChatSettings>().userId;
    final inGroup = {
      me,
      ...widget.conversation.participantPreviews.map((p) => p.employeeId),
    };
    final q = _query.trim().toLowerCase();
    return ChatSeed.peopleDirectory
        .where((p) => !inGroup.contains(p.employeeId))
        .where((p) => q.isEmpty || p.name.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final candidates = _candidates;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 12,
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person_add_alt_1_rounded,
                  color: Colors.orange.shade700,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Add members',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      'Pick from your directory — already-in-group folks '
                      'are filtered out.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Search employees…',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: candidates.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        _query.isEmpty
                            ? 'Everyone in the directory is already in this '
                                'group.'
                            : 'No employees match "${_query.trim()}".',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: candidates.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      indent: 64,
                      color: theme.colorScheme.outlineVariant
                          .withValues(alpha: 0.4),
                    ),
                    itemBuilder: (_, i) {
                      final p = candidates[i];
                      final sel = _selected.contains(p.employeeId);
                      return Material(
                        color: sel
                            ? theme.colorScheme.primaryContainer
                                .withValues(alpha: 0.4)
                            : Colors.transparent,
                        child: InkWell(
                          onTap: () => setState(() {
                            if (sel) {
                              _selected.remove(p.employeeId);
                            } else {
                              _selected.add(p.employeeId);
                            }
                          }),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 8,
                            ),
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
                                    style:
                                        theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Checkbox(
                                  value: sel,
                                  onChanged: (_) => setState(() {
                                    if (sel) {
                                      _selected.remove(p.employeeId);
                                    } else {
                                      _selected.add(p.employeeId);
                                    }
                                  }),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 12),
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
                  onPressed: _selected.isEmpty
                      ? null
                      : () {
                          final picks = _selected
                              .map(ChatSeed.personById)
                              .toList(growable: false);
                          Navigator.pop(context, picks);
                        },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.md),
                    ),
                  ),
                  child: Text(
                    _selected.isEmpty
                        ? 'Add'
                        : 'Add ${_selected.length}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
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

// ── Slice 10.3.3 — Rename group + Change group photo ────────────

Future<void> _showRenameSheet(
  BuildContext context,
  ChatConversation conversation,
) async {
  final name = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _RenameGroupSheet(initialName: conversation.name),
  );
  if (name == null || name.trim().isEmpty || !context.mounted) return;
  await GetIt.I<ConversationsRepository>().rename(conversation.id, name.trim());
}

class _RenameGroupSheet extends StatefulWidget {
  const _RenameGroupSheet({required this.initialName});
  final String initialName;

  @override
  State<_RenameGroupSheet> createState() => _RenameGroupSheetState();
}

class _RenameGroupSheetState extends State<_RenameGroupSheet> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialName);
    _ctrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canSave =
        _ctrl.text.trim().isNotEmpty && _ctrl.text.trim() != widget.initialName;
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
            'Rename group',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              if (canSave) Navigator.pop(context, _ctrl.text);
            },
            decoration: InputDecoration(
              labelText: 'Group name',
              prefixIcon: const Icon(Icons.edit_outlined, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              isDense: true,
            ),
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
                  onPressed: canSave
                      ? () => Navigator.pop(context, _ctrl.text)
                      : null,
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

Future<void> _showChangePhotoSheet(
  BuildContext context,
  ChatConversation conversation,
) async {
  final theme = Theme.of(context);
  final hasPhoto = (conversation.avatarFilePath ?? '').isNotEmpty;
  await showModalBottomSheet<void>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetCtx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
              hasPhoto ? 'Change group photo' : 'Add a group photo',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            _PhotoOptionTile(
              icon: Icons.camera_alt_outlined,
              label: 'Take photo',
              color: theme.colorScheme.primary,
              onTap: () async {
                Navigator.pop(sheetCtx);
                await _pickGroupPhoto(context, conversation, ImageSource.camera);
              },
            ),
            const SizedBox(height: 8),
            _PhotoOptionTile(
              icon: Icons.photo_library_outlined,
              label: 'Choose from gallery',
              color: Colors.green.shade700,
              onTap: () async {
                Navigator.pop(sheetCtx);
                await _pickGroupPhoto(context, conversation, ImageSource.gallery);
              },
            ),
            if (hasPhoto) ...[
              const SizedBox(height: 8),
              _PhotoOptionTile(
                icon: Icons.delete_outline,
                label: 'Remove photo',
                color: theme.colorScheme.error,
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  await GetIt.I<ConversationsRepository>()
                      .setAvatarPath(conversation.id, null);
                },
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

Future<void> _pickGroupPhoto(
  BuildContext context,
  ChatConversation conversation,
  ImageSource source,
) async {
  try {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked == null) return;
    final file = File(picked.path);
    if (!await file.exists()) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not read the selected image.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await GetIt.I<ConversationsRepository>()
        .setAvatarPath(conversation.id, picked.path);
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Could not pick image: $e'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _PhotoOptionTile extends StatelessWidget {
  const _PhotoOptionTile({
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
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
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
