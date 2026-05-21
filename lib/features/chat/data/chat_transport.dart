import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as ws_status;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../entities/chat_message.dart';

/// Connection status surfaced to the UI (banner / status dot).
enum ChatTransportStatus { disconnected, connecting, connected, error }

/// Inbound event the transport hands off to the repositories.
sealed class ChatTransportEvent {
  const ChatTransportEvent();
}

/// Peer sent a new message — add to local seed without re-broadcasting.
class MessageReceivedEvent extends ChatTransportEvent {
  const MessageReceivedEvent(this.message);
  final ChatMessage message;
}

/// Peer edited a message they previously sent.
class MessageEditedEvent extends ChatTransportEvent {
  const MessageEditedEvent({required this.messageId, required this.newBody});
  final String messageId;
  final String newBody;
}

/// Peer soft-deleted a message.
class MessageDeletedEvent extends ChatTransportEvent {
  const MessageDeletedEvent(this.messageId);
  final String messageId;
}

/// Peer toggled a reaction on a message.
class ReactionToggledEvent extends ChatTransportEvent {
  const ReactionToggledEvent({
    required this.messageId,
    required this.emoji,
    required this.employeeId,
  });
  final String messageId;
  final String emoji;
  final String employeeId;
}

/// Module 10 wire transport — wraps a [WebSocketChannel] connected to
/// the relay (`tools/chat_relay/bin/server.dart`) and translates between
/// JSON envelopes on the wire and typed [ChatTransportEvent]s for the
/// repositories.
///
/// **Lifecycle**: call [start] with the relay URL once; it connects in
/// the background and auto-reconnects on drop with a 2-second backoff.
/// Call [updateConfig] to change URL or identity (existing socket is
/// closed and a new one opened). Call [dispose] on app shutdown.
class ChatTransport {
  ChatTransport();

  // ── current configuration ────────────────────────────────────
  String _url = '';
  String _userId = '';
  String _userName = '';

  // ── connection state ─────────────────────────────────────────
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  ChatTransportStatus _status = ChatTransportStatus.disconnected;
  Timer? _reconnect;
  bool _disposed = false;

  final StreamController<ChatTransportEvent> _events =
      StreamController<ChatTransportEvent>.broadcast();
  final StreamController<ChatTransportStatus> _statusEvents =
      StreamController<ChatTransportStatus>.broadcast();

  Stream<ChatTransportEvent> get events => _events.stream;
  Stream<ChatTransportStatus> get status async* {
    yield _status;
    yield* _statusEvents.stream;
  }

  ChatTransportStatus get currentStatus => _status;

  /// Start (or restart) with a new URL + identity.
  Future<void> updateConfig({
    required String url,
    required String userId,
    required String userName,
  }) async {
    final urlChanged = url != _url;
    final identityChanged = userId != _userId || userName != _userName;
    _url = url;
    _userId = userId;
    _userName = userName;
    if (urlChanged || identityChanged) {
      await _close();
      unawaited(_maybeConnect());
    }
  }

  /// Initial start. Same as [updateConfig] but exists as a clearer
  /// boot-time entry point.
  Future<void> start({
    required String url,
    required String userId,
    required String userName,
  }) =>
      updateConfig(url: url, userId: userId, userName: userName);

  Future<void> dispose() async {
    _disposed = true;
    _reconnect?.cancel();
    await _close();
    await _events.close();
    await _statusEvents.close();
  }

  Future<void> _maybeConnect() async {
    if (_disposed) return;
    if (_url.isEmpty) {
      _setStatus(ChatTransportStatus.disconnected);
      return;
    }
    final uri = Uri.tryParse(_url);
    if (uri == null || (uri.scheme != 'ws' && uri.scheme != 'wss')) {
      _setStatus(ChatTransportStatus.error);
      return;
    }
    _setStatus(ChatTransportStatus.connecting);
    // Use `WebSocket.connect` (dart:io) instead of
    // `WebSocketChannel.connect` so we get an awaitable Future that
    // throws synchronously on TCP / handshake failure. The
    // shelf-style `WebSocketChannel.connect` returns immediately and
    // fires errors on the sink — those errors escape the zone as
    // `runZonedGuarded uncaught` and spam the log.
    WebSocket socket;
    try {
      socket = await WebSocket.connect(uri.toString())
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      _setStatus(ChatTransportStatus.error);
      _scheduleReconnect();
      return;
    }
    if (_disposed) {
      await socket.close();
      return;
    }
    final channel = IOWebSocketChannel(socket);
    _channel = channel;
    _sub = channel.stream.listen(
      _onData,
      onDone: _onDone,
      onError: _onError,
      cancelOnError: true,
    );
    // Tag the socket with our identity so the relay log is useful.
    channel.sink.add(jsonEncode({
      'type': 'hello',
      'from': _userId,
      'payload': {'name': _userName},
    }));
    _setStatus(ChatTransportStatus.connected);
  }

