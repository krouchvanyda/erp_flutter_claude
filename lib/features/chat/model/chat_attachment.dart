import 'chat_enums.dart';

/// What `POST /chats/attachments` returns (backend `ChatAttachmentDto`).
/// [url] is a server path ("/uploads/chat/uuid.jpg") that we then send back
/// as the message's `attachmentUrl`.
class ChatAttachmentModel {
  const ChatAttachmentModel({
    required this.url,
    required this.contentType,
    required this.sizeBytes,
  });

  final String url;
  final String contentType;
  final int sizeBytes;

  factory ChatAttachmentModel.fromJson(Map<String, dynamic> json) =>
      ChatAttachmentModel(
        url: json['url'] as String? ?? '',
        contentType: json['contentType'] as String? ?? '',
        sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      );

  @override
  bool operator ==(Object other) =>
      other is ChatAttachmentModel &&
      other.url == url &&
      other.contentType == contentType &&
      other.sizeBytes == sizeBytes;

  @override
  int get hashCode => Object.hash(url, contentType, sizeBytes);

  @override
  String toString() => 'ChatAttachmentModel($contentType, $sizeBytes B)';
}

/// The backend's upload rules, in ONE place (`application.yml`
/// `uploads.chat-attachment`). Checked on the phone BEFORE uploading, so
/// the user gets a clear message instead of a 400 after a long upload.
abstract final class AttachmentRules {
  /// 25 MiB (`UPLOAD_CHAT_MAX_SIZE`).
  static const int maxBytes = 25 * 1024 * 1024;

  /// File extension → the content type the server accepts. null = not
  /// allowed. (Documents: the server accepts ONLY PDF today.)
  static String? contentTypeFor(String fileName) =>
      switch (fileName.split('.').last.toLowerCase()) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'webp' => 'image/webp',
        'gif' => 'image/gif',
        'heic' => 'image/heic',
        'm4a' || 'mp4' => 'audio/mp4', // our voice recordings (AAC)
        'aac' => 'audio/aac',
        'mp3' => 'audio/mpeg',
        'ogg' => 'audio/ogg',
        'wav' => 'audio/wav',
        'pdf' => 'application/pdf',
        _ => null,
      };

  /// null = OK; otherwise the reason to show the user.
  static String? problem({required String fileName, required int sizeBytes}) {
    if (contentTypeFor(fileName) == null) {
      return 'This file type can\'t be sent. Photos, voice and PDF only.';
    }
    if (sizeBytes > maxBytes) {
      return 'The file is ${_mb(sizeBytes)}. The limit is ${_mb(maxBytes)}.';
    }
    return null;
  }

  /// "1.2 MB", "350 KB" — for file bubbles too.
  static String sizeLabel(int bytes) {
    if (bytes >= 1024 * 1024) return _mb(bytes);
    return '${(bytes / 1024).ceil()} KB';
  }

  static String _mb(int bytes) =>
      '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

  /// The message type for a content type.
  static MessageType typeFor(String contentType) {
    if (contentType.startsWith('image/')) return MessageType.image;
    if (contentType.startsWith('audio/')) return MessageType.voice;
    return MessageType.file;
  }
}
