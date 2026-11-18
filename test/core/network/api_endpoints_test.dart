import 'package:erp_mobile/core/network/api_endpoints.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pins every path to the backend controllers, so a typo fails a test
/// instead of silently 404-ing at runtime.
void main() {
  test('conversations', () {
    expect(ApiEndPoint.conversations, '/chats/conversations');
    expect(ApiEndPoint.conversation(12), '/chats/conversations/12');
    expect(ApiEndPoint.conversationMembers(12), '/chats/conversations/12/members');
    expect(ApiEndPoint.conversationMember(12, 7), '/chats/conversations/12/members/7');
    expect(ApiEndPoint.conversationRead(12), '/chats/conversations/12/read');
  });

  test('messages', () {
    expect(ApiEndPoint.conversationMessages(12), '/chats/conversations/12/messages');
    expect(ApiEndPoint.conversationMessagesSearch(12),
        '/chats/conversations/12/messages/search');
    expect(ApiEndPoint.message(345), '/chats/messages/345');
    expect(ApiEndPoint.messageReactions(345), '/chats/messages/345/reactions');
    expect(ApiEndPoint.attachments, '/chats/attachments');
  });

  test('calls', () {
    expect(ApiEndPoint.calls, '/chats/calls');
    expect(ApiEndPoint.streamToken, '/chats/calls/stream-token');
    expect(ApiEndPoint.conversationCalls(12), '/chats/conversations/12/calls');
    expect(ApiEndPoint.call(9), '/chats/calls/9');
    expect(ApiEndPoint.callAccept(9), '/chats/calls/9/accept');
    expect(ApiEndPoint.callReject(9), '/chats/calls/9/reject');
    expect(ApiEndPoint.callEnd(9), '/chats/calls/9/end');
  });

  test('presence, auth, users, roles, employees, devices', () {
    expect(ApiEndPoint.presence, '/chats/presence');
    expect(ApiEndPoint.presenceBackground, '/chats/presence/background');
    expect(ApiEndPoint.presenceForeground, '/chats/presence/foreground');
    expect(ApiEndPoint.login, '/auth/login');
    expect(ApiEndPoint.register, '/auth/register');
    expect(ApiEndPoint.refresh, '/auth/refresh');
    expect(ApiEndPoint.logout, '/auth/logout');
    expect(ApiEndPoint.oauthToken, '/oauth/token');
    expect(ApiEndPoint.users, '/users');
    expect(ApiEndPoint.usersMe, '/users/me');
    expect(ApiEndPoint.usersAssignRoles, '/users/assign-roles');
    expect(ApiEndPoint.user(5), '/users/5');
    expect(ApiEndPoint.roles, '/roles');
    expect(ApiEndPoint.rolesPermissions, '/roles/permissions');
    expect(ApiEndPoint.role(3), '/roles/3');
    expect(ApiEndPoint.employees, '/employees');
    expect(ApiEndPoint.employeesMe, '/employees/me');
    expect(ApiEndPoint.employeesMeAvatar, '/employees/me/avatar');
    expect(ApiEndPoint.employee(5), '/employees/5');
    expect(ApiEndPoint.meDevices, '/me/devices');
    expect(ApiEndPoint.meDevice('abc'), '/me/devices/abc');
  });
}
