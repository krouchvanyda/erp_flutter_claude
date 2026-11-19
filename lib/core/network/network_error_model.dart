import '../utils/constants.dart';

/// Everything that can go wrong with a request.
///
/// Same shape as the MVVM template (`title`, `description`, `statusCode`),
/// so `error.title` / `error.description` work everywhere. It is `sealed`, so
/// you can also `switch` on the kind and the compiler checks you covered all:
///
/// ```
///                    NetworkErrorModel
///   ┌──────────────┬───────┴────────┬────────────────┐
/// NoInternetError ServerError  UnauthorizedError  UnknownError
/// (offline,       (4xx/5xx,    (401: session      (bad JSON,
///  timeout,        success:     is over)            a bug)
///  server down)    false)
/// ```
sealed class NetworkErrorModel {
  const NetworkErrorModel({
    required this.title,
    required this.description,
    required this.statusCode,
  });

  final String title;
  final String description;

  /// The HTTP status, or [Constants.codeNetwork] / [Constants.codeUnknown].
  final int statusCode;

  @override
  String toString() => '$runtimeType($statusCode, $title: $description)';
}

/// The phone is offline, the server is unreachable, or a timeout.
final class NoInternetError extends NetworkErrorModel {
  const NoInternetError({
    super.title = Constants.noInternet,
    super.description = Constants.pleaseCheckInternet,
  }) : super(statusCode: Constants.codeNetwork);
}

/// The server answered with an error (4xx / 5xx, or `success: false`).
final class ServerError extends NetworkErrorModel {
  const ServerError({
    required super.description,
    required super.statusCode,
    super.title = Constants.serverError,
    this.errorCode,
    this.fieldErrors = const {},
    this.traceId,
  });

  /// The backend's machine code, e.g. `VALIDATION_ERROR`.
  final String? errorCode;

  /// Form validation errors: field name → message (`{"email": "invalid"}`).
  final Map<String, String> fieldErrors;

  /// Give this to the backend team to find the request in their logs.
  final String? traceId;
}

/// 401 — the session is over (Step 2.2: only after refresh also failed).
final class UnauthorizedError extends NetworkErrorModel {
  const UnauthorizedError()
    : super(
        title: Constants.sessionExpired,
        description: Constants.pleaseLoginAgain,
        statusCode: 401,
      );
}

/// Anything we didn't expect (bad JSON, a bug in our parser…).
final class UnknownError extends NetworkErrorModel {
  const UnknownError({super.description = Constants.somethingWentWrong})
    : super(title: Constants.unKnownError, statusCode: Constants.codeUnknown);
}
