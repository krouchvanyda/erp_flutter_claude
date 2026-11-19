/// The wrapper the backend puts around EVERY JSON response:
///
/// ```json
/// { "success": true, "message": "Success", "data": { … },
///   "errorCode": null, "traceId": "…" }
/// ```
///
/// We unwrap it in ONE place (`AppService`), so repositories only see `data`.
class ApiEnvelope {
  const ApiEnvelope({
    required this.success,
    required this.message,
    required this.data,
    this.errorCode,
    this.traceId,
  });

  final bool success;
  final String message;
  final Object? data;
  final String? errorCode;
  final String? traceId;

  /// Returns null when [json] is not an envelope (a plain JSON body).
  /// (API_LIST_BACKEND.md says `/health` is plain `{ "status": "UP" }`, but the
  /// real server wraps it too — we accept both.)
  static ApiEnvelope? tryParse(Object? json) {
    if (json is! Map<String, dynamic> || json['success'] is! bool) return null;
    return ApiEnvelope(
      success: json['success'] as bool,
      message: json['message'] as String? ?? '',
      data: json['data'],
      errorCode: json['errorCode'] as String?,
      traceId: json['traceId'] as String?,
    );
  }

  /// `data.fieldErrors` as `{field: message}`. Accepts both shapes a backend
  /// may send: a map, or a list of `{field, message}` objects.
  Map<String, String> get fieldErrors {
    final raw = data is Map<String, dynamic>
        ? (data as Map<String, dynamic>)['fieldErrors']
        : null;
    if (raw is Map) {
      return raw.map((k, v) => MapEntry('$k', '$v'));
    }
    if (raw is List) {
      return {
        for (final e in raw.whereType<Map>())
          '${e['field']}': '${e['message'] ?? e['defaultMessage'] ?? ''}',
      };
    }
    return const {};
  }
}
