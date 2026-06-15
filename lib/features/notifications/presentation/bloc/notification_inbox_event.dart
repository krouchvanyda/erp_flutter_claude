import '../../domain/entities/notification.dart';

/// Inputs to [NotificationInboxBloc] (Slice 2.3.1).
///
/// Plain Dart 3 `sealed class` (was `freezed`). Factory redirects preserve
/// `NotificationInboxEvent.started()` etc.; the bloc's `on<...>` handlers
/// match the subtypes.
sealed class NotificationInboxEvent {
  const NotificationInboxEvent();

  const factory NotificationInboxEvent.started() = NotificationInboxStarted;
  const factory NotificationInboxEvent.markedRead(String id) =
      NotificationInboxMarkedRead;
  const factory NotificationInboxEvent.markedAllRead() =
      NotificationInboxMarkedAllRead;
  const factory NotificationInboxEvent.dismissed(String id) =
      NotificationInboxDismissed;
  const factory NotificationInboxEvent.inboxUpdated(
    List<AppNotification> notifications,
  ) = NotificationInboxUpdated;
  const factory NotificationInboxEvent.inboxFailed(String message) =
      NotificationInboxFailed;
}

class NotificationInboxStarted extends NotificationInboxEvent {
  const NotificationInboxStarted();
}

class NotificationInboxMarkedRead extends NotificationInboxEvent {
  const NotificationInboxMarkedRead(this.id);
  final String id;
}

class NotificationInboxMarkedAllRead extends NotificationInboxEvent {
  const NotificationInboxMarkedAllRead();
}

class NotificationInboxDismissed extends NotificationInboxEvent {
  const NotificationInboxDismissed(this.id);
  final String id;
}

class NotificationInboxUpdated extends NotificationInboxEvent {
  const NotificationInboxUpdated(this.notifications);
  final List<AppNotification> notifications;
}

class NotificationInboxFailed extends NotificationInboxEvent {
  const NotificationInboxFailed(this.message);
  final String message;
}
