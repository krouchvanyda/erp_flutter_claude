import 'package:erp_mobile/core/utils/logger/app_logger.dart';
import 'package:erp_mobile/core/error/crash_reporter.dart';

/// Default [CrashReporter] — funnels every report to [AppLogger].
///
/// Severity maps to log level:
/// - `warning` → `warn`
/// - `error`   → `error`
/// - `fatal`   → `fatal`
///
/// Replace the DI binding when you wire a real telemetry SDK
/// (Sentry / Crashlytics) — the rest of the codebase only depends on the
/// abstract [CrashReporter].
class LoggingCrashReporter extends CrashReporter {
  LoggingCrashReporter(this._logger);

  final AppLogger _logger;

  @override
  void report(
    Object error,
    StackTrace? stack, {
    CrashSeverity severity = CrashSeverity.error,
    String? description,
    Map<String, Object?>? context,
  }) {
    final message = description ?? error.toString();
    switch (severity) {
      case CrashSeverity.warning:
        _logger.warn(message,
            error: error, stackTrace: stack, context: context);
      case CrashSeverity.error:
        _logger.error(message,
            error: error, stackTrace: stack, context: context);
      case CrashSeverity.fatal:
        _logger.fatal(message,
            error: error, stackTrace: stack, context: context);
    }
  }
}
