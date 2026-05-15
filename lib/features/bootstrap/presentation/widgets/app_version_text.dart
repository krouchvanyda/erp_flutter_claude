import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_label.dart';

/// Splash version label.
///
/// **Why a const string and not `package_info_plus`**: keeping the
/// splash dependency-free means it never has to wait on a platform
/// channel before rendering. The build pipeline can rewrite this
/// constant at release time (or hand it the version via `--dart-define`)
/// without touching the widget.
///
/// Pass [migrating] = true to swap the version line for a "Updating
/// data…" line, per the spec note about drift migrations on upgrade.
class AppVersionText extends StatelessWidget {
  const AppVersionText({
    super.key,
    this.version = '1.0.0',
    this.buildNumber = '1',
    this.migrating = false,
  });

  final String version;
  final String buildNumber;
  final bool migrating;

  @override
  Widget build(BuildContext context) {
    final text =
        migrating ? 'Updating local data…' : 'v$version+$buildNumber';
    return AppLabel(
      text,
      variant: AppLabelVariant.labelMedium,
      color: AppColors.splashMuted,
      letterSpacing: 0.4,
    );
  }
}