  void _onData(dynamic data) {
    if (data is! String) return;
    Map<String, dynamic> envelope;
    try {
      envelope = jsonDecode(data) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final type = envelope['type'] as String? ?? '';
    final payload = envelope['payload'];
    if (payload is! Map<String, dynamic>) return;

    final event = _decode(type, payload);
    if (event != null && !_events.isClosed) {
      _events.add(event);
    }
  }

  ChatTransportEvent? _decode(String type, Map<String, dynamic> payload) {
    switch (type) {
      case 'message.send':
        return MessageReceivedEvent(_decodeMessage(payload));
      case 'message.edit':
        return MessageEditedEvent(
          messageId: payload['messageId'] as String,
          newBody: payload['newBody'] as String? ?? '',
        );
      case 'message.delete':
        return MessageDeletedEvent(payload['messageId'] as String);
      case 'reaction.toggle':
        return ReactionToggledEvent(
          messageId: payload['messageId'] as String,
          emoji: payload['emoji'] as String,
          employeeId: payload['employeeId'] as String,
        );
      default:
        return null;
    }
  }

  void _onDone() {
    _setStatus(ChatTransportStatus.disconnected);
    _scheduleReconnect();
  }

  void _onError(Object e) {
    _setStatus(ChatTransportStatus.error);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_disposed || _url.isEmpty) return;
    _reconnect?.cancel();
    _reconnect = Timer(const Duration(seconds: 2), () => unawaited(_maybeConnect()));
  }

  Future<void> _close() async {
    try {
      await _sub?.cancel();
    } catch (_) {}
    _sub = null;
    try {
      await _channel?.sink.close(ws_status.normalClosure);
    } catch (_) {}
    _channel = null;
  }

  void _setStatus(ChatTransportStatus s) {
    if (_status == s) return;
    _status = s;
    if (!_statusEvents.isClosed) _statusEvents.add(s);
  }

  // ── outbound ─────────────────────────────────────────────────
  void sendMessage(ChatMessage message) {
    _send('message.send', _encodeMessage(message));
  }

  void sendEdit(String messageId, String newBody) {
    _send('message.edit', {'messageId': messageId, 'newBody': newBody});
  }

  void sendDelete(String messageId) {
    _send('message.delete', {'messageId': messageId});
  }

  void sendReaction({
    required String messageId,
    required String emoji,
    required String employeeId,
  }) {
    _send('reaction.toggle', {
      'messageId': messageId,
      'emoji': emoji,
      'employeeId': employeeId,
    });
  }

  void _send(String type, Map<String, dynamic> payload) {
    final ch = _channel;
    if (ch == null || _status != ChatTransportStatus.connected) return;
    try {
      ch.sink.add(jsonEncode({
        'type': type,
        'from': _userId,
        'payload': payload,
      }));
    } catch (_) {
      _setStatus(ChatTransportStatus.error);
      _scheduleReconnect();
    }
  }

  // ── (de)serialise ChatMessage on the wire ────────────────────
  static Map<String, dynamic> _encodeMessage(ChatMessage m) => {
        'id': m.id,
        'conversationId': m.conversationId,
        'senderId': m.senderId,
        'senderName': m.senderName,
        'type': m.type.name,
        'sentAt': m.sentAt.toIso8601String(),
        if (m.body != null) 'body': m.body,
        if (m.replyToId != null) 'replyToId': m.replyToId,
        if (m.replyToSenderName != null)
          'replyToSenderName': m.replyToSenderName,
        if (m.replyToPreview != null) 'replyToPreview': m.replyToPreview,
        if (m.voiceUrl != null) 'voiceUrl': m.voiceUrl,
        if (m.voiceDurationSeconds != null)
          'voiceDurationSeconds': m.voiceDurationSeconds,
        if (m.fileUrl != null) 'fileUrl': m.fileUrl,
        if (m.fileName != null) 'fileName': m.fileName,
        if (m.fileSizeBytes != null) 'fileSizeBytes': m.fileSizeBytes,
      };

  static ChatMessage _decodeMessage(Map<String, dynamic> p) {
    final typeName = p['type'] as String? ?? 'text';
    return ChatMessage(
      id: p['id'] as String,
      conversationId: p['conversationId'] as String,
      senderId: p['senderId'] as String,
      senderName: p['senderName'] as String,
      type: ChatMessageType.values.firstWhere(
        (t) => t.name == typeName,
        orElse: () => ChatMessageType.text,
      ),
      sentAt: DateTime.tryParse(p['sentAt'] as String? ?? '') ??
          DateTime.now(),
      body: p['body'] as String?,
      replyToId: p['replyToId'] as String?,
      replyToSenderName: p['replyToSenderName'] as String?,
      replyToPreview: p['replyToPreview'] as String?,
      voiceUrl: p['voiceUrl'] as String?,
      voiceDurationSeconds: p['voiceDurationSeconds'] as int?,
      fileUrl: p['fileUrl'] as String?,
      fileName: p['fileName'] as String?,
      fileSizeBytes: p['fileSizeBytes'] as int?,
    );
  }
}
