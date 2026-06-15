import 'package:collection/collection.dart';

/// Server-pushed notification payload (Slice 2.3.2).
///
/// A project-owned envelope that keeps the rest of the app free of the FCM
/// SDK. The shape mirrors a typical FCM payload — `notification.title/body`
/// for display + a `data` map for routing. Plain immutable value type (was
/// `freezed`; the codegen was removed).
class PushMessage {
  const PushMessage({
    this.id,
    required this.title,
    required this.body,
    this.data = const <String, String>{},
    this.sentAt,
  });

  /// Server-assigned message id (dedupe key). Null when not supplied.
  final String? id;

  /// Display title — comes from FCM's `notification.title`.
  final String title;

  /// Display body — FCM's `notification.body`.
  final String body;

  /// App-specific routing data — FCM's `data` map.
  final Map<String, String> data;

  /// When the server / push transport says the message was emitted.
  final DateTime? sentAt;

  PushMessage copyWith({
    String? id,
    String? title,
    String? body,
    Map<String, String>? data,
    DateTime? sentAt,
  }) =>
      PushMessage(
        id: id ?? this.id,
        title: title ?? this.title,
        body: body ?? this.body,
        data: data ?? this.data,
        sentAt: sentAt ?? this.sentAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PushMessage &&
          other.id == id &&
          other.title == title &&
          other.body == body &&
          const MapEquality<String, String>().equals(other.data, data) &&
          other.sentAt == sentAt);

  @override
  int get hashCode => Object.hash(
        id,
        title,
        body,
        const MapEquality<String, String>().hash(data),
        sentAt,
      );
}
