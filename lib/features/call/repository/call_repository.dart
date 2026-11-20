import 'package:dartz/dartz.dart' show Either;

import '../../../core/network/api_endpoints.dart';
import '../../../core/network/app_service.dart';
import '../../../core/network/helper_service.dart';
import '../../../core/network/network_error_model.dart';
import '../../../core/network/token_storage.dart';
import '../../../core/realtime/realtime_service.dart';
import '../model/call_enums.dart';
import '../model/call_model.dart';
import '../model/call_update.dart';
import '../model/stream_token_model.dart';

/// Call signalling (Step 6.1): REST to change a call, STOMP to hear about it.
///
/// ```
/// start ──► POST /conversations/{id}/calls {type}     (the server rings them)
/// ringing ► POST /calls/{id}/ringing                  (my phone shows it)
/// accept ─► POST /calls/{id}/accept
/// reject ─► POST /calls/{id}/reject[?reason=busy]
/// end ────► POST /calls/{id}/end
///
/// callsQueue()     /user/queue/calls             invites for ME
/// callTopic(conv)  /topic/conversations/{id}/call  one call's events
/// ```
class CallRepository {
  CallRepository({
    required AppService appService,
    required TokenStorage tokenStorage,
    required RealtimeService realtime,
  }) : _appService = appService,
       _tokenStorage = tokenStorage,
       _realtime = realtime;

  final AppService _appService;
  final TokenStorage _tokenStorage;
  final RealtimeService _realtime;

  /// MY user id (the access token's `sub`) — to tell my events from theirs.
  Future<String?> myUserId() async => (await _tokenStorage.read())?.userId;

  Future<Either<NetworkErrorModel, CallModel>> start(
    String conversationId,
    CallType type,
  ) => _send(
    HttpMethods.post,
    ApiEndPoint.conversationCalls(conversationId),
    data: {'type': type.toJson()},
  );

  /// Best effort: if it's lost, the caller just stays on "Calling…".
  Future<void> ringing(String callId) => _appService.send<void>(
    httpMethods: HttpMethods.post,
    endPoint: ApiEndPoint.callRinging(callId),
    parse: (_) {},
  );

  Future<Either<NetworkErrorModel, CallModel>> accept(String callId) =>
      _send(HttpMethods.post, ApiEndPoint.callAccept(callId));

  /// [reason] `"busy"` = an automatic "I'm already in a call".
  Future<Either<NetworkErrorModel, CallModel>> reject(
    String callId, {
    String? reason,
  }) => _send(
    HttpMethods.post,
    ApiEndPoint.callReject(callId),
    query: {'reason': ?reason},
  );

  Future<Either<NetworkErrorModel, CallModel>> end(String callId) =>
      _send(HttpMethods.post, ApiEndPoint.callEnd(callId));

  /// The call as the server sees it NOW (after a reconnect).
  Future<Either<NetworkErrorModel, CallModel>> load(String callId) =>
      _send(HttpMethods.get, ApiEndPoint.call(callId));

  /// A fresh Stream Video token (Step 6.2) — for the sound and picture.
  Future<Either<NetworkErrorModel, StreamTokenModel>> streamToken() =>
      _appService.send(
        httpMethods: HttpMethods.get,
        endPoint: ApiEndPoint.callStreamToken,
        parse: (json) =>
            StreamTokenModel.fromJson(json as Map<String, dynamic>),
      );

  /// Invites (and "ringing" for my own calls) — for the whole session.
  Stream<CallUpdate> callsQueue() => _updates(ApiEndPoint.callsQueue);

  /// One conversation's call events (while a call there is on screen).
  Stream<CallUpdate> callTopic(String conversationId) =>
      _updates(ApiEndPoint.callTopic(conversationId));

  /// The socket came back: events during the drop are lost → resync.
  Stream<void> get reconnected => _realtime.reconnected;

  Stream<CallUpdate> _updates(String destination) => _realtime
      .subscribe(destination)
      .map(CallUpdate.fromRealtime)
      .where((u) => u != null)
      .cast<CallUpdate>();

  Future<Either<NetworkErrorModel, CallModel>> _send(
    HttpMethods method,
    String endPoint, {
    Map<String, Object?>? data,
    Map<String, Object?>? query,
  }) => _appService.send(
    httpMethods: method,
    endPoint: endPoint,
    data: data,
    queryParameters: query,
    parse: (json) => CallModel.fromJson(json as Map<String, dynamic>),
  );
}
