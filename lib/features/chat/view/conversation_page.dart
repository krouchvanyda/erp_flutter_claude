import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/audio/app_audio_player.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/router/config_router.dart';
import '../../../core/widgets/app_error_banner.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/app_confirm_dialog.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../model/chat_call_launcher.dart';
import '../model/chat_enums.dart';
import '../model/conversation_model.dart';
import '../model/message_model.dart';
import '../repository/chat_repository.dart';
import '../repository/presence_store.dart';
import '../viewmodel/conversation/conversation_view_model_bloc.dart';
import '../viewmodel/conversation_info/conversation_info_view_model_bloc.dart';
import '../viewmodel/typing/typing_view_model_bloc.dart';
import '../widgets/chat_composer.dart';
import '../widgets/conversation_app_bar_title.dart';
import '../widgets/conversation_call_buttons.dart';
import '../widgets/conversation_empty_view.dart';
import '../widgets/message_actions_sheet.dart';
import '../widgets/message_list.dart';
import 'conversation_info_page.dart';
import 'conversation_search_page.dart';

/// One conversation (Step 5.2). Layout only.
///
/// ```
/// ┌ ← (JD) Jane Doe ─────────────┐
/// │ [AppErrorBanner]  (load failed, messages kept)
/// │ MessageList / empty / spinner / AppErrorView
/// ├──────────────────────────────┤
/// │ ChatComposer                  │  ← disabled until the first load works
/// └──────────────────────────────┘
/// ```
///
/// Gets the [conversation] from the inbox: it already has the title, the
/// avatar and the members (names in groups) → no extra request.
class ConversationPage extends StatelessWidget {
  const ConversationPage({
    super.key,
    required this.conversation,
    required this.myId,
    this.calls,
  });

  final ConversationModel conversation;
  final String? myId;

