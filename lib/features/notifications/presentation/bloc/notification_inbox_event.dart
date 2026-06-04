import 'package:equatable/equatable.dart';

import '../../domain/entities/notification.dart';

/// Inputs to [NotificationInboxBloc] (Slice 2.3.1).
///
/// Sealed union — adding a new event is one subclass + one `on<...>`
/// handler. `NotificationInboxUpdated` / `NotificationInboxFailed` are
/// fired by the bloc's own subscription to the repository's watch stream
/// (the UI doesn't dispatch them directly — that's the bloc's concern).
sealed class NotificationInboxEvent extends Equatable {
  const NotificationInboxEvent();

  /// Subscribe to the repo's watch stream. Idempotent — calling twice
  /// is a no-op (the bloc tracks its own subscription).
  const factory NotificationInboxEvent.started() = NotificationInboxStarted;

  /// User opened a single notification. Drives the read flag + (later)
  /// triggers deep-link navigation outside the bloc.
  const factory NotificationInboxEvent.markedRead(String id) =
      NotificationInboxMarkedRead;

  /// "Mark all as read" toolbar action.
  const factory NotificationInboxEvent.markedAllRead() =
      NotificationInboxMarkedAllRead;

  /// Swipe-to-dismiss (or a context-menu "Dismiss"). Tombstones the row.
  const factory NotificationInboxEvent.dismissed(String id) =
      NotificationInboxDismissed;

  /// Internal: the watch stream emitted a fresh inbox snapshot. Wired
  /// by `_subscribe()` in the bloc; not for UI dispatch.
  const factory NotificationInboxEvent.inboxUpdated(
    List<AppNotification> notifications,
  ) = NotificationInboxUpdated;

  /// Internal: the watch stream errored — surfaced as a `Failure` state
  /// instead of an uncaught exception.
  const factory NotificationInboxEvent.inboxFailed(String message) =
      NotificationInboxFailed;
}

class NotificationInboxStarted extends NotificationInboxEvent {
  const NotificationInboxStarted();
  @override
  List<Object?> get props => const [];
}

class NotificationInboxMarkedRead extends NotificationInboxEvent {
  const NotificationInboxMarkedRead(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
}

class NotificationInboxMarkedAllRead extends NotificationInboxEvent {
  const NotificationInboxMarkedAllRead();
  @override
  List<Object?> get props => const [];
}

class NotificationInboxDismissed extends NotificationInboxEvent {
  const NotificationInboxDismissed(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
}

class NotificationInboxUpdated extends NotificationInboxEvent {
  const NotificationInboxUpdated(this.notifications);
  final List<AppNotification> notifications;
  @override
  List<Object?> get props => [notifications];
}

class NotificationInboxFailed extends NotificationInboxEvent {
  const NotificationInboxFailed(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}
