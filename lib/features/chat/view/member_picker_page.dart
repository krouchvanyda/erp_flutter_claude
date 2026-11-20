import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/router/config_router.dart';
import '../../../core/theme/app_font_size.dart';
import '../../../core/theme/app_label.dart';
import '../../../core/widgets/app_error_banner.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../model/conversation_model.dart';
import '../repository/chat_repository.dart';
import '../viewmodel/member_picker/member_picker_view_model_bloc.dart';
import '../widgets/contact_list.dart';
import '../widgets/picker_new_group_tile.dart';
import '../widgets/picker_search_field.dart';
import '../widgets/selected_contacts_bar.dart';
import 'new_group_page.dart';

/// What the picker is for.
enum MemberPickerMode {
  newChat, //    tap a person → 1-to-1 chat ("New group" row on top)
  newGroup, //   tick people → Next → name page
  addMembers, // tick people → Add
}

/// Pick people (Step 5.4). Layout only.
///
/// Closes with the [ConversationModel] that was opened / created / changed
/// (`Navigator.pop(conversation)`), or null when the user goes back.
///
/// ```
/// ┌ ← New group             Next ┐
/// │ 🔍 Search by name or email    │
/// │ (DS)ⓧ (JD)ⓧ                   │  ← SelectedContactsBar
/// │ (DS) Dara Sok            ✓    │
/// │ (SC) Sok Chan            ◯    │
/// └──────────────────────────────┘
/// ```
class MemberPickerPage extends StatelessWidget {
  const MemberPickerPage({
    super.key,
    this.mode = MemberPickerMode.newChat,
    this.conversationId,
    this.excludeIds = const {},
  });

  final MemberPickerMode mode;

  /// addMembers: the group to add to, and who is already in it.
  final String? conversationId;
  final Set<String> excludeIds;

  bool get _selectable => mode != MemberPickerMode.newChat;

  String get _title => switch (mode) {
    MemberPickerMode.newChat => 'New chat',
    MemberPickerMode.newGroup => 'New group',
    MemberPickerMode.addMembers => 'Add members',
  };

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => MemberPickerViewModelBloc(
        getIt<ChatRepository>(),
        excludeIds: excludeIds,
      )..add(OnPickerLoadEvent()),
      child: Scaffold(
        appBar: AppBar(
          title: AppLabel(
            text: _title,
            fontSize: AppFontSize.value20,
            fontWeight: FontWeight.w700,
          ),
          actions: [
            if (_selectable)
              BlocBuilder<
                MemberPickerViewModelBloc,
                MemberPickerViewModelState
              >(
                builder: (context, state) {
                  final data = state.data;
                  if (data?.isSubmitting ?? false) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  }
                  final count = data?.selected.length ?? 0;
                  return TextButton(
                    onPressed: count == 0 ? null : () => _next(context),
                    child: AppLabel(
                      text: mode == MemberPickerMode.newGroup
                          ? 'Next'
                          : 'Add${count > 0 ? ' ($count)' : ''}',
                      fontSize: AppFontSize.value16,
                      fontWeight: FontWeight.w700,
                    ),
                  );
                },
              ),
          ],
        ),
        body:
            BlocConsumer<MemberPickerViewModelBloc, MemberPickerViewModelState>(
              // Only the page on TOP reacts (the name page shares this bloc).
              listenWhen: (previous, current) =>
                  (current is MemberPickerDoneState ||
                      current is MemberPickerSubmitFailedState) &&
                  (ModalRoute.of(context)?.isCurrent ?? false),
              listener: (context, state) {
                if (state is MemberPickerDoneState) {
                  Navigator.of(context).pop(state.conversation);
                } else if (state is MemberPickerSubmitFailedState) {
                  AppSnackBar.error(
                    context,
                    title: state.error.title,
                    message: state.error.description,
                  );
                }
              },
              buildWhen: (previous, current) =>
                  previous.runtimeType != current.runtimeType ||
                  previous.data != current.data,
              builder: (context, state) {
                final bloc = context.read<MemberPickerViewModelBloc>();
                final data = state.data;
                if (data == null) {
                  return state is MemberPickerErrorState
                      ? AppErrorView.fromError(
                          state.error,
                          onRetry: () => bloc.add(OnPickerLoadEvent()),
                        )
                      : const Center(child: CircularProgressIndicator());
                }
                final busy = data.isSubmitting;
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Column(
                      children: [
                        if (state is MemberPickerErrorState)
                          AppErrorBanner(
                            error: state.error,
                            onRetry: () async => bloc.add(OnPickerLoadEvent()),
                          ),
                        PickerSearchField(
                          onChanged: (q) => bloc.add(OnPickerSearchEvent(q)),
                        ),
                        if (_selectable && data.selected.isNotEmpty)
                          SelectedContactsBar(
                            selected: data.selected,
                            onRemove: busy
                                ? null
                                : (c) => bloc.add(OnPickerToggleEvent(c)),
                          ),
                        if (busy && !_selectable)
                          const LinearProgressIndicator(minHeight: 2),
                        Expanded(
                          child: ContactList(
                            contacts: data.visible,
                            isLoadingMore: data.isLoadingMore,
                            selectable: _selectable,
                            isSelected: data.isSelected,
                            header:
                                mode == MemberPickerMode.newChat &&
                                    data.query.trim().isEmpty
                                ? PickerNewGroupTile(
                                    onTap: () => _openNewGroup(context),
                                  )
                                : null,
                            onTap: busy
                                ? null
                                : (c) => bloc.add(
                                    _selectable
                                        ? OnPickerToggleEvent(c)
                                        : OnPickerCreateDirectEvent(c),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      ),
    );
  }

  /// "Next" (new group) → the name page, or "Add" (add members).
  Future<void> _next(BuildContext context) async {
    final bloc = context.read<MemberPickerViewModelBloc>();
    if (mode == MemberPickerMode.addMembers) {
      bloc.add(OnPickerAddMembersEvent(conversationId!));
      return;
    }
    final created = await ConfigRouter.pushPageAnimation<ConversationModel>(
      context,
      BlocProvider.value(value: bloc, child: const NewGroupPage()),
    );
    if (created != null && context.mounted) {
      Navigator.of(context).pop(created); // hand it back to the inbox
    }
  }

  /// "New group" row → a fresh picker in group mode; pass its result back.
  Future<void> _openNewGroup(BuildContext context) async {
    final created = await ConfigRouter.pushPageAnimation<ConversationModel>(
      context,
      const MemberPickerPage(mode: MemberPickerMode.newGroup),
    );
    if (created != null && context.mounted) {
      Navigator.of(context).pop(created);
    }
  }
}
