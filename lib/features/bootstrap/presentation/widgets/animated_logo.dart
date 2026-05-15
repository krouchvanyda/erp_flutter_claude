import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_label.dart';

/// Splash brand mark with a combined fade + scale entrance.
///
/// **Why a combined animation, not just fade**: a pure fade reads as
/// "the page hasn't finished loading yet". A subtle scale-up plus the
/// fade reads as "the app is presenting itself" — same intent as the
/// iOS / Android system splash that scales the launcher icon up to
/// the foreground.
///
/// Tunable knobs (defaults match the spec's "≤ 1.5s" budget):
/// - [duration] — total animation time
/// - [initialScale] — starting scale (1.0 = no scaling)
/// - [iconData] — replace with the real brand glyph when it lands
class AnimatedLogo extends StatefulWidget {
  const AnimatedLogo({
    super.key,
    this.duration = const Duration(milliseconds: 900),
    this.initialScale = 0.85,
    this.iconData = Icons.business_center_outlined,
    this.label = 'ERP Mobile',
  });

  final Duration duration;
  final double initialScale;
  final IconData iconData;
  final String label;

  @override
  State<AnimatedLogo> createState() => _AnimatedLogoState();
}

class _AnimatedLogoState extends State<AnimatedLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  late final Animation<double> _fade =
      CurvedAnimation(parent: _controller, curve: Curves.easeOut);

  late final Animation<double> _scale = Tween<double>(
    begin: widget.initialScale,
    end: 1.0,
  ).animate(CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  ));

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.splashForeground.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppColors.splashForeground.withValues(alpha: 0.25),
                  width: 1.5,
                ),
              ),
              child: Icon(
                widget.iconData,
                size: 48,
                color: AppColors.splashForeground,
              ),
            ),
            const SizedBox(height: 16),
            AppLabel(
              widget.label,
              variant: AppLabelVariant.splashLogo,
              color: AppColors.splashForeground,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ],
        ),
      ),
    );
  }
}
