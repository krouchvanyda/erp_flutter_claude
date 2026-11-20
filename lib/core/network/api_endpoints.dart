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

  // ── Chat (Step 5) ──
  static const String conversations = '$_v1/chats/conversations';

  /// History (GET, newest first) and send (POST) for one conversation.
  static String messages(String conversationId) =>
      '$conversations/$conversationId/messages';

  /// "I've read up to message X" (POST `{ lastReadMessageId }`).
  static String markRead(String conversationId) =>
      '$conversations/$conversationId/read';

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
