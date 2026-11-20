import 'package:dartz/dartz.dart' show Either;

import '../../../core/network/api_endpoints.dart';
import '../../../core/network/app_service.dart';
import '../../../core/network/helper_service.dart';
import '../../../core/network/network_error_model.dart';
import '../../../core/network/page_model.dart';
import '../../../core/network/token_storage.dart';
import '../../../core/realtime/realtime_service.dart';
import '../model/chat_update.dart';
import '../model/contact_model.dart';
import '../model/chat_enums.dart';
import '../model/conversation_model.dart';
import '../model/message_model.dart';

/// Chat business rules. BLoCs call this; they never touch Dio or tokens.
class ChatRepository {
  ChatRepository({
    required AppService appService,
    required TokenStorage tokenStorage,
    required RealtimeService realtime,
  }) : _appService = appService,
       _tokenStorage = tokenStorage,
       _realtime = realtime;

  final AppService _appService;
  final TokenStorage _tokenStorage;
  final RealtimeService _realtime;

  /// How many conversations per page.
  static const int inboxPageSize = 20;

  /// MY user id, from the access token (`sub`). No request, works offline.
  Future<String?> myUserId() async => (await _tokenStorage.read())?.userId;

  /// One page of my inbox, newest first (the server sorts it).
  Future<Either<NetworkErrorModel, PageModel<ConversationModel>>> loadInbox({
    int page = 1,
  }) {
    return _appService.send(
      httpMethods: HttpMethods.get,
      endPoint: ApiEndPoint.conversations,
      queryParameters: {'page': page, 'pageSize': inboxPageSize},
      parse: (data) => PageModel.fromData(data, ConversationModel.fromJson),
    );
  }

  // ─────────────── Step 5.2: one conversation ───────────────

  /// How many messages per page (the backend's default too).
  static const int messagesPageSize = 30;

  /// One page of a conversation's messages, NEWEST first (the server sorts
  /// by `createdAt` desc). Page 1 = the latest 30.
  Future<Either<NetworkErrorModel, PageModel<MessageModel>>> loadMessages(
    String conversationId, {
    int page = 1,
  }) {
    return _appService.send(
      httpMethods: HttpMethods.get,
      endPoint: ApiEndPoint.messages(conversationId),
      queryParameters: {'page': page, 'pageSize': messagesPageSize},
      parse: (data) => PageModel.fromData(data, MessageModel.fromJson),
    );
  }

  /// Sends a TEXT message. The server returns the saved message (real id,
  /// server time) — that's what replaces the "sending" bubble.
  ///
  /// We don't send `targetIds`: the server finds the receivers itself.
  Future<Either<NetworkErrorModel, MessageModel>> sendText(
    String conversationId,
    String text,
  ) {
    return _appService.send(
      httpMethods: HttpMethods.post,
      endPoint: ApiEndPoint.messages(conversationId),
      data: {'type': MessageType.text.toJson(), 'body': text},
      parse: (data) => MessageModel.fromJson(data as Map<String, dynamic>),
    );
  }

  /// "I've read everything up to [messageId]" → my unread count becomes 0.
  /// The server wants a NUMBER (ids are strings in the app).
  Future<Either<NetworkErrorModel, void>> markRead(
    String conversationId,
    String messageId,
  ) {
    return _appService.send<void>(
      httpMethods: HttpMethods.post,
      endPoint: ApiEndPoint.markRead(conversationId),
      data: {'lastReadMessageId': int.tryParse(messageId) ?? messageId},
      parse: (_) {},
    );
  }

  /// One conversation — for a live message from a chat the inbox hasn't
  /// loaded (a new chat, or one on a later page).
  Future<Either<NetworkErrorModel, ConversationModel>> loadConversation(
    String conversationId,
  ) {
    return _appService.send(
      httpMethods: HttpMethods.get,
      endPoint: ApiEndPoint.conversation(conversationId),
      parse: (data) => ConversationModel.fromJson(data as Map<String, dynamic>),
    );
  }

  // ─────────────── Step 5.4: new chats + groups ───────────────

  /// How many people per page in the picker (we load them all, page by page).
  static const int contactsPageSize = 100;

