import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as ws_status;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../entities/call_log.dart';
import '../entities/chat_message.dart';

/// Connection status surfaced to the UI (banner / status dot).
enum ChatTransportStatus { disconnected, connecting, connected, error }

/// Inbound event the transport hands off to the repositories.
sealed class ChatTransportEvent {
  const ChatTransportEvent();
}

/// Peer sent a new message — add to local seed without re-broadcasting.
///
/// [targetIds] is the list of user ids the message is addressed to.
/// For direct conversations that's the single other person, for groups
/// it's every member except the sender. The relay is broadcast-only
/// (no identity awareness on the server), so each receiver filters on
/// [targetIds.contains(settings.userId)] in `bootChatTransport` —
/// without this, a Vibol → Pisey direct message would land in
/// Channary's inbox as well (Slice 10.1.8). Empty list = pre-10.1.8
/// "broadcast to everyone" for backwards compatibility.
class MessageReceivedEvent extends ChatTransportEvent {
  const MessageReceivedEvent(this.message, {this.targetIds = const <String>[]});
  final ChatMessage message;
  final List<String> targetIds;
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

/// Slice 10.2.3 — call signalling envelopes. No media flows; these
/// just drive the call-state machine on both sides so a placed call
/// rings on the peer, accept transitions both to "connected", and
/// hangup closes both. "Real" WebRTC would replace the body of the
/// `connected` state with actual SDP offer/answer + ICE exchange.

/// Caller pressed Call → callee's overlay should show an incoming
/// call sheet.
///
/// [targetIds] is the list of user ids the caller intends to ring —
/// for direct calls just the other person, for group calls every
/// member except the caller. The relay still broadcasts the envelope
/// to every connected socket (it doesn't know identities), so the
/// callee filters on its own userId before raising the overlay
/// (Slice 10.2.7). An empty list means "ring everyone" — falls back
/// to the old pre-slice-10.2.7 behaviour.
class CallInviteEvent extends ChatTransportEvent {
  const CallInviteEvent({
    required this.callId,
    required this.conversationId,
    required this.callerId,
    required this.callerName,
    required this.callType,
    required this.startedAt,
    this.targetIds = const <String>[],
  });
  final String callId;
  final String conversationId;
  final String callerId;
  final String callerName;
  final ChatCallType callType;
  final DateTime startedAt;
  final List<String> targetIds;
}

/// Callee tapped Accept on the incoming sheet — both sides should
/// transition to the "connected" state. For group calls, [accepterId]
/// tells the caller WHICH callee joined so the caller can track the
/// set of "in-call" peers and auto-end the call when the last one
/// leaves (Slice 10.2.11). Optional for back-compat with pre-10.2.11
/// clients on the wire.
class CallAcceptEvent extends ChatTransportEvent {
  const CallAcceptEvent({required this.callId, this.accepterId});
  final String callId;
  final String? accepterId;
}

/// Callee tapped Reject (or the invite timed out on their device).
/// Caller should transition to "ended". [reason] is `'busy'` when the
/// callee was already in another call, `'declined'` when they tapped
/// Reject explicitly, or `null` when no reason was supplied.
class CallRejectEvent extends ChatTransportEvent {
  const CallRejectEvent({required this.callId, this.reason});
  final String callId;
  final String? reason;
}

/// Either side pressed End — for direct calls both sides transition to
/// "ended". For group calls the receiver checks [hangerUpperId] against
/// the original caller's id: only the caller's hangup ends the call
/// for everyone (Slice 10.2.10). A callee tapping End just leaves
/// their own client; the other group members stay connected.
class CallHangupEvent extends ChatTransportEvent {
  const CallHangupEvent({required this.callId, this.hangerUpperId});
  final String callId;

