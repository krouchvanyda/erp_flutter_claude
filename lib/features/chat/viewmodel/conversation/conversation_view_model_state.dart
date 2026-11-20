part of 'conversation_view_model_bloc.dart';

@immutable
sealed class ConversationViewModelState {
  /// The messages to draw, if any (Loaded → itself, Error → the last ones).
  ConversationLoadedState? get data => null;
}

final class ConversationViewModelInitial extends ConversationViewModelState {}

/// First load → full-page spinner.
final class ConversationLoadingState extends ConversationViewModelState {}

final class ConversationLoadedState extends ConversationViewModelState {
  ConversationLoadedState({
    required this.messages,
    this.outgoing = const [],
    required this.page,
    required this.hasMore,
    this.isLoadingOlder = false,
    this.editing,
  });

  /// What the SERVER has, NEWEST first (index 0 = the bottom bubble).
  final List<MessageModel> messages;

  /// What I typed and the server hasn't confirmed yet, newest first.
  /// Drawn BELOW [messages] (they are newer).
  final List<OutgoingMessage> outgoing;

  /// The last page loaded (1-based) and whether older pages exist.
  final int page;
  final bool hasMore;

  /// Older page on its way → small spinner at the TOP.
  final bool isLoadingOlder;

  /// The message I'm editing (the composer shows "✎ Editing") — 5.6.
  final MessageModel? editing;

  @override
  ConversationLoadedState get data => this;

  ConversationLoadedState copyWith({
    List<MessageModel>? messages,
    List<OutgoingMessage>? outgoing,
    int? page,
    bool? hasMore,
    bool? isLoadingOlder,
    MessageModel? editing,
    bool clearEditing = false,
  }) => ConversationLoadedState(
    messages: messages ?? this.messages,
    outgoing: outgoing ?? this.outgoing,
    page: page ?? this.page,
    hasMore: hasMore ?? this.hasMore,
    isLoadingOlder: isLoadingOlder ?? this.isLoadingOlder,
    editing: clearEditing ? null : (editing ?? this.editing),
  );

  static const _messagesEq = ListEquality<MessageModel>();
  static const _outgoingEq = ListEquality<OutgoingMessage>();

  @override
  bool operator ==(Object other) =>
      other is ConversationLoadedState &&
      _messagesEq.equals(other.messages, messages) &&
      _outgoingEq.equals(other.outgoing, outgoing) &&
      other.page == page &&
      other.hasMore == hasMore &&
      other.isLoadingOlder == isLoadingOlder &&
      other.editing == editing;

  @override
  int get hashCode => Object.hash(
    _messagesEq.hash(messages),
    _outgoingEq.hash(outgoing),
    page,
    hasMore,
    isLoadingOlder,
    editing,
  );

  @override
  String toString() =>
      'ConversationLoadedState(${messages.length} msgs, '
      '${outgoing.length} outgoing, page $page)';
}

/// A LOAD failed (sending never makes this state: a failed send only marks
/// its own bubble).
/// - [lastData] null → nothing to show → AppErrorView + "Try again".
/// - [lastData] set  → keep the messages + AppErrorBanner on top.
final class ConversationErrorState extends ConversationViewModelState {
  ConversationErrorState({required this.error, this.lastData});

  final NetworkErrorModel error;
  final ConversationLoadedState? lastData;

  @override
  ConversationLoadedState? get data =>
      lastData?.copyWith(isLoadingOlder: false);
}

/// Edit / delete / reaction failed (403 "Can only edit own messages",
/// "Edit window has expired", offline…) → the page shows a snackbar.
/// The messages stay ([lastData]).
final class ConversationActionFailedState extends ConversationViewModelState {
  ConversationActionFailedState({required this.error, required this.lastData});

  final NetworkErrorModel error;
  final ConversationLoadedState lastData;

  @override
  ConversationLoadedState get data => lastData;
}