  /// 📞 / 🎥 (Step 6) — from `app/` through the inbox; null → hidden.
  final ChatCallLauncher? calls;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        // Built here, not with a getIt factory: they need THIS conversation.
        BlocProvider(
          create: (_) => ConversationViewModelBloc(
            getIt<ChatRepository>(),
            conversationId: conversation.id,
            myId: myId,
          )..add(OnConversationLoadEvent()),
        ),
        // The CURRENT name / members (5.4): the title, the names in group
        // bubbles, and the info page all read it.
        // "Dara is typing…" — in and out (5.6).
        BlocProvider(
          create: (_) => TypingViewModelBloc(
            getIt<ChatRepository>(),
            conversationId: conversation.id,
            myId: myId,
          ),
        ),
        BlocProvider(
          create: (_) => ConversationInfoViewModelBloc(
            getIt<ChatRepository>(),
            conversation: conversation,
            myId: myId,
            presence: getIt<PresenceStore>(),
          ),
        ),
      ],
      child: BlocListener<ConversationInfoViewModelBloc, ConversationInfoViewModelState>(
        // Left / deleted / removed → close the chat (and the info page on
        // top of it) and say why.
        listenWhen: (previous, current) => current is ConversationInfoGoneState,
        listener: (context, state) {
          if (state is! ConversationInfoGoneState) return;
          // The inbox (AuthGate's home) is the first route.
          Navigator.of(context).popUntil((route) => route.isFirst);
          final name = state.conversation.title(myId);
          switch (state.reason) {
            case ConversationGoneReason.left:
              AppSnackBar.success(context, message: 'You left “$name”.');
            case ConversationGoneReason.deleted:
              AppSnackBar.success(context, message: '“$name” was deleted.');
            case ConversationGoneReason.removed:
              AppSnackBar.warning(
                context,
                message: 'You are no longer in “$name”.',
              );
          }
        },
        // Leaving the chat (back, or closed because it's gone) → stop a
        // voice message that is still playing.
        child: PopScope(
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) getIt<AppAudioPlayer>().stop();
          },
          child: Scaffold(
            appBar: AppBar(
              titleSpacing: 0,
              actions: [
                // 📞 🎥 call (6.1) — the CURRENT conversation (name, members)
                if (calls case final calls?)
                  Builder(
                    builder: (context) => ConversationCallButtons(
                      calls: calls,
                      conversation: context
                          .select<
                            ConversationInfoViewModelBloc,
                            ConversationModel
                          >((b) => b.state.conversation),
                      myId: myId,
                    ),
                  ),
                // 🔍 search this chat (5.6)
                Builder(
                  builder: (context) => IconButton(
                    tooltip: 'Search',
                    onPressed: () => ConfigRouter.pushPageAnimation<void>(
                      context,
                      ConversationSearchPage(
                        conversation: context
                            .read<ConversationInfoViewModelBloc>()
                            .state
                            .conversation,
                        myId: myId,
                      ),
                    ),
                    icon: const Icon(Icons.search_rounded),
                  ),
                ),
              ],
              // Tap the title → chat info. Live name / member changes show here.
              title:
                  BlocBuilder<
                    ConversationInfoViewModelBloc,
                    ConversationInfoViewModelState
                  >(
                    buildWhen: (previous, current) =>
                        previous.conversation != current.conversation,
                    builder: (context, info) => InkWell(
                      onTap: () => ConfigRouter.pushPageAnimation<void>(
                        context,
                        BlocProvider.value(
                          value: context.read<ConversationInfoViewModelBloc>(),
                          child: ConversationInfoPage(myId: myId),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child:
                            BlocBuilder<
                              TypingViewModelBloc,
                              TypingViewModelState
                            >(
                              // + "online" / "last seen 10:42" (5.6)
                              builder: (context, typing) =>
                                  ValueListenableBuilder(
                                    valueListenable:
                                        getIt<PresenceStore>().presence,
                                    builder: (context, presence, _) =>
                                        ConversationAppBarTitle(
                                          conversation: info.conversation,
                                          myId: myId,
                                          presenceText: presenceLine(
                                            presence[info.conversation
                                                .otherMember(myId)
                                                ?.userId],
                                          ),
                                          typingNames: [
                                            for (final m
                                                in info.conversation.members)
                                              if (typing.userIds.contains(
                                                m.userId,
                                              ))
                                                m.displayName,
                                          ],
                                        ),
                                  ),
                            ),
                      ),
                    ),
                  ),
            ),
            body: SafeArea(
              top: false,
              child:
                  BlocConsumer<
                    ConversationViewModelBloc,
                    ConversationViewModelState
                  >(
                    // edit / delete / reaction failed → say why (the messages stay)
                    listenWhen: (previous, current) =>
                        current is ConversationActionFailedState,
                    listener: (context, state) {
                      if (state is ConversationActionFailedState) {
                        AppSnackBar.error(
                          context,
                          title: state.error.title,
                          message: state.error.description,
                        );
                      }
                    },
                    buildWhen: (previous, current) =>
                        previous.runtimeType != current.runtimeType ||
                        previous.data != current.data, // Loaded has ==
                    builder: (context, state) {
                      final bloc = context.read<ConversationViewModelBloc>();
                      final data = state.data;

                      // "Try again" waits for "finished" (see the inbox lesson).
                      Future<void> reload() {
                        final done = Completer<void>();
                        bloc.add(OnConversationLoadEvent(done: done));
                        return done.future;
                      }

                      final Widget content;
                      if (data == null) {
                        content = state is ConversationErrorState
                            ? AppErrorView.fromError(
                                state.error,
                                onRetry: reload,
                              )
                            : const Center(child: CircularProgressIndicator());
                      } else if (data.messages.isEmpty &&
                          data.outgoing.isEmpty) {
                        content = const ConversationEmptyView();
                      } else {
                        content = MessageList(
                          messages: data.messages,
                          outgoing: data.outgoing,
                          myId: myId,
                          isGroup: conversation.isGroup,
                          // current members (a new member's name shows)
                          members: context
                              .select<
                                ConversationInfoViewModelBloc,
                                ConversationModel
                              >((b) => b.state.conversation)
                              .members,
                          isLoadingOlder: data.isLoadingOlder,
                          onLoadOlder: () =>
                              bloc.add(OnConversationLoadOlderEvent()),
                          onLongPress: (message) =>
                              _showActions(context, message),
                          onReact: (messageId, emoji) =>
                              bloc.add(OnReactionToggleEvent(messageId, emoji)),
                          onRetry: (localId) =>
                              bloc.add(OnMessageRetryEvent(localId)),
                          audioPlayer: getIt<AppAudioPlayer>(),
                        );
                      }

                      return Column(
                        children: [
                          AnimatedSize(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            alignment: Alignment.topCenter,
                            child:
                                state is ConversationErrorState && data != null
                                ? Center(
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: MessageList.maxWidth,
                                      ),
                                      child: AppErrorBanner(
                                        error: state.error,
                                        onRetry: reload,
                                      ),
                                    ),
                                  )
                                : const SizedBox(width: double.infinity),
                          ),
                          Expanded(child: content),
                          Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxWidth: MessageList.maxWidth,
                              ),
                              child: ChatComposer(
                                enabled: data != null,
                                // edit mode (5.6): the banner + the old text
                                editingText: data?.editing?.body,
                                onSubmitEdit: (text) =>
                                    bloc.add(OnMessageEditSubmitEvent(text)),
                                onCancelEdit: () =>
                                    bloc.add(OnMessageEditCancelEvent()),
                                onSend: (text) {
                                  context.read<TypingViewModelBloc>().add(
                                    OnTypingStopEvent(),
                                  );
                                  bloc.add(OnMessageSendEvent(text));
                                },
                                onTextChanged: (text) => context
                                    .read<TypingViewModelBloc>()
                                    .add(OnTypingTextChangedEvent(text)),
                                onAttach: (type, path) => bloc.add(
                                  OnAttachmentSendEvent(
                                    type: type,
                                    filePath: path,
                                  ),
                                ),
                                onVoice: (path, seconds) => bloc.add(
                                  OnAttachmentSendEvent(
                                    type: MessageType.voice,
                                    filePath: path,
                                    durationSeconds: seconds,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
            ),
          ),
        ),
      ),
    );
  }

  /// Long-press a message → the sheet → do what was picked.
  Future<void> _showActions(BuildContext context, MessageModel message) async {
    final bloc = context.read<ConversationViewModelBloc>();
    final members = context
        .read<ConversationInfoViewModelBloc>()
        .state
        .conversation
        .members;
    final mine = message.senderId == myId;
    final isText = message.type == MessageType.text;

    // "Seen by Dara, Jane" (group) / "Seen" (direct) — only for mine
    String? seenBy;
    if (mine && message.readByUserIds.isNotEmpty) {
      final names = [
        for (final m in members)
          if (message.readByUserIds.contains(m.userId))
            m.displayName.split(' ').first,
      ];
      seenBy = conversation.isGroup && names.isNotEmpty
          ? 'Seen by ${names.join(', ')}'
          : 'Seen';
    }

    final choice = await MessageActionsSheet.show(
      context,
      myEmojis: {
        for (final r in message.reactions)
          if (r.userId == myId) r.emoji,
      },
      canReact: !message.deleted,
      canCopy: isText && (message.body ?? '').isNotEmpty,
      canEdit: bloc.canEdit(message),
      canDelete: mine && !message.deleted,
      seenBy: seenBy,
    );
    if (choice == null || !context.mounted) return;

    switch (choice) {
      case ReactChoice(:final emoji):
        bloc.add(OnReactionToggleEvent(message.id, emoji));
      case CopyChoice():
        await Clipboard.setData(ClipboardData(text: message.body ?? ''));
        if (context.mounted) AppSnackBar.info(context, message: 'Copied.');
      case EditChoice():
        bloc.add(OnMessageEditStartEvent(message));
      case DeleteChoice():
        final yes = await AppConfirmDialog.show(
          context,
          title: 'Delete message?',
          message: 'It will be deleted for everyone in this chat.',
          confirmText: 'Delete',
          icon: Icons.delete_outline_rounded,
          destructive: true,
        );
        if (yes) bloc.add(OnMessageDeleteEvent(message.id));
    }
  }
}
