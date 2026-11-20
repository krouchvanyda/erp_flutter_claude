import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/router/config_router.dart';
import '../../../core/theme/app_font_size.dart';
import '../../../core/theme/app_label.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_confirm_dialog.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../model/conversation_model.dart';
import '../model/member_model.dart';
import '../viewmodel/conversation_info/conversation_info_view_model_bloc.dart';
import '../widgets/conversation_info_action_tile.dart';
import '../widgets/conversation_info_header.dart';
import '../widgets/conversation_rename_sheet.dart';
import '../widgets/member_tile.dart';
import 'member_picker_page.dart';

/// Chat info (Step 5.4). Layout only.
///
/// Uses the SAME [ConversationInfoViewModelBloc] as the chat page
/// (`BlocProvider.value`), so a rename shows in the chat's title too.
/// When the chat is gone (left / deleted / removed), the CHAT page closes
/// both pages — this page does nothing for that.
///
/// ```
/// group, admin:  ✎ rename · + Add members · ⊖ remove · Leave · Delete group
/// group:         Leave group
/// direct:        the other person · Delete chat
/// ```
class ConversationInfoPage extends StatelessWidget {
  const ConversationInfoPage({super.key, required this.myId});

  final String? myId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const AppLabel(
          text: 'Chat info',
          fontSize: AppFontSize.value20,
          fontWeight: FontWeight.w700,
        ),
      ),
      body:
          BlocConsumer<
            ConversationInfoViewModelBloc,
            ConversationInfoViewModelState
          >(
            listenWhen: (previous, current) =>
                current is ConversationInfoFailedState,
            listener: (context, state) {
              if (state is ConversationInfoFailedState) {
                AppSnackBar.error(
                  context,
                  title: state.error.title,
                  message: state.error.description,
                );
              }
            },
            builder: (context, state) {
              final bloc = context.read<ConversationInfoViewModelBloc>();
              final c = state.conversation;
              final busy =
                  state is ConversationInfoGoneState ||
                  (state is ConversationInfoReadyState && state.isBusy);
              final admin = bloc.isAdmin;
              // me first, then admins, then by name
              final members = [...c.members]
                ..sort((a, b) {
                  int rank(MemberModel m) => m.userId == myId ? 0 : 1;
                  final r = rank(a).compareTo(rank(b));
                  return r != 0
                      ? r
                      : a.displayName.toLowerCase().compareTo(
                          b.displayName.toLowerCase(),
                        );
                });

              return Column(
                children: [
                  if (busy) const LinearProgressIndicator(minHeight: 2),
                  Expanded(
                    child: ListView(
                      children: [
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 600),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                ConversationInfoHeader(
                                  conversation: c,
                                  myId: myId,
                                  onRename: c.isGroup && admin && !busy
                                      ? () => _rename(context, c)
                                      : null,
                                ),
                                if (c.isGroup && admin)
                                  ConversationInfoActionTile(
                                    icon: Icons.person_add_alt_1_rounded,
                                    label: 'Add members',
                                    onTap: busy
                                        ? null
                                        : () => _addMembers(context, c),
                                  ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    AppSpacing.md,
                                    AppSpacing.md,
                                    AppSpacing.md,
                                    AppSpacing.xs,
                                  ),
                                  child: AppLabel(
                                    text: '${c.members.length} members',
                                    fontSize: AppFontSize.value14,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                for (final m in members)
                                  MemberTile(
                                    key: ValueKey(m.userId),
                                    member: m,
                                    isMe: m.userId == myId,
                                    onRemove:
                                        c.isGroup &&
                                            admin &&
                                            m.userId != myId &&
                                            !busy
                                        ? () => _remove(context, m)
                                        : null,
                                  ),
                                const Divider(height: AppSpacing.lg),
                                if (c.isGroup)
                                  ConversationInfoActionTile(
                                    icon: Icons.logout_rounded,
                                    label: 'Leave group',
                                    destructive: true,
                                    onTap: busy
                                        ? null
                                        : () => _leave(context, c),
                                  ),
                                if (!c.isGroup || admin)
                                  ConversationInfoActionTile(
                                    icon: Icons.delete_outline_rounded,
                                    label: c.isGroup
                                        ? 'Delete group'
                                        : 'Delete chat',
                                    destructive: true,
                                    onTap: busy
                                        ? null
                                        : () => _delete(context, c),
                                  ),
                                const SizedBox(height: AppSpacing.xl),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
    );
  }

  Future<void> _rename(BuildContext context, ConversationModel c) async {
    final bloc = context.read<ConversationInfoViewModelBloc>();
    final name = await ConversationRenameSheet.show(
      context,
      current: c.name ?? '',
    );
    if (name != null) bloc.add(OnInfoRenameEvent(name));
  }

  Future<void> _addMembers(BuildContext context, ConversationModel c) async {
    final bloc = context.read<ConversationInfoViewModelBloc>();
    final updated = await ConfigRouter.pushPageAnimation<ConversationModel>(
      context,
      MemberPickerPage(
        mode: MemberPickerMode.addMembers,
        conversationId: c.id,
        excludeIds: {for (final m in c.members) m.userId},
      ),
    );
    if (updated != null) bloc.add(OnInfoConversationChangedEvent(updated));
  }

  Future<void> _remove(BuildContext context, MemberModel m) async {
    final bloc = context.read<ConversationInfoViewModelBloc>();
    final yes = await AppConfirmDialog.show(
      context,
      title: 'Remove ${m.displayName}?',
      message: 'They will no longer see new messages in this group.',
      confirmText: 'Remove',
      icon: Icons.person_remove_rounded,
      destructive: true,
    );
    if (yes) bloc.add(OnInfoRemoveMemberEvent(m.userId));
  }

  Future<void> _leave(BuildContext context, ConversationModel c) async {
    final bloc = context.read<ConversationInfoViewModelBloc>();
    final yes = await AppConfirmDialog.show(
      context,
      title: 'Leave group?',
      message: 'You will stop getting messages from “${c.title(myId)}”.',
      confirmText: 'Leave',
      icon: Icons.logout_rounded,
      destructive: true,
    );
    if (yes) bloc.add(OnInfoLeaveEvent());
  }

  Future<void> _delete(BuildContext context, ConversationModel c) async {
    final bloc = context.read<ConversationInfoViewModelBloc>();
    final yes = await AppConfirmDialog.show(
      context,
      title: c.isGroup ? 'Delete group?' : 'Delete chat?',
      message:
          'All messages will be deleted for everyone. This can\'t be undone.',
      confirmText: 'Delete',
      icon: Icons.delete_outline_rounded,
      destructive: true,
    );
    if (yes) bloc.add(OnInfoDeleteEvent());
  }
}
