import 'package:collection/collection.dart';

import 'package:erp_mobile/features/notifications/models/notification_model.dart';

/// Inputs to [NotificationInboxViewModel] (Slice 2.3.1).
///
/// Sealed union — adding a new event is one subclass + one `on<...>`
/// handler. `NotificationInboxUpdated` / `NotificationInboxFailed` are
/// fired by the bloc's own subscription to the repository's watch stream
/// (the UI doesn't dispatch them directly — that's the bloc's concern).
sealed class NotificationInboxEvent {
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
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationInboxStarted && runtimeType == other.runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;
}

class NotificationInboxMarkedRead extends NotificationInboxEvent {
  const NotificationInboxMarkedRead(this.id);
  final String id;
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationInboxMarkedRead &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => Object.hash(runtimeType, id);
}

class NotificationInboxMarkedAllRead extends NotificationInboxEvent {
  const NotificationInboxMarkedAllRead();
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationInboxMarkedAllRead &&
          runtimeType == other.runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;
}

class NotificationInboxDismissed extends NotificationInboxEvent {
  const NotificationInboxDismissed(this.id);
  final String id;
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationInboxDismissed &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => Object.hash(runtimeType, id);
}

class NotificationInboxUpdated extends NotificationInboxEvent {
  const NotificationInboxUpdated(this.notifications);
  final List<AppNotification> notifications;
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationInboxUpdated &&
          runtimeType == other.runtimeType &&
          const ListEquality<AppNotification>()
              .equals(notifications, other.notifications);

  @override
  int get hashCode => Object.hash(
        runtimeType,
        const ListEquality<AppNotification>().hash(notifications),
      );
}

class NotificationInboxFailed extends NotificationInboxEvent {
  const NotificationInboxFailed(this.message);
  final String message;
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationInboxFailed &&
          runtimeType == other.runtimeType &&
          message == other.message;

  @override
  int get hashCode => Object.hash(runtimeType, message);
}