  /// One page of people I can chat with.
  Future<Either<NetworkErrorModel, PageModel<ContactModel>>> loadContacts({
    int page = 1,
  }) {
    return _appService.send(
      httpMethods: HttpMethods.get,
      endPoint: ApiEndPoint.users,
      queryParameters: {'page': page, 'pageSize': contactsPageSize},
      parse: (data) => PageModel.fromData(data, ContactModel.fromJson),
    );
  }

  /// A 1-to-1 chat. If one already exists with this person, the server
  /// returns THAT one (no duplicates). I'm added by the server.
  Future<Either<NetworkErrorModel, ConversationModel>> createDirect(
    String userId,
  ) => _createConversation({
    'type': ConversationType.direct.name.toUpperCase(),
    'memberIds': [_wireId(userId)],
  });

  /// A group with [name]. I'm added by the server, as ADMIN.
  Future<Either<NetworkErrorModel, ConversationModel>> createGroup({
    required String name,
    required List<String> memberIds,
  }) => _createConversation({
    'type': ConversationType.group.name.toUpperCase(),
    'name': name.trim(),
    'memberIds': [for (final id in memberIds) _wireId(id)],
  });

  Future<Either<NetworkErrorModel, ConversationModel>> _createConversation(
    Map<String, dynamic> body,
  ) {
    return _appService.send(
      httpMethods: HttpMethods.post,
      endPoint: ApiEndPoint.conversations,
      data: body,
      parse: _conversation,
    );
  }

  /// Rename a group (admin only; the server answers 403 otherwise).
  Future<Either<NetworkErrorModel, ConversationModel>> rename(
    String conversationId,
    String name,
  ) {
    return _appService.send(
      httpMethods: HttpMethods.patch,
      endPoint: ApiEndPoint.conversation(conversationId),
      data: {'name': name.trim()},
      parse: _conversation,
    );
  }

  /// Add people to a group (admin only).
  Future<Either<NetworkErrorModel, ConversationModel>> addMembers(
    String conversationId,
    List<String> userIds,
  ) {
    return _appService.send(
      httpMethods: HttpMethods.post,
      endPoint: ApiEndPoint.conversationMembers(conversationId),
      data: {
        'memberIds': [for (final id in userIds) _wireId(id)],
      },
      parse: _conversation,
    );
  }

  /// Remove someone from a group (admin only) → the updated group.
  Future<Either<NetworkErrorModel, ConversationModel>> removeMember(
    String conversationId,
    String userId,
  ) {
    return _appService.send(
      httpMethods: HttpMethods.delete,
      endPoint: ApiEndPoint.conversationMember(conversationId, userId),
      parse: _conversation,
    );
  }

  /// Leave a group = remove MYSELF (allowed for everyone).
  Future<Either<NetworkErrorModel, void>> leave(String conversationId) async {
    final me = await myUserId() ?? '';
    final result = await removeMember(conversationId, me);
    return result.map((_) {});
  }

  /// Delete for everyone. Group: admin only. Direct: either person.
  Future<Either<NetworkErrorModel, void>> deleteConversation(
    String conversationId,
  ) {
    return _appService.send<void>(
      httpMethods: HttpMethods.delete,
      endPoint: ApiEndPoint.conversation(conversationId),
      parse: (_) {},
    );
  }

  static ConversationModel _conversation(Object? data) =>
      ConversationModel.fromJson(data as Map<String, dynamic>);

  /// The server wants NUMBER ids ("7" → 7).
  static Object _wireId(String id) => int.tryParse(id) ?? id;

  // ─────────────── Step 5.3: live updates ───────────────

  /// MY inbox: new messages in any chat, chats created / changed / removed.
  Stream<ChatUpdate> inboxUpdates() => _updates(ApiEndPoint.inboxQueue);

  /// One OPEN conversation: messages, edits, deletes, read receipts.
  Stream<ChatUpdate> conversationUpdates(String conversationId) =>
      _updates(ApiEndPoint.conversationTopic(conversationId));

  /// The connection came back after a drop. Events sent meanwhile are lost,
  /// so listeners reload (catch-up).
  Stream<void> get reconnected => _realtime.reconnected;

  Stream<ChatUpdate> _updates(String destination) => _realtime
      .subscribe(destination)
      .map(ChatUpdate.fromRealtime)
      .where((u) => u != null)
      .cast<ChatUpdate>();
}
