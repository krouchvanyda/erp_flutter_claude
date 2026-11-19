/// Every backend path, in one place (see API_LIST_BACKEND.md).
/// Never type a path in a repository.
abstract final class ApiEndPoint {
  static const String _v1 = '/api/v1';

  // ── Public ──
  static const String health = '/health';
  static const String login = '$_v1/auth/login';
  static const String refresh = '$_v1/auth/refresh';

  // ── Token needed ──
  static const String logout = '$_v1/auth/logout';
  static const String me = '$_v1/users/me';
}
