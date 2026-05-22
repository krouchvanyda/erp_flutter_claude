import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get_it/get_it.dart';

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

/// Slice 10.1.3 — New Conversation / Group Chat.
class NewConversationPage extends StatefulWidget {
  const NewConversationPage({super.key});

  @override
  State<NewConversationPage> createState() => _NewConversationPageState();
}

enum _Mode { direct, group }

class _NewConversationPageState extends State<NewConversationPage> {
  final _searchCtrl = TextEditingController();
  final _groupNameCtrl = TextEditingController();
  String _query = '';
  _Mode _mode = _Mode.direct;
  final Set<String> _selected = {};
  bool _creating = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _groupNameCtrl.dispose();
    super.dispose();
  }

  List<ChatParticipantPreview> get _filtered {
    final q = _query.trim().toLowerCase();
    final me = GetIt.I<ChatSettings>().userId;
    final everyone = ChatSeed.peopleDirectory
        .where((p) => p.employeeId != me)
        .toList();
    if (q.isEmpty) return everyone;
    return everyone.where((p) => p.name.toLowerCase().contains(q)).toList();
  }

  bool get _canCreate {
    if (_creating) return false;
    if (_mode == _Mode.direct) return _selected.length == 1;
    return _selected.length >= 2;
  }

  /// Group-mode confirm flow: members are already picked, so we only
  /// need the name. Prompt for it in a bottom sheet; on confirm, set
  /// the controller and run [_create].
  Future<void> _confirmCreateGroup() async {
    final name = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _GroupNameSheet(memberCount: _selected.length),
    );
    if (name == null || name.trim().isEmpty || !mounted) return;
    _groupNameCtrl.text = name.trim();
    await _create();
  }

  Future<void> _create() async {
    setState(() => _creating = true);
    try {
      final repo = GetIt.I<ConversationsRepository>();
      ChatConversation draft;
      final now = DateTime.now();
      if (_mode == _Mode.direct) {
        final picked = ChatSeed.personById(_selected.first);
        draft = ChatConversation(
          id: '',
          name: picked.name,
          isGroup: false,
          isMuted: false,
          unreadCount: 0,
          createdAt: now,
          updatedAt: now,
          presence: picked.presence,
        );
      } else {
        final previews =
            _selected.map(ChatSeed.personById).toList(growable: false);
        final online = previews
            .where((p) => p.presence == PresenceStatus.online)
            .length;
        draft = ChatConversation(
          id: '',
          name: _groupNameCtrl.text.trim(),
          isGroup: true,
          isMuted: false,
          unreadCount: 0,
          createdAt: now,
          updatedAt: now,
          participantPreviews: previews,
          totalMembers: previews.length + 1, // include self
          onlineCount: online,
        );
      }
      final created = await repo.create(draft);
      // Slice 10.1.7 — broadcast group creation so every invited member
      // hydrates the conversation locally. Direct convs don't broadcast
      // (they materialise implicitly on the first message exchange).
      if (_mode == _Mode.group) {
        final settings = GetIt.I<ChatSettings>();
        // Wire payload includes the creator AND every invited member so
        // each callee can verify it's actually addressed to them.
        final participantIds = <String>[
          settings.userId,
          ..._selected,
        ];
        GetIt.I<ChatTransport>().sendConversationCreate(
          conversationId: created.id,
          name: created.name,
          isGroup: true,
          creatorId: settings.userId,
          creatorName: settings.userName,
          participantIds: participantIds,
          createdAt: now,
        );
      }
      if (!mounted) return;
      Navigator.pop(context);
      await ConfigRouter.pushPageAnimation(
        context,
        ChatConversationPage(conversationId: created.id),
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: DynamicAppBar(title: 'New Message', centerTitle: true),
      body: DynamicStatusBar(
        child: Stack(
          children: [
            const AppBackgroundGradient(),
            Column(
              children: [
                SizedBox(height: context.dynamicAppBarPadding + kToolbarHeight),
                _ModeToggle(
                  mode: _mode,
                  onChanged: (m) => setState(() {
                    _mode = m;
                    if (m == _Mode.direct && _selected.length > 1) {
                      _selected.clear();
                    }
                  }),
                ),
                _SearchBar(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v),
                ),
                // Group mode only — Direct mode opens the chat
                // immediately on tap, so the chip row would just flash
                // briefly before navigation.
                if (_mode == _Mode.group && _selected.isNotEmpty)
                  _SelectedChips(
                    selectedIds: _selected,
                    onRemove: (id) => setState(() => _selected.remove(id)),
                  ),
                const Divider(height: 1),
                Expanded(child: _MemberList(
                  people: _filtered,
                  selected: _selected,
                  isMulti: _mode == _Mode.group,
                  onToggle: (id) {
                    if (_mode == _Mode.direct) {
                      // Direct mode: tapping a member opens the chat
                      // immediately — no Start Chat confirmation step.
                      setState(() {
                        _selected
                          ..clear()
                          ..add(id);
                      });
                      _create();
                      return;
                    }
                    setState(() {
                      if (_selected.contains(id)) {
                        _selected.remove(id);
                      } else {
                        _selected.add(id);
                      }
                    });
                  },
                )),
                // Bottom action bar only matters in Group mode —
                // Direct mode opens the chat the moment a member is tapped.
                if (_mode == _Mode.group)
                  _BottomBar(
                    enabled: _canCreate,
                    busy: _creating,
                    label: 'Create Group',
                    onPressed: _confirmCreateGroup,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.mode, required this.onChanged});
  final _Mode mode;
  final ValueChanged<_Mode> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Expanded(child: _Pill(label: 'Direct', selected: mode == _Mode.direct, onTap: () => onChanged(_Mode.direct))),
          Expanded(child: _Pill(label: 'Group', selected: mode == _Mode.group, onTap: () => onChanged(_Mode.group))),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.pill),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: selected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

/// Bottom-sheet prompt that asks for the group name only — members
/// are already picked on the underlying page. Pops with the trimmed
/// name on confirm, or `null` when dismissed / cancelled. The
/// controller is owned by [_GroupNameSheetState] so the TextField is
/// disposed cleanly with the sheet (avoids the InputDecorator
/// `_dependents.isEmpty` assertion).
class _GroupNameSheet extends StatefulWidget {
  const _GroupNameSheet({required this.memberCount});
  final int memberCount;

  @override
  State<_GroupNameSheet> createState() => _GroupNameSheetState();
}

class _GroupNameSheetState extends State<_GroupNameSheet> {
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Re-render on each keystroke so the Confirm button can flip
    // enabled the moment the field is non-empty.
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
    final canConfirm = _ctrl.text.trim().isNotEmpty;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer
                      .withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.groups_rounded,
                  color: theme.colorScheme.primary,
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
                      'Name your group',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.memberCount} member${widget.memberCount == 1 ? '' : 's'} selected',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              if (canConfirm) Navigator.pop(context, _ctrl.text);
            },
            decoration: InputDecoration(
              labelText: 'Group name',
              hintText: 'e.g. Q3 Launch Crew',
              prefixIcon: const Icon(Icons.edit_outlined, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              isDense: true,
            ),
          ),
          const SizedBox(height: 20),
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
                  onPressed: canConfirm
                      ? () => Navigator.pop(context, _ctrl.text)
                      : null,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.md),
                    ),
                  ),
                  child: const Text(
                    'Create Group',
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

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      decoration: BoxDecoration(
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
          hintText: 'Search employees',
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

class _SelectedChips extends StatelessWidget {
  const _SelectedChips({required this.selectedIds, required this.onRemove});
  final Set<String> selectedIds;
  final void Function(String employeeId) onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final id in selectedIds)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: InputChip(
                avatar: ChatAvatar(
                  name: ChatSeed.personById(id).name,
                  size: 24,
                  showStatus: false,
                ),
                label: Text(
                  ChatSeed.personById(id).name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                deleteIcon: const Icon(Icons.close_rounded, size: 16),
                onDeleted: () => onRemove(id),
                backgroundColor: theme.colorScheme.surface,
                side: BorderSide(
                  color: theme.colorScheme.primary.withValues(alpha: 0.4),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MemberList extends StatelessWidget {
  const _MemberList({
    required this.people,
    required this.selected,
    required this.isMulti,
    required this.onToggle,
  });
  final List<ChatParticipantPreview> people;
  final Set<String> selected;
  final bool isMulti;
  final void Function(String id) onToggle;

  @override
  Widget build(BuildContext context) {
    if (people.isEmpty) {
      return const Center(child: Text('No employees match.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.only(top: 4, bottom: 96),
      itemCount: people.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        indent: 72,
        color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
      ),
      itemBuilder: (_, i) {
        final p = people[i];
        final isSel = selected.contains(p.employeeId);
        final theme = Theme.of(context);
        return Material(
          color: isSel
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4)
              : Colors.transparent,
          child: InkWell(
            onTap: () => onToggle(p.employeeId),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  ChatAvatar(name: p.name, size: 44, presence: p.presence),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      p.name,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (isMulti)
                    Checkbox(
                      value: isSel,
                      onChanged: (_) => onToggle(p.employeeId),
                    )
                ],
              ),
            ),
          ),
        ).animate().fadeIn(delay: (i * 25).clamp(0, 240).ms);
      },
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.enabled,
    required this.busy,
    required this.label,
    required this.onPressed,
  });
  final bool enabled;
  final bool busy;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
        ),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: enabled ? onPressed : null,
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
            ),
            child: busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
          ),
        ),
      ),
    );
  }
}
