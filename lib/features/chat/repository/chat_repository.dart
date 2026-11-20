import 'package:dartz/dartz.dart' show Either;

import '../../../core/network/api_endpoints.dart';
import '../../../core/network/app_service.dart';
import '../../../core/network/helper_service.dart';
import '../../../core/network/network_error_model.dart';
import '../../../core/network/page_model.dart';
import '../../../core/network/token_storage.dart';
import '../model/chat_enums.dart';
import '../model/conversation_model.dart';
import '../model/message_model.dart';

/// Chat business rules. BLoCs call this; they never touch Dio or tokens.
class ChatRepository {
  ChatRepository({
    required AppService appService,
    required TokenStorage tokenStorage,
  }) : _appService = appService,
       _tokenStorage = tokenStorage;

  final AppService _appService;
  final TokenStorage _tokenStorage;

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
}