  /// User id of whoever pressed End. Optional for back-compat with
  /// pre-10.2.10 clients on the wire — if null, falls back to the old
  /// "everyone ends" behaviour.
  final String? hangerUpperId;
}

/// Slice 10.1.7 — peer just created a group conversation that lists us
/// as a member. The receiving device materialises the conversation in
/// its local repo so it shows up in the inbox without needing a server
/// round-trip. Direct conversations don't fan out (they're created
/// implicitly the first time anyone sends a message).
///
/// [participantIds] includes the creator AND every invited member. Each
/// callee filters on its own [participantIds.contains(settings.userId)]
/// before applying — the relay still broadcasts to every socket.
class ConversationCreatedEvent extends ChatTransportEvent {
  const ConversationCreatedEvent({
    required this.conversationId,
    required this.name,
    required this.isGroup,
    required this.creatorId,
    required this.creatorName,
    required this.participantIds,
    required this.createdAt,
  });
  final String conversationId;
  final String name;
  final bool isGroup;
  final String creatorId;
  final String creatorName;
  final List<String> participantIds;
  final DateTime createdAt;
}

/// Slice 10.3.4 — admin renamed a group on their device. Every other
/// member's local conv gets updated so their inbox tile + AppBar
/// reflect the new name. [participantIds] is used the same way as
/// [ConversationCreatedEvent.participantIds] — receivers filter on
/// their own id to ignore renames they're not part of.
///
/// Group avatar is NOT broadcast — it's a local `image_picker` file
/// path, which is meaningless on a peer device. That stays per-device.
class ConversationUpdatedEvent extends ChatTransportEvent {
  const ConversationUpdatedEvent({
    required this.conversationId,
    required this.name,
    required this.participantIds,
  });
  final String conversationId;
  final String name;
  final List<String> participantIds;
}

/// Slice 10.3.4 — the user changed their display name (currently via
/// the chat identity switcher, eventually via the My Profile screen).
/// Every other connected device updates its local direct conversation
/// with this user so the AppBar title + inbox tile rename live.
///
/// [userId] is the chat identity that changed; [newName] is the value
/// we want every peer to render going forward. Avatar would ride here
/// too if we had a server to host it.
class ProfileUpdatedEvent extends ChatTransportEvent {
  const ProfileUpdatedEvent({required this.userId, required this.newName});
  final String userId;
  final String newName;
}

/// Slice 10.3.6 — admin set or cleared a group's avatar. Carries the
/// raw image bytes (base64-encoded JPEG, sized down by image_picker to
/// 1024×1024 / quality 85 ≈ 50–200 KB) so receivers can write them to
/// their own local cache and use that path — local file paths from
/// the sender are meaningless on a peer device. Set [avatarBase64] to
/// null to clear the photo on every member.
class ConversationAvatarUpdatedEvent extends ChatTransportEvent {
  const ConversationAvatarUpdatedEvent({
    required this.conversationId,
    required this.participantIds,
    required this.avatarBase64,
    required this.fileExtension,
  });
  final String conversationId;
  final List<String> participantIds;

  /// Base64-encoded image bytes; null = "remove the photo".
  final String? avatarBase64;

