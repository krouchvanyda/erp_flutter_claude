import 'package:collection/collection.dart';

import '../../domain/entities/notification.dart';

/// State machine for [NotificationInboxBloc] (Slice 2.3.1).
///
/// **Why one `Loaded` state with a derived unread count, not separate
/// states for empty / non-empty**: the inbox view rebuilds the same
/// scaffold either way; an `if (notifications.isEmpty)` in the widget
/// is cheaper than a state-shape branch.
sealed class NotificationInboxState {
  const NotificationInboxState();

  /// Pre-subscribe — the bloc hasn't loaded the first snapshot yet.
  const factory NotificationInboxState.initial() = NotificationInboxInitial;

  /// First snapshot in flight.
  const factory NotificationInboxState.loading() = NotificationInboxLoading;

  /// Latest inbox snapshot. [notifications] is newest-first, dismissed
  /// rows already filtered. [unreadCount] is derived once at emit time
  /// rather than re-counted per UI rebuild.
  const factory NotificationInboxState.loaded({
    required List<AppNotification> notifications,
    required int unreadCount,
  }) = NotificationInboxLoaded;

  /// Watch stream errored. A typed state lets the UI render a retry
  /// hint instead of an indefinite spinner.
  const factory NotificationInboxState.failure(String message) =
      NotificationInboxFailure;
}

class NotificationInboxInitial extends NotificationInboxState {
  const NotificationInboxInitial();
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationInboxInitial && runtimeType == other.runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;
}

class NotificationInboxLoading extends NotificationInboxState {
  const NotificationInboxLoading();
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationInboxLoading && runtimeType == other.runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;
}

class NotificationInboxLoaded extends NotificationInboxState {
  const NotificationInboxLoaded({
    required this.notifications,
    required this.unreadCount,
  });

  final List<AppNotification> notifications;
  final int unreadCount;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationInboxLoaded &&
          runtimeType == other.runtimeType &&
          const ListEquality<AppNotification>()
              .equals(notifications, other.notifications) &&
          unreadCount == other.unreadCount;

  @override
  int get hashCode => Object.hash(
        runtimeType,
        const ListEquality<AppNotification>().hash(notifications),
        unreadCount,
      );
}

class NotificationInboxFailure extends NotificationInboxState {
  const NotificationInboxFailure(this.message);
  final String message;
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationInboxFailure &&
          runtimeType == other.runtimeType &&
          message == other.message;

  @override
  int get hashCode => Object.hash(runtimeType, message);
}
