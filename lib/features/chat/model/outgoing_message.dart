/// A text I typed that the server has NOT confirmed yet.
///
/// ```
/// tap ➤ ──► OutgoingMessage(failed: false)  🕓 "sending"
///             ├─ server OK   ──► removed; the server's MessageModel takes its place ✓
///             └─ server fail ──► failed: true  ⚠ "Not sent · Retry"
/// ```
///
/// Kept apart from [MessageModel] on purpose: a MessageModel is always what
/// the SERVER has (a real id). This has only a [localId] made on the phone.
class OutgoingMessage {
  const OutgoingMessage({
    required this.localId,
    required this.text,
    required this.createdAt,
    this.failed = false,
  });

  /// "local-3" — unique on this phone, never sent to the server.
  final String localId;
  final String text;
  final DateTime createdAt;
  final bool failed;

  OutgoingMessage copyWith({bool? failed}) => OutgoingMessage(
    localId: localId,
    text: text,
    createdAt: createdAt,
    failed: failed ?? this.failed,
  );

  @override
  bool operator ==(Object other) =>
      other is OutgoingMessage &&
      other.localId == localId &&
      other.text == text &&
      other.createdAt == createdAt &&
      other.failed == failed;

  @override
  int get hashCode => Object.hash(localId, text, createdAt, failed);

  /// No message text in logs (private).
  @override
  String toString() => 'OutgoingMessage($localId, failed: $failed)';
}
