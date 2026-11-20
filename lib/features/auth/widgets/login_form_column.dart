import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_fade_slide_in.dart';
import 'login_brand_row.dart';
import 'login_form.dart';
import 'login_secure_note.dart';
import 'login_titles.dart';

/// The login content: centered, max [maxWidth] wide, scrollable (keyboard),
/// with an entry animation.
///
/// ```
/// LoginBrandRow   (phone only)
/// LoginTitles
/// LoginForm
/// LoginSecureNote
/// ```
class LoginFormColumn extends StatelessWidget {
  const LoginFormColumn({super.key, required this.showBrandHeader});

  /// Forms are never wider than this (CLAUDE.md: forms ≤ 420).
  static const double maxWidth = 420;

  /// On phones the brand sits above the form; on wide screens it's the
  /// left panel instead.
  final bool showBrandHeader;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xl,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxWidth),
          child: AppFadeSlideIn(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showBrandHeader) ...[
                  const LoginBrandRow(),
                  const SizedBox(height: AppSpacing.xl),
                ],
                const LoginTitles(),
                Container(
                  margin: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  child: LoginForm(),
                ),
                const LoginSecureNote(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
