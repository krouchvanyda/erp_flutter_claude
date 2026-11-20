part of 'conversation_view_model_bloc.dart';

@immutable
sealed class ConversationViewModelEvent {}

/// Page opened, or "Try again" → page 1 (the latest messages).
///
/// [done] is completed when the load has finished (same idea as the inbox:
/// an unchanged list emits no new state).
final class OnConversationLoadEvent extends ConversationViewModelEvent {
  OnConversationLoadEvent({this.done});

  final Completer<void>? done;
}

/// Scrolled near the TOP (the oldest message) → the next older page.
final class OnConversationLoadOlderEvent extends ConversationViewModelEvent {}

/// ➤ tapped. Blank text is ignored.
final class OnMessageSendEvent extends ConversationViewModelEvent {
  OnMessageSendEvent(this.text);

  final String text;
}

/// "Not sent · Retry" tapped on a failed bubble.
final class OnMessageRetryEvent extends ConversationViewModelEvent {
  OnMessageRetryEvent(this.localId);

  final String localId;
}

/// A live change from the server (Step 5.3), from
/// `ChatRepository.conversationUpdates(id)`. Added by the bloc itself.
final class OnConversationLiveUpdateEvent extends ConversationViewModelEvent {
  OnConversationLiveUpdateEvent(this.update);

  final ChatUpdate update;
}

/// Send a photo / PDF / voice note (Step 5.5). [filePath] is on the phone;
/// VOICE needs [durationSeconds].
final class OnAttachmentSendEvent extends ConversationViewModelEvent {
  OnAttachmentSendEvent({
    required this.type,
    required this.filePath,
    this.durationSeconds,
  });

  final MessageType type;
  final String filePath;
  final int? durationSeconds;
}

// ─────────────── Step 5.6: message actions ───────────────

/// Long-press → ✎ Edit: the composer switches to edit mode.
final class OnMessageEditStartEvent extends ConversationViewModelEvent {
  OnMessageEditStartEvent(this.message);

  final MessageModel message;
}

/// ✕ on the "Editing" banner.
final class OnMessageEditCancelEvent extends ConversationViewModelEvent {}

/// ➤ in edit mode → save the new text.
final class OnMessageEditSubmitEvent extends ConversationViewModelEvent {
  OnMessageEditSubmitEvent(this.body);

  final String body;
}

/// Long-press → 🗑 Delete (after "Are you sure?").
final class OnMessageDeleteEvent extends ConversationViewModelEvent {
  OnMessageDeleteEvent(this.messageId);

  final String messageId;
}

/// Tap an emoji (sheet or chip) → add / remove MY reaction.
final class OnReactionToggleEvent extends ConversationViewModelEvent {
  OnReactionToggleEvent(this.messageId, this.emoji);

  final String messageId;
  final String emoji;
}
