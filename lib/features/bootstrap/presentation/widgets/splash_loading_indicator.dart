import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Subtle linear progress indicator for the splash screen.
///
/// Sits below the [AnimatedLogo] and above the [AppVersionText]. Fixed
/// width so it doesn't span the whole screen and read as an "actual
/// progress" bar — the spec calls for *subtle*, not aggressive.
class SplashLoadingIndicator extends StatelessWidget {
  const SplashLoadingIndicator({
    super.key,
    this.width = 96,
  });

  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: LinearProgressIndicator(
          minHeight: 3,
          backgroundColor: AppColors.splashForeground.withValues(alpha: 0.15),
          valueColor:
              const AlwaysStoppedAnimation<Color>(AppColors.splashMuted),
        ),
      ),
    );
  }
}
