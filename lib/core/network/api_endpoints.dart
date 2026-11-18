/// Backend REST paths (MVVM template: `core/network/api_endpoints.dart`).
///
/// Relative to the flavor's API base URL, which already ends in `/api/v1`.
/// Use with [AppService]: `AppService(httpMethods: HttpMethods.get,
/// endPoint: ApiEndPoint.streamToken).send()`.
///
/// Fixed paths are `const`; paths with an id are small functions:
/// `ApiEndPoint.conversation(12)` → `/chats/conversations/12`.
class ApiEndPoint {
  ApiEndPoint._();

  // ── Auth ────────────────────────────────────────────────────────
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String oauthToken = '/oauth/token';

  // ── Conversations ───────────────────────────────────────────────
  /// GET inbox · POST create (direct / group).
  static const String conversations = '/chats/conversations';
  static String conversation(Object id) => '$conversations/$id';
  static String conversationMembers(Object id) => '$conversations/$id/members';
  static String conversationMember(Object id, Object userId) =>
      '$conversations/$id/members/$userId';
  static String conversationRead(Object id) => '$conversations/$id/read';

  // ── Messages ────────────────────────────────────────────────────
  /// GET history (paged) · POST send.
  static String conversationMessages(Object conversationId) =>
      '$conversations/$conversationId/messages';
  static String conversationMessagesSearch(Object conversationId) =>
      '$conversations/$conversationId/messages/search';
  static const String messages = '/chats/messages';
  static String message(Object id) => '$messages/$id';
  static String messageReactions(Object id) => '$messages/$id/reactions';
  static const String attachments = '/chats/attachments';

  // ── Calls (voice / video) ───────────────────────────────────────
  /// GET my call history (all conversations).
  static const String calls = '/chats/calls';

  /// GET Stream Video token used to join the media call.
  static const String streamToken = '$calls/stream-token';

  /// POST start a call · GET this conversation's call history.
  static String conversationCalls(Object conversationId) =>
      '$conversations/$conversationId/calls';
  static String call(Object id) => '$calls/$id';
  static String callAccept(Object id) => '$calls/$id/accept';
  static String callReject(Object id) => '$calls/$id/reject';
  static String callEnd(Object id) => '$calls/$id/end';

  // ── Presence ────────────────────────────────────────────────────
  static const String presence = '/chats/presence';
  static const String presenceBackground = '$presence/background';
  static const String presenceForeground = '$presence/foreground';

  // ── Users & roles (admin) ───────────────────────────────────────
  static const String users = '/users';
  static const String usersMe = '/users/me';
  static const String usersAssignRoles = '/users/assign-roles';
  static String user(Object id) => '$users/$id';

  static const String roles = '/roles';
  static const String rolesPermissions = '/roles/permissions';
  static String role(Object id) => '$roles/$id';

  // ── Employees (My Profile) ──────────────────────────────────────
  static const String employees = '/employees';
  static const String employeesMe = '/employees/me';
  static const String employeesMeAvatar = '/employees/me/avatar';
  static String employee(Object id) => '$employees/$id';

  // ── Push devices ────────────────────────────────────────────────
  /// POST register this device's FCM token · DELETE on logout.
  static const String meDevices = '/me/devices';
  static String meDevice(Object deviceId) => '$meDevices/$deviceId';
}
