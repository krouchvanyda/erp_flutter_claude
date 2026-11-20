import 'package:flutter/material.dart';

import '../../../core/theme/app_font_size.dart';
import '../../../core/theme/app_label.dart';
import '../../../core/theme/app_spacing.dart';

/// What sits ON TOP of the video: the name + status at the top, the buttons
/// at the bottom, each on a soft dark fade so they stay readable on any
/// picture.
///
/// ```
/// ▓▓ Jane Doe            ▓▓  ← fade
///    01:15
///
///        (video)
///
/// ▓▓ (🎙) (🎥) (🔄) (🔊) ▓▓  ← fade
/// ▓▓       (⛔ End)       ▓▓
/// ```
class CallVideoOverlay extends StatelessWidget {
  const CallVideoOverlay({
    super.key,
    required this.name,
    required this.status,
    required this.controls,
  });

  final String name;
  final Widget status;
  final Widget controls;

  @override
  Widget build(BuildContext context) {
    final scrim = Theme.of(context).colorScheme.scrim;
    BoxDecoration fade(Alignment from) => BoxDecoration(
      gradient: LinearGradient(
        begin: from,
        end: -from,
        colors: [scrim.withValues(alpha: 0.6), scrim.withValues(alpha: 0)],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch, // fades = full width
      children: [
        DecoratedBox(
          decoration: fade(Alignment.topCenter),
          child: SafeArea(
            bottom: false,
            child: Padding(
              // leave room for my small camera on the right
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.lg,
                AppSpacing.md,
                136,
                AppSpacing.xl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppLabel(
                    text: name.isEmpty ? '…' : name,
                    fontSize: AppFontSize.value20,
                    fontWeight: FontWeight.w700,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  status,
                ],
              ),
            ),
          ),
        ),
        const Spacer(),
        DecoratedBox(
          decoration: fade(Alignment.bottomCenter),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.only(
                top: AppSpacing.xxl,
                bottom: AppSpacing.lg,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: controls,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
