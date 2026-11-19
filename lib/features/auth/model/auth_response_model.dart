import '../../../core/network/auth_tokens.dart';
import 'user_model.dart';

/// What login / register / refresh return (`AuthResponse`):
/// the token pair + the user.
class AuthResponseModel {
  const AuthResponseModel({required this.tokens, required this.user});

  final AuthTokens tokens;
  final UserModel user;

  /// A `Parser` for `AppService.send(parse: AuthResponseModel.fromData)`.
  factory AuthResponseModel.fromData(Object? data) {
    final json = data as Map<String, dynamic>;
    return AuthResponseModel(
      tokens: AuthTokens.fromJson(json), // reads accessToken, refreshToken…
      user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}