  /// File extension (`.jpg` / `.png` / etc.) so the receiver can
  /// reconstruct a sensible file name. Empty / null = default to `.jpg`.
  final String? fileExtension;
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
        return MessageReceivedEvent(
          _decodeMessage(payload),
          targetIds:
              (payload['targetIds'] as List?)?.cast<String>() ?? const <String>[],
        );
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
      case 'call.invite':
        return CallInviteEvent(
          callId: payload['callId'] as String,
          conversationId: payload['conversationId'] as String,
          callerId: payload['callerId'] as String,
          callerName: payload['callerName'] as String,
          callType: (payload['callType'] as String? ?? 'voice') == 'video'
              ? ChatCallType.video
              : ChatCallType.voice,
          startedAt:
              DateTime.tryParse(payload['startedAt'] as String? ?? '') ??
                  DateTime.now(),
          targetIds: (payload['targetIds'] as List?)?.cast<String>() ??
              const <String>[],
        );
      case 'call.accept':
        return CallAcceptEvent(
          callId: payload['callId'] as String,
          accepterId: payload['accepterId'] as String?,
        );
      case 'call.reject':
        return CallRejectEvent(
          callId: payload['callId'] as String,
          reason: payload['reason'] as String?,
        );
      case 'call.hangup':
        return CallHangupEvent(
          callId: payload['callId'] as String,
          hangerUpperId: payload['hangerUpperId'] as String?,
        );
      case 'conversation.create':
        return ConversationCreatedEvent(
          conversationId: payload['conversationId'] as String,
          name: payload['name'] as String,
          isGroup: payload['isGroup'] as bool? ?? true,
          creatorId: payload['creatorId'] as String,
          creatorName: payload['creatorName'] as String,
          participantIds: (payload['participantIds'] as List?)
                  ?.cast<String>() ??
              const <String>[],
          createdAt:
              DateTime.tryParse(payload['createdAt'] as String? ?? '') ??
                  DateTime.now(),
        );
      case 'conversation.update':
        return ConversationUpdatedEvent(
          conversationId: payload['conversationId'] as String,
          name: payload['name'] as String,
          participantIds: (payload['participantIds'] as List?)
                  ?.cast<String>() ??
              const <String>[],
        );
      case 'profile.update':
        return ProfileUpdatedEvent(
          userId: payload['userId'] as String,
          newName: payload['newName'] as String,
        );
      case 'conversation.avatar.update':
        return ConversationAvatarUpdatedEvent(
          conversationId: payload['conversationId'] as String,
          participantIds: (payload['participantIds'] as List?)
                  ?.cast<String>() ??
              const <String>[],
          avatarBase64: payload['avatarBase64'] as String?,
          fileExtension: payload['fileExtension'] as String?,
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
  void sendMessage(
    ChatMessage message, {
    List<String> targetIds = const <String>[],
  }) {
    _send('message.send', {
      ..._encodeMessage(message),
      if (targetIds.isNotEmpty) 'targetIds': targetIds,
    });
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

  // ── Slice 10.2.3 — call signalling outbound ──────────────────
  void sendCallInvite({
    required String callId,
    required String conversationId,
    required String callerId,
    required String callerName,
    required ChatCallType callType,
    required DateTime startedAt,
    List<String> targetIds = const <String>[],
  }) {
    _send('call.invite', {
      'callId': callId,
      'conversationId': conversationId,
      'callerId': callerId,
      'callerName': callerName,
      'callType': callType.name,
      'startedAt': startedAt.toIso8601String(),
      if (targetIds.isNotEmpty) 'targetIds': targetIds,
    });
  }

  void sendCallAccept(String callId, {String? accepterId}) {
    _send('call.accept', {
      'callId': callId,
      if (accepterId != null) 'accepterId': accepterId,
    });
  }

  void sendCallReject(String callId, {String? reason}) {
    _send('call.reject', {
      'callId': callId,
      if (reason != null) 'reason': reason,
    });
  }

  void sendCallHangup(String callId, {String? hangerUpperId}) {
    _send('call.hangup', {
      'callId': callId,
      if (hangerUpperId != null) 'hangerUpperId': hangerUpperId,
    });
  }

  /// Slice 10.1.7 — broadcast a freshly-created group so every member
  /// device hydrates it locally. [participantIds] must include the
  /// creator and every invited member; receivers filter on their own
  /// id before applying.
  void sendConversationCreate({
    required String conversationId,
    required String name,
    required bool isGroup,
    required String creatorId,
    required String creatorName,
    required List<String> participantIds,
    required DateTime createdAt,
  }) {
    _send('conversation.create', {
      'conversationId': conversationId,
      'name': name,
      'isGroup': isGroup,
      'creatorId': creatorId,
      'creatorName': creatorName,
      'participantIds': participantIds,
      'createdAt': createdAt.toIso8601String(),
    });
  }

  /// Slice 10.3.4 — broadcast a group rename so every other member's
  /// inbox tile + AppBar shows the new name without needing them to
  /// re-open the chat.
  void sendConversationUpdate({
    required String conversationId,
    required String name,
    required List<String> participantIds,
  }) {
    _send('conversation.update', {
      'conversationId': conversationId,
      'name': name,
      'participantIds': participantIds,
    });
  }

  /// Slice 10.3.4 — broadcast a user-profile rename so every other
  /// device renames the matching local direct conversation.
  void sendProfileUpdate({
    required String userId,
    required String newName,
  }) {
    _send('profile.update', {
      'userId': userId,
      'newName': newName,
    });
  }

  /// Slice 10.3.6 — broadcast a group avatar change. [avatarBase64] is
  /// null to clear the photo; otherwise it's the raw image bytes
  /// base64-encoded so every peer can write them locally and use that
  /// path going forward.
  void sendConversationAvatar({
    required String conversationId,
    required List<String> participantIds,
    required String? avatarBase64,
    required String? fileExtension,
  }) {
    _send('conversation.avatar.update', {
      'conversationId': conversationId,
      'participantIds': participantIds,
      if (avatarBase64 != null) 'avatarBase64': avatarBase64,
      if (fileExtension != null) 'fileExtension': fileExtension,
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
