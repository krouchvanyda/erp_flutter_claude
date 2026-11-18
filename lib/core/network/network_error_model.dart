import 'package:get/get.dart' show Trans;

import '../error/failure.dart';

/// UI-friendly error from [AppService.send] (template: `NetworkErrorModel`).
///
/// Built from the app's typed [Failure], so the screen can show [title] +
/// [description] (already translated) and still branch on [failure] when it
/// needs to (e.g. `failure is UnauthorizedFailure`).
class NetworkErrorModel {
  const NetworkErrorModel({
    required this.title,
    required this.description,
    required this.statusCode,
    this.failure,
  });

  /// No connection (template `Constants.codeNetwork`).
  static const int codeNetwork = -1;

  /// Unknown / unexpected error (template `Constants.codeUnknown`).
  static const int codeUnknown = 0;

  final String title;
  final String description;

  /// HTTP status when the server answered; [codeNetwork] / [codeUnknown]
  /// otherwise.
  final int statusCode;

  /// The typed failure behind this error (null when built from JSON).
  final Failure? failure;

  factory NetworkErrorModel.fromFailure(Failure f) {
    NetworkErrorModel make(String titleKey, String bodyKey, int code,
            [String? serverMessage]) =>
        NetworkErrorModel(
          title: titleKey.tr,
          description: (serverMessage != null && serverMessage.isNotEmpty)
              ? serverMessage
              : bodyKey.tr,
          statusCode: code,
          failure: f,
        );

    return switch (f) {
      NetworkFailure() => make('networkNoInternetTitle',
          'networkNoInternetBody', codeNetwork),
      TimeoutFailure() =>
        make('networkTimeoutTitle', 'networkTimeoutBody', 408),
      UnauthorizedFailure() =>
        make('networkUnauthorizedTitle', 'networkUnauthorizedBody', 401),
      ForbiddenFailure(:final message) => make(
          'networkForbiddenTitle', 'networkForbiddenBody', 403, message),
      NotFoundFailure(:final message) =>
        make('networkNotFoundTitle', 'networkNotFoundBody', 404, message),
      ValidationFailure(:final message) => make(
          'networkValidationTitle', 'networkValidationBody', 422, message),
      ConflictFailure(:final message) =>
        make('networkConflictTitle', 'networkConflictBody', 409, message),
      RateLimitFailure() =>
        make('networkRateLimitTitle', 'networkRateLimitBody', 429),
      ServerFailure(:final statusCode) => make('networkServerTitle',
          'networkServerBody', statusCode ?? 500),
      CancelledFailure() =>
        make('networkCancelledTitle', 'networkCancelledBody', codeUnknown),
      UnknownFailure() =>
        make('networkUnknownTitle', 'networkUnknownBody', codeUnknown),
    };
  }

  /// Optional: parse an error body from the API.
  factory NetworkErrorModel.fromJson(Map<String, dynamic> json) {
    return NetworkErrorModel(
      title: json['title']?.toString() ?? 'networkUnknownTitle'.tr,
      description: (json['message'] ?? json['error'])?.toString() ??
          'networkUnknownBody'.tr,
      statusCode: json['statusCode'] is int ? json['statusCode'] as int : 500,
    );
  }

  @override
  String toString() => 'NetworkErrorModel($statusCode, $title: $description)';
}
