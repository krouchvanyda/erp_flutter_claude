import '../config/flavor.dart';

/// Every backend path, in one place (see API_LIST_BACKEND.md).
/// Never type a path in a repository.
abstract final class ApiEndPoint {
  static const String _v1 = '/api/v1';

  // ── Public (no token) ──
  static const String health = '/health';
  static const String login = '$_v1/auth/login';
  static const String register = '$_v1/auth/register';
  static const String refresh = '$_v1/auth/refresh';

  // ── Token needed ──
  static const String logout = '$_v1/auth/logout';
  static const String me = '$_v1/users/me';
  static const String employeesMe = '$_v1/employees/me';
  static const String employeesMeAvatar = '$_v1/employees/me/avatar';

  /// Everyone I can chat with (5.4 member picker). Open to every logged-in
  /// user. NOTE: the backend ignores `search` → we filter on the phone.
  static const String users = '$_v1/users';

  // ── Chat (Step 5) ──
  static const String conversations = '$_v1/chats/conversations';

  /// History (GET, newest first) and send (POST) for one conversation.
  static String messages(String conversationId) =>
      '$conversations/$conversationId/messages';

  /// "I've read up to message X" (POST `{ lastReadMessageId }`).
  static String markRead(String conversationId) =>
      '$conversations/$conversationId/read';

  /// Chat file upload (POST multipart `file`) → `{url, contentType,
  /// sizeBytes}` — Step 5.5.
  static const String chatAttachments = '$_v1/chats/attachments';

  /// One conversation (GET) — for a chat that isn't in the loaded inbox yet.
  static String conversation(String conversationId) =>
      '$conversations/$conversationId';

  /// Add members (POST `{memberIds}`) — 5.4.
  static String conversationMembers(String conversationId) =>
      '$conversations/$conversationId/members';

  /// Remove one member (DELETE). Removing MYSELF = leaving the group.
  static String conversationMember(String conversationId, String userId) =>
      '$conversations/$conversationId/members/$userId';

  /// One message: edit (PATCH `{body}`) / delete (DELETE) — 5.6.
  static String message(String messageId) => '$_v1/chats/messages/$messageId';

  /// Toggle an emoji (POST `{emoji}`) → the message's full reaction list.
  static String messageReactions(String messageId) =>
      '$_v1/chats/messages/$messageId/reactions';

  /// Search inside one conversation (GET `?q&page&pageSize`) — 5.6.
  static String messageSearch(String conversationId) =>
      '$conversations/$conversationId/messages/search';

  /// Online status: GET `?ids=1&ids=2` → `[{userId, status, lastSeenAt}]`.
  static const String presence = '$_v1/chats/presence';

  /// App minimized / back (so a minimized phone counts as OFFLINE at once,
  /// which lets calls ring it by push — Steps 6–7).
  static const String presenceBackground = '$_v1/chats/presence/background';
  static const String presenceForeground = '$_v1/chats/presence/foreground';

  // ── Realtime (Step 5.3) ──
  /// STOMP over WebSocket, per flavor (`Environments.*RealtimeUrl`, the
  /// backend's `/ws`). The token goes in the CONNECT frame, not the URL.
  static String get websocketUrl => Flavor.current.realtimeUrl;

  static const String inboxQueue = '/user/queue/inbox';

  /// Everyone's ONLINE / BUSY / OFFLINE changes (`presence.update`).
  static const String presenceTopic = '/topic/presence';

  /// SEND here `{typing: true|false}` → the server tells the conversation
  /// topic "typing" (5.6). `/app` = the server's handlers (not a topic).
  static String typingDestination(String conversationId) =>
      '/app/conversations/$conversationId/typing';
  static String conversationTopic(String conversationId) =>
      '/topic/conversations/$conversationId';

  /// Endpoints that never carry a token and never trigger a refresh.
  /// (The backend answers 401 for a WRONG PASSWORD on login — that must not
  /// look like "token expired".)
  static const Set<String> publicEndpoints = {health, login, register, refresh};

  static bool isPublic(String path) => publicEndpoints.contains(path);

  /// Server file path → full URL for `Image` widgets.
  /// `"/uploads/a.jpg"` → `"http://host:8080/uploads/a.jpg"`.
  /// Already full (`http…`) → unchanged. Empty / null → null.
  /// `/uploads/**` is public on the backend, so no token is needed.
  static String? fileUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http')) return path;
    return '${Flavor.current.apiBaseUrl}$path';
  }
}
