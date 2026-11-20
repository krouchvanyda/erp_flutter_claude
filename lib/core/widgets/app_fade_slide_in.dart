import 'package:flutter/material.dart';

/// Fade + small slide up, once, when the page appears (300 ms, calm).
/// Reusable: login now, profile and other pages later.
class AppFadeSlideIn extends StatelessWidget {
  const AppFadeSlideIn({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      child: child, // built once, not on every animation frame
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - t)),
          child: child,
        ),
      ),
    );
  }
}
