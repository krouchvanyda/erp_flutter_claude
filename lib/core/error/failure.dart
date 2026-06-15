import 'package:collection/collection.dart';

/// Cross-cutting failure type returned by every repository.
///
/// Plain Dart 3 `sealed class` (was `freezed`; the codegen was removed).
/// Factory redirects preserve `Failure.network(...)` etc.; callers
/// pattern-match exhaustively on the subtypes:
///
/// ```dart
/// switch (failure) {
///   case NetworkFailure():       'no internet';
///   case ServerFailure(:final statusCode): 'server $statusCode';
///   ...
/// }
/// ```
sealed class Failure {
  const Failure();

  /// No connectivity / DNS / TLS handshake failure.
  const factory Failure.network({String? message}) = NetworkFailure;

  /// Connect / send / receive timed out before the server responded.
  const factory Failure.timeout({String? message}) = TimeoutFailure;

  /// 5xx — server is unhappy.
  const factory Failure.server({int? statusCode, String? message}) =
      ServerFailure;

  /// 401 surfaced after the auth interceptor's refresh attempt failed.
  const factory Failure.unauthorized({String? message}) = UnauthorizedFailure;

  /// 403 — authenticated but lacks permission.
  const factory Failure.forbidden({String? message}) = ForbiddenFailure;

  /// 404 — resource missing.
  const factory Failure.notFound({String? message}) = NotFoundFailure;

  /// 400 / 422 — request shape rejected.
  const factory Failure.validation({
    Map<String, List<String>> fieldErrors,
    String? message,
  }) = ValidationFailure;

  /// 409 — conflicting resource state.
  const factory Failure.conflict({String? message}) = ConflictFailure;

  /// 429 — caller is being throttled.
  const factory Failure.rateLimited({Duration? retryAfter, String? message}) =
      RateLimitFailure;

  /// Request was cancelled.
  const factory Failure.cancelled() = CancelledFailure;

  /// Catch-all.
  const factory Failure.unknown({String? message}) = UnknownFailure;
}

class NetworkFailure extends Failure {
  const NetworkFailure({this.message});
  final String? message;
  @override
  bool operator ==(Object other) =>
      other is NetworkFailure && other.message == message;
  @override
  int get hashCode => Object.hash(NetworkFailure, message);
}

class TimeoutFailure extends Failure {
  const TimeoutFailure({this.message});
  final String? message;
  @override
  bool operator ==(Object other) =>
      other is TimeoutFailure && other.message == message;
  @override
  int get hashCode => Object.hash(TimeoutFailure, message);
}

class ServerFailure extends Failure {
  const ServerFailure({this.statusCode, this.message});
  final int? statusCode;
  final String? message;
  @override
  bool operator ==(Object other) =>
      other is ServerFailure &&
      other.statusCode == statusCode &&
      other.message == message;
  @override
  int get hashCode => Object.hash(ServerFailure, statusCode, message);
}

class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure({this.message});
  final String? message;
  @override
  bool operator ==(Object other) =>
      other is UnauthorizedFailure && other.message == message;
  @override
  int get hashCode => Object.hash(UnauthorizedFailure, message);
}

class ForbiddenFailure extends Failure {
  const ForbiddenFailure({this.message});
  final String? message;
  @override
  bool operator ==(Object other) =>
      other is ForbiddenFailure && other.message == message;
  @override
  int get hashCode => Object.hash(ForbiddenFailure, message);
}

class NotFoundFailure extends Failure {
  const NotFoundFailure({this.message});
  final String? message;
  @override
  bool operator ==(Object other) =>
      other is NotFoundFailure && other.message == message;
  @override
  int get hashCode => Object.hash(NotFoundFailure, message);
}

class ValidationFailure extends Failure {
  const ValidationFailure({
    this.fieldErrors = const <String, List<String>>{},
    this.message,
  });
  final Map<String, List<String>> fieldErrors;
  final String? message;
  @override
  bool operator ==(Object other) =>
      other is ValidationFailure &&
      other.message == message &&
      const DeepCollectionEquality().equals(other.fieldErrors, fieldErrors);
  @override
  int get hashCode => Object.hash(
        ValidationFailure,
        message,
        const DeepCollectionEquality().hash(fieldErrors),
      );
}

class ConflictFailure extends Failure {
  const ConflictFailure({this.message});
  final String? message;
  @override
  bool operator ==(Object other) =>
      other is ConflictFailure && other.message == message;
  @override
  int get hashCode => Object.hash(ConflictFailure, message);
}

class RateLimitFailure extends Failure {
  const RateLimitFailure({this.retryAfter, this.message});
  final Duration? retryAfter;
  final String? message;
  @override
  bool operator ==(Object other) =>
      other is RateLimitFailure &&
      other.retryAfter == retryAfter &&
      other.message == message;
  @override
  int get hashCode => Object.hash(RateLimitFailure, retryAfter, message);
}

class CancelledFailure extends Failure {
  const CancelledFailure();
  @override
  bool operator ==(Object other) => other is CancelledFailure;
  @override
  int get hashCode => (CancelledFailure).hashCode;
}

class UnknownFailure extends Failure {
  const UnknownFailure({this.message});
  final String? message;
  @override
  bool operator ==(Object other) =>
      other is UnknownFailure && other.message == message;
  @override
  int get hashCode => Object.hash(UnknownFailure, message);
}
