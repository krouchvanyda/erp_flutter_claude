import 'package:flutter/material.dart';

import '../network/network_error_model.dart';
import '../theme/app_font_size.dart';
import '../theme/app_label.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import 'app_error_view.dart';

/// A small error strip ABOVE data that is still on screen.
///
/// ```
/// ┌───────────────────────────────────────────┐
/// │ (☁̸) No Internet                Try again │
/// │      Please check internet connection.    │
/// └───────────────────────────────────────────┘
///   (JD) Jane Doe ...        ← the old list stays readable
/// ```
///
/// - Nothing on screen yet → use [AppErrorView] (full page) instead.
/// - Same icon + colours as [AppErrorView] (grey = connection, red = server).
/// - [onRetry] returns a Future: while it runs, "Try again" becomes a small
///   spinner, and taps are ignored (no double requests).
class AppErrorBanner extends StatefulWidget {
  const AppErrorBanner({super.key, required this.error, required this.onRetry});

  final NetworkErrorModel error;
  final Future<void> Function() onRetry;

  @override
  State<AppErrorBanner> createState() => _AppErrorBannerState();
}

class _AppErrorBannerState extends State<AppErrorBanner> {
  bool _retrying = false;

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    try {
      await widget.onRetry();
    } finally {
      // The banner may be gone already (retry worked → list without banner).
      if (mounted) setState(() => _retrying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final error = widget.error;
    final serverProblem = error is ServerError || error is UnknownError;
    final background = serverProblem
        ? colors.errorContainer
        : colors.surfaceContainerHighest;
    final foreground = serverProblem
        ? colors.onErrorContainer
        : colors.onSurfaceVariant;

    return Semantics(
      liveRegion: true, // screen readers announce it when it appears
      child: Container(
        margin: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.xs,
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm + 4,
          AppSpacing.sm + 2,
          AppSpacing.xs,
          AppSpacing.sm + 2,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            Icon(
              AppErrorView.iconFor(error),
              size: 22,
              color: serverProblem ? colors.error : foreground,
            ),
            const SizedBox(width: AppSpacing.sm + 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppLabel(
                    text: error.title,
                    fontSize: AppFontSize.value14,
                    fontWeight: FontWeight.w600,
                    color: serverProblem ? colors.onErrorContainer : null,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  AppLabel(
                    text: error.description,
                    fontSize: AppFontSize.value12,
                    color: foreground,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            SizedBox(
              height: 40,
              child: Center(
                child: _retrying
                    ? const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppSpacing.md + 4,
                        ),
                        child: SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : TextButton(
                        onPressed: _retry,
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 40),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm + 4,
                          ),
                          foregroundColor: serverProblem
                              ? colors.error
                              : colors.primary,
                        ),
                        child: const AppLabel(
                          text: 'Try again',
                          fontSize: AppFontSize.value14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
