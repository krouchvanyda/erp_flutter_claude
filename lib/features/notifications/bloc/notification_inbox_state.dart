import 'package:collection/collection.dart';

import '../../domain/entities/notification.dart';

/// State machine for [NotificationInboxBloc] (Slice 2.3.1).
///
/// Plain Dart 3 `sealed class` (was `freezed`). Factory redirects preserve
/// `NotificationInboxState.loaded(...)` etc.; the view switches on the
/// subtypes. Value `==`/`hashCode` are kept so `BlocBuilder` dedupes
/// rebuilds correctly.
sealed class NotificationInboxState {
  const NotificationInboxState();

  const factory NotificationInboxState.initial() = NotificationInboxInitial;
  const factory NotificationInboxState.loading() = NotificationInboxLoading;
  const factory NotificationInboxState.loaded({
    required List<AppNotification> notifications,
    required int unreadCount,
  }) = NotificationInboxLoaded;
  const factory NotificationInboxState.failure(String message) =
      NotificationInboxFailure;
}

class NotificationInboxInitial extends NotificationInboxState {
  const NotificationInboxInitial();

  @override
  bool operator ==(Object other) => other is NotificationInboxInitial;
  @override
  int get hashCode => (NotificationInboxInitial).hashCode;
}

class NotificationInboxLoading extends NotificationInboxState {
  const NotificationInboxLoading();

  @override
  bool operator ==(Object other) => other is NotificationInboxLoading;
  @override
  int get hashCode => (NotificationInboxLoading).hashCode;
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
      (other is NotificationInboxLoaded &&
          other.unreadCount == unreadCount &&
          const ListEquality<AppNotification>()
              .equals(other.notifications, notifications));

  @override
  int get hashCode => Object.hash(
        unreadCount,
        const ListEquality<AppNotification>().hash(notifications),
      );
}

class NotificationInboxFailure extends NotificationInboxState {
  const NotificationInboxFailure(this.message);
  final String message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NotificationInboxFailure && other.message == message);
  @override
  int get hashCode => message.hashCode;
}
