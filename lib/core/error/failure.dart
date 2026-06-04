import 'package:collection/collection.dart';

/// Cross-cutting failure type returned by every repository.
///
/// Sealed so callers can pattern-match exhaustively:
///
/// ```dart
/// switch (failure) {
///   case NetworkFailure():       'no internet';
///   case TimeoutFailure():       'slow connection';
///   case ServerFailure(:final statusCode):
///                                'server $statusCode';
///   case UnauthorizedFailure():  'session expired';
///   case ForbiddenFailure():     'not allowed';
///   case NotFoundFailure():      'gone';
///   case ValidationFailure(:final fieldErrors):
///                                'fix ${fieldErrors.keys}';
///   case ConflictFailure():      'merge conflict';
///   case RateLimitFailure(:final retryAfter):
///                                'try again in $retryAfter';
///   case CancelledFailure():     'aborted';
///   case UnknownFailure():       'unexpected';
/// }
/// ```
sealed class Failure {
  const Failure();

  /// No connectivity / DNS / TLS handshake failure.
  const factory Failure.network({String? message}) = NetworkFailure;

  /// Connect / send / receive timed out before the server responded.
  const factory Failure.timeout({String? message}) = TimeoutFailure;

  /// 5xx — server is unhappy. Include `statusCode` for surfacing in toasts.
  const factory Failure.server({
    int? statusCode,
    String? message,
  }) = ServerFailure;

  /// 401 surfaced *after* the auth interceptor's refresh attempt failed.
  /// Treat as "session ended; route to login."
  const factory Failure.unauthorized({String? message}) = UnauthorizedFailure;

  /// 403 — caller is authenticated but lacks permission.
  const factory Failure.forbidden({String? message}) = ForbiddenFailure;

  /// 404 — resource missing.
  const factory Failure.notFound({String? message}) = NotFoundFailure;

  /// 400 / 422 — request shape was rejected. `fieldErrors` lists the
  /// per-field messages so forms can highlight inputs.
  const factory Failure.validation({
    Map<String, List<String>> fieldErrors,
    String? message,
  }) = ValidationFailure;

  /// 409 — conflicting resource state (optimistic concurrency, etc.).
  const factory Failure.conflict({String? message}) = ConflictFailure;

  /// 429 — caller is being throttled. `retryAfter` is parsed from the
  /// `Retry-After` header when present.
  const factory Failure.rateLimited({
    Duration? retryAfter,
    String? message,
  }) = RateLimitFailure;

  /// Request was cancelled (CancelToken, navigation away, etc.).
  const factory Failure.cancelled() = CancelledFailure;

  /// Catch-all. Always carries a message so logs aren't blind.
  const factory Failure.unknown({String? message}) = UnknownFailure;
}

class NetworkFailure extends Failure {
  const NetworkFailure({this.message});
  final String? message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NetworkFailure &&
          runtimeType == other.runtimeType &&
          message == other.message;

  @override
  int get hashCode => Object.hash(runtimeType, message);
}

class TimeoutFailure extends Failure {
  const TimeoutFailure({this.message});
  final String? message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimeoutFailure &&
          runtimeType == other.runtimeType &&
          message == other.message;

  @override
  int get hashCode => Object.hash(runtimeType, message);
}

class ServerFailure extends Failure {
  const ServerFailure({this.statusCode, this.message});
  final int? statusCode;
  final String? message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServerFailure &&
          runtimeType == other.runtimeType &&
          statusCode == other.statusCode &&
          message == other.message;

  @override
  int get hashCode => Object.hash(runtimeType, statusCode, message);
}

class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure({this.message});
  final String? message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UnauthorizedFailure &&
          runtimeType == other.runtimeType &&
          message == other.message;

  @override
  int get hashCode => Object.hash(runtimeType, message);
}

class ForbiddenFailure extends Failure {
  const ForbiddenFailure({this.message});
  final String? message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ForbiddenFailure &&
          runtimeType == other.runtimeType &&
          message == other.message;

  @override
  int get hashCode => Object.hash(runtimeType, message);
}

class NotFoundFailure extends Failure {
  const NotFoundFailure({this.message});
  final String? message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotFoundFailure &&
          runtimeType == other.runtimeType &&
          message == other.message;

  @override
  int get hashCode => Object.hash(runtimeType, message);
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
      identical(this, other) ||
      other is ValidationFailure &&
          runtimeType == other.runtimeType &&
          const DeepCollectionEquality().equals(fieldErrors, other.fieldErrors) &&
          message == other.message;

  @override
  int get hashCode => Object.hash(
        runtimeType,
        const DeepCollectionEquality().hash(fieldErrors),
        message,
      );
}

class ConflictFailure extends Failure {
  const ConflictFailure({this.message});
  final String? message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConflictFailure &&
          runtimeType == other.runtimeType &&
          message == other.message;

  @override
  int get hashCode => Object.hash(runtimeType, message);
}

class RateLimitFailure extends Failure {
  const RateLimitFailure({this.retryAfter, this.message});
  final Duration? retryAfter;
  final String? message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RateLimitFailure &&
          runtimeType == other.runtimeType &&
          retryAfter == other.retryAfter &&
          message == other.message;

  @override
  int get hashCode => Object.hash(runtimeType, retryAfter, message);
}

class CancelledFailure extends Failure {
  const CancelledFailure();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CancelledFailure && runtimeType == other.runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;
}

class UnknownFailure extends Failure {
  const UnknownFailure({this.message});
  final String? message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UnknownFailure &&
          runtimeType == other.runtimeType &&
          message == other.message;

  @override
  int get hashCode => Object.hash(runtimeType, message);
}
