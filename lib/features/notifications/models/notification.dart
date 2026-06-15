import 'package:collection/collection.dart';

/// One notification in the user's inbox (Slice 2.3.1).
///
/// Named `AppNotification` (not `Notification`) to avoid shadowing the
/// Flutter framework's `Notification` widget class.
///
/// **Pure data**: no Flutter, no drift. Plain immutable value type (was
/// `freezed`; the codegen was removed).
class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    this.routeName,
    this.pathParameters = const <String, String>{},
    required this.receivedAt,
    this.readAt,
    this.dismissed = false,
  });

  final String id;
  final String title;
  final String body;

  /// Discriminator like `'invoice'`, `'leave-request'`, `'system'`.
  final String category;

  /// Optional `go_router` named route for the deep-link target.
  final String? routeName;

  /// Path parameters for the deep-link target.
  final Map<String, String> pathParameters;

  /// When the notification was first emitted.
  final DateTime receivedAt;

  /// `null` when unread.
  final DateTime? readAt;

  /// Tombstone — true when the user swiped to dismiss.
  final bool dismissed;

  /// `true` iff the user hasn't opened it yet.
  bool get isUnread => readAt == null;

  /// `true` iff a tap should trigger navigation.
  bool get hasDeepLink => routeName != null;

  AppNotification copyWith({
    String? id,
    String? title,
    String? body,
    String? category,
    String? routeName,
    Map<String, String>? pathParameters,
    DateTime? receivedAt,
    DateTime? readAt,
    bool? dismissed,
  }) =>
      AppNotification(
        id: id ?? this.id,
        title: title ?? this.title,
        body: body ?? this.body,
        category: category ?? this.category,
        routeName: routeName ?? this.routeName,
        pathParameters: pathParameters ?? this.pathParameters,
        receivedAt: receivedAt ?? this.receivedAt,
        readAt: readAt ?? this.readAt,
        dismissed: dismissed ?? this.dismissed,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppNotification &&
          other.id == id &&
          other.title == title &&
          other.body == body &&
          other.category == category &&
          other.routeName == routeName &&
          const MapEquality<String, String>()
              .equals(other.pathParameters, pathParameters) &&
          other.receivedAt == receivedAt &&
          other.readAt == readAt &&
          other.dismissed == dismissed);

  @override
  int get hashCode => Object.hash(
        id,
        title,
        body,
        category,
        routeName,
        const MapEquality<String, String>().hash(pathParameters),
        receivedAt,
        readAt,
        dismissed,
      );
}
