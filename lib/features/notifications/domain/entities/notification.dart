import 'package:collection/collection.dart';

/// One notification in the user's inbox (Slice 2.3.1).
///
/// Named `AppNotification` (not `Notification`) to avoid shadowing the
/// Flutter framework's `Notification` widget class — feature code that
/// imports both wins.
///
/// **Pure data**: no Flutter. The DAO maps its in-memory row ↔
/// `AppNotification` at the boundary; the bloc + UI work with this
/// type alone.
///
/// **Categories** are free-form strings — the server can introduce new
/// ones without a client schema bump. The UI maps unknown categories
/// to a generic icon.
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

  /// Discriminator like `'invoice'`, `'leave-request'`, `'system'` —
  /// drives icon / colour selection in the inbox UI.
  final String category;

  /// Optional `go_router` named route for the deep-link target.
  /// `null` means the notification is informational only.
  final String? routeName;

  /// Path parameters for the deep-link target. Empty when the route
  /// has no params (or [routeName] is null).
  final Map<String, String> pathParameters;

  /// When the notification was first emitted (server / push timestamp).
  final DateTime receivedAt;

  /// `null` when unread. Set the first time the user opens the row.
  final DateTime? readAt;

  /// Tombstone — true when the user swiped to dismiss. Kept (not
  /// deleted) so a future "show dismissed" toggle can restore.
  final bool dismissed;

  /// Convenience predicate — `true` iff the user hasn't opened it yet.
  /// Dismissal is independent: a dismissed row can still be unread.
  bool get isUnread => readAt == null;

  /// `true` iff a tap on this notification should trigger navigation.
  bool get hasDeepLink => routeName != null;

  static const Object _undefined = Object();

  AppNotification copyWith({
    String? id,
    String? title,
    String? body,
    String? category,
    Object? routeName = _undefined,
    Map<String, String>? pathParameters,
    DateTime? receivedAt,
    Object? readAt = _undefined,
    bool? dismissed,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      category: category ?? this.category,
      routeName: identical(routeName, _undefined)
          ? this.routeName
          : routeName as String?,
      pathParameters: pathParameters ?? this.pathParameters,
      receivedAt: receivedAt ?? this.receivedAt,
      readAt: identical(readAt, _undefined) ? this.readAt : readAt as DateTime?,
      dismissed: dismissed ?? this.dismissed,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppNotification &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          body == other.body &&
          category == other.category &&
          routeName == other.routeName &&
          const MapEquality<String, String>()
              .equals(pathParameters, other.pathParameters) &&
          receivedAt == other.receivedAt &&
          readAt == other.readAt &&
          dismissed == other.dismissed;

  @override
  int get hashCode => Object.hash(
        runtimeType,
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
