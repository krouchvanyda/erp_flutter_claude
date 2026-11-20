import 'package:flutter/material.dart';

import '../network/network_error_model.dart';
import '../theme/app_font_size.dart';
import '../theme/app_label.dart';
import '../theme/app_spacing.dart';
import '../utils/constants.dart';
import 'app_button.dart';

/// Full-page "could not load" view with a retry button.
///
/// Use it when a page has NOTHING to show yet (first load failed). When the
/// page already shows data and a refresh fails, use `AppErrorBanner` (a strip
/// above the data) or `AppSnackBar` instead.
///
/// ```
///        ( 📶̸ )
///   No Internet
///   Please check internet connection.
///   [  Try again  ]
/// ```
///
/// Usually built from a [NetworkErrorModel] — the icon then matches the
/// problem (a 500 must not look like a wifi problem):
///
/// ```dart
/// AppErrorView.fromError(state.error, onRetry: () => bloc.add(...))
/// ```
class AppErrorView extends StatelessWidget {
  const AppErrorView({
    super.key,
    required this.title,
    required this.message,
    required this.onRetry,
    this.icon = Icons.cloud_off_rounded,
    this.isServerProblem = false,
  });

  /// Title, message AND icon from the error.
  AppErrorView.fromError(
    NetworkErrorModel error, {
    Key? key,
    required VoidCallback onRetry,
  }) : this(
         key: key,
         title: error.title,
         message: error.description,
         onRetry: onRetry,
         icon: iconFor(error),
         isServerProblem: error is ServerError || error is UnknownError,
       );

  final String title;
  final String message;
  final VoidCallback onRetry;
  final IconData icon;

  /// true → red-tinted icon ("something broke"). false → calm grey
  /// ("check your connection").
  final bool isServerProblem;

  /// The picture for each kind of error. `switch` on the SEALED class: add a
  /// new error type and the compiler makes you pick an icon here.
  ///
  /// | Error                          | Icon        |
  /// |--------------------------------|-------------|
  /// | NoInternetError (phone offline)| 📶̸ wifi off |
  /// | NoInternetError (server down)  | ☁̸ cloud off |
  /// | NoInternetError (timeout)      | ⏳ hourglass |
  /// | ServerError (4xx / 5xx)        | ⚠ error     |
  /// | UnauthorizedError              | 🔒 lock     |
  /// | UnknownError                   | ? help      |
  static IconData iconFor(NetworkErrorModel error) => switch (error) {
    // The 3 NoInternetError cases share a type; their titles are our own
    // constants (AppService), so comparing them is safe.
    NoInternetError(title: Constants.timeout) => Icons.hourglass_empty_rounded,
    NoInternetError(title: Constants.serverUnreachable) =>
      Icons.cloud_off_rounded,
    NoInternetError() => Icons.wifi_off_rounded,
    ServerError() => Icons.error_outline_rounded,
    UnauthorizedError() => Icons.lock_outline_rounded,
    UnknownError() => Icons.help_outline_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: isServerProblem
                      ? colors.errorContainer
                      : colors.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 36,
                  color: isServerProblem
                      ? colors.error
                      : colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppLabel(
                text: title,
                fontSize: AppFontSize.value18,
                fontWeight: FontWeight.w600,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              AppLabel(
                text: message,
                fontSize: AppFontSize.value14,
                color: colors.onSurfaceVariant,
                textAlign: TextAlign.center,
                lineHeight: 1.5,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                text: 'Try again',
                icon: const Icon(Icons.refresh_rounded),
                onPressed: onRetry,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
