import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/widgets/app_error_banner.dart';
import '../../../core/widgets/app_error_view.dart';
import '../model/conversation_model.dart';
import '../repository/chat_repository.dart';
import '../viewmodel/conversation_view_model_bloc.dart';
import '../widgets/chat_composer.dart';
import '../widgets/conversation_app_bar_title.dart';
import '../widgets/conversation_empty_view.dart';
import '../widgets/message_list.dart';

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
  });

  final ConversationModel conversation;
  final String? myId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      // Built here, not with a getIt factory: it needs THIS conversation's id.
      create: (_) => ConversationViewModelBloc(
        getIt<ChatRepository>(),
        conversationId: conversation.id,
        myId: myId,
      )..add(OnConversationLoadEvent()),
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: ConversationAppBarTitle(
            conversation: conversation,
            myId: myId,
          ),
        ),
        body: SafeArea(
          top: false,
          child:
              BlocBuilder<
                ConversationViewModelBloc,
                ConversationViewModelState
              >(
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
                        ? AppErrorView.fromError(state.error, onRetry: reload)
                        : const Center(child: CircularProgressIndicator());
                  } else if (data.messages.isEmpty && data.outgoing.isEmpty) {
                    content = const ConversationEmptyView();
                  } else {
                    content = MessageList(
                      messages: data.messages,
                      outgoing: data.outgoing,
                      myId: myId,
                      isGroup: conversation.isGroup,
                      members: conversation.members,
                      isLoadingOlder: data.isLoadingOlder,
                      onLoadOlder: () =>
                          bloc.add(OnConversationLoadOlderEvent()),
                      onRetry: (localId) =>
                          bloc.add(OnMessageRetryEvent(localId)),
                    );
                  }

                  return Column(
                    children: [
                      AnimatedSize(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.topCenter,
                        child: state is ConversationErrorState && data != null
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
                            onSend: (text) =>
                                bloc.add(OnMessageSendEvent(text)),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
        ),
      ),
    );
  }
}
