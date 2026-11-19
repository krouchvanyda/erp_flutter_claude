import 'package:dartz/dartz.dart' show Either, Left, Right;

import '../../../core/network/api_endpoints.dart';
import '../../../core/network/app_service.dart';
import '../../../core/network/helper_service.dart';
import '../../../core/network/network_error_model.dart';
import '../../../core/network/token_storage.dart';
import '../../../core/router/auth_session.dart';
import '../model/auth_response_model.dart';
import '../model/user_model.dart';

/// Auth business rules. The BLoC calls this; it never touches Dio or tokens.
///
/// login = ask the server → SAVE the tokens → OPEN the session.
/// The order matters: tokens are saved BEFORE the session opens, so the very
/// first request after login already carries the token.
class AuthRepository {
  AuthRepository({
    required AppService appService,
    required TokenStorage tokenStorage,
    required AuthSession session,
  }) : _appService = appService,
       _tokenStorage = tokenStorage,
       _session = session;

  final AppService _appService;
  final TokenStorage _tokenStorage;
  final AuthSession _session;

  Future<Either<NetworkErrorModel, UserModel>> login({
    required String email,
    required String password,
  }) async {
    final result = await _appService.send(
      httpMethods: HttpMethods.post,
      endPoint: ApiEndPoint.login,
      data: {'email': email.trim(), 'password': password},
      parse: AuthResponseModel.fromData,
    );

    // fold = handle both boxes. The success side is async (we save tokens),
    // so both sides return a Future.
    return result.fold<Future<Either<NetworkErrorModel, UserModel>>>(
      (error) async => Left(error), // wrong password, offline… → pass it up
      (response) async {
        await _tokenStorage.write(response.tokens); // 1. save tokens
        _session.markAuthenticated(); //               2. open the session
        return Right(response.user);
      },
    );
  }
}
