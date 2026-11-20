import 'package:dartz/dartz.dart' show Either;

import '../../../core/network/api_endpoints.dart';
import '../../../core/network/app_service.dart';
import '../../../core/network/helper_service.dart';
import '../../../core/network/network_error_model.dart';
import '../../../core/network/page_model.dart';
import '../../../core/network/token_storage.dart';
import '../model/conversation_model.dart';

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
}
