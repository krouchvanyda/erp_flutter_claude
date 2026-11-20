import 'chat_enums.dart';

/// Something I sent that the server has NOT confirmed yet.
///
/// ```
/// text:        🕓 sending ─► server OK → replaced by the server's MessageModel ✓
/// attachment:  ◔ uploading (progress) ─► uploadedUrl set ─► 🕓 sending ─► ✓
///              any failure → failed ⚠ "Not sent · Tap to retry"
///              retry: uploadedUrl already there → skip the upload
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
    this.type = MessageType.text,
    this.localPath,
    this.contentType,
    this.sizeBytes,
    this.durationSeconds,
    this.progress,
    this.uploadedUrl,
  });

  /// "local-3" — unique on this phone, never sent to the server.
  final String localId;
  final String text; // '' for attachments
  final DateTime createdAt;
  final bool failed;

  // ── attachments (Step 5.5) ──
  final MessageType type;

  /// The file on THIS phone (shown at once: my photo, my voice note).
  final String? localPath;
  final String? contentType;
  final int? sizeBytes;
  final int? durationSeconds; // voice

  /// 0.0–1.0 while uploading; null when not uploading.
  final double? progress;

  /// Set once the upload worked → a retry only re-sends the message.
  final String? uploadedUrl;

  bool get isAttachment => type != MessageType.text;

  OutgoingMessage copyWith({
    bool? failed,
    double? progress,
    bool clearProgress = false,
    String? uploadedUrl,
    String? contentType,
    int? sizeBytes,
  }) => OutgoingMessage(
    localId: localId,
    text: text,
    createdAt: createdAt,
    failed: failed ?? this.failed,
    type: type,
    localPath: localPath,
    contentType: contentType ?? this.contentType,
    sizeBytes: sizeBytes ?? this.sizeBytes,
    durationSeconds: durationSeconds,
    progress: clearProgress ? null : (progress ?? this.progress),
    uploadedUrl: uploadedUrl ?? this.uploadedUrl,
  );

  @override
  bool operator ==(Object other) =>
      other is OutgoingMessage &&
      other.localId == localId &&
      other.text == text &&
      other.createdAt == createdAt &&
      other.failed == failed &&
      other.type == type &&
      other.localPath == localPath &&
      other.contentType == contentType &&
      other.sizeBytes == sizeBytes &&
      other.durationSeconds == durationSeconds &&
      other.progress == progress &&
      other.uploadedUrl == uploadedUrl;

  @override
  int get hashCode => Object.hash(
    localId,
    text,
    createdAt,
    failed,
    type,
    localPath,
    contentType,
    sizeBytes,
    durationSeconds,
    progress,
    uploadedUrl,
  );

  /// No message text / file path in logs (private).
  @override
  String toString() =>
      'OutgoingMessage($localId, ${type.name}, failed: $failed)';
}
