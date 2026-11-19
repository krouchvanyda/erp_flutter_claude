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

  /// Endpoints that never carry a token and never trigger a refresh.
  /// (The backend answers 401 for a WRONG PASSWORD on login — that must not
  /// look like "token expired".)
  static const Set<String> publicEndpoints = {health, login, register, refresh};

  static bool isPublic(String path) => publicEndpoints.contains(path);
}
