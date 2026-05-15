import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Picks the right system-bar icon brightness for the current page.
///
/// **The naming trap to avoid**: Flutter's `SystemUiOverlayStyle.light`
/// means *light icons* (used on **dark** backgrounds), and
/// `.dark` means *dark icons* (used on **light** backgrounds). To stop
/// callers tripping over that we accept a [surfaceBrightness] —
/// "what brightness is the page background?" — and resolve the icon
/// brightness internally.
///
/// **Why a widget, not a one-shot
/// `SystemChrome.setSystemUIOverlayStyle`**: the `setSystemUIOverlayStyle`
/// call sticks until the next call, so a stale value bleeds across
/// route transitions. `AnnotatedRegion` is reactive — when the
/// containing route is the topmost, its style applies; when another
/// route covers it, the other route's annotation takes over.
///
/// Pass [surfaceBrightness] when the page background doesn't match the
/// active `Theme.of(context).brightness` (e.g. the splash page, which
/// is always dark even in a light theme):
/// ```dart
/// AdaptiveStatusBar(
///   surfaceBrightness: Brightness.dark,  // gradient is dark blue
///   child: Scaffold(...),
/// )
/// ```
///
/// Omit it for theme-following pages (Settings, Dashboard, …) — the
/// widget reads the active theme and matches.
class AdaptiveStatusBar extends StatelessWidget {
  const AdaptiveStatusBar({
    super.key,
    this.surfaceBrightness,
    required this.child,
  });

  /// Brightness of the page **background** behind the system bars.
  /// `null` = follow `Theme.of(context).brightness`.
  final Brightness? surfaceBrightness;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final surface =
        surfaceBrightness ?? Theme.of(context).brightness;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _styleFor(surface),
      child: child,
    );
  }

  /// Maps **surface** brightness to the corresponding icon style for
  /// both Android (statusBarIconBrightness / nav-bar) and iOS
  /// (statusBarBrightness — iOS reads the *background* directly).
  static SystemUiOverlayStyle _styleFor(Brightness surface) {
    final isLightSurface = surface == Brightness.light;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      // Android — icon colour.
      statusBarIconBrightness:
          isLightSurface ? Brightness.dark : Brightness.light,
      // iOS — describes the surface, not the icons.
      statusBarBrightness:
          isLightSurface ? Brightness.light : Brightness.dark,
      // Android nav bar — match the status bar so both feel cohesive.
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness:
          isLightSurface ? Brightness.dark : Brightness.light,
      systemNavigationBarDividerColor: Colors.transparent,
    );
  }
}
