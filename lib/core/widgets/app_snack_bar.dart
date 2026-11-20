import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_font_size.dart';
import '../theme/app_label.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_status_colors.dart';

/// What kind of message: picks the colour and the icon.
enum AppSnackBarType { error, warning, success, info }

/// The app's one message bar, shown at the TOP of the screen
/// (the MVVM template's `SnackBarHelper.show`, themed and responsive).
///
/// ```dart
/// AppSnackBar.error(context, title: error.title, message: error.description);
/// AppSnackBar.success(context, message: 'Profile saved');
/// AppSnackBar.warning(context, message: 'Weak connection');
/// AppSnackBar.hide();
/// ```
///
/// Why an Overlay and not Flutter's `SnackBar`? A `SnackBar` can only sit at
/// the BOTTOM. An `OverlayEntry` floats above every page, anywhere we like.
///
/// - Colours from `colorScheme` → dark mode works by itself.
/// - Never wider than [_maxWidth] (tablet).
/// - A new one REPLACES the old one (no queue).
/// - Slides down; goes away after [show]'s `duration`, on ✕, or swipe up.
abstract final class AppSnackBar {
  static const double _maxWidth = 420;

  static OverlayEntry? _entry;
  static GlobalKey<_TopBarState>? _key;

  static void error(
    BuildContext context, {
    required String message,
    String? title,
  }) => show(
    context,
    message: message,
    title: title,
    type: AppSnackBarType.error,
  );

  static void success(
    BuildContext context, {
    required String message,
    String? title,
  }) => show(
    context,
    message: message,
    title: title,
    type: AppSnackBarType.success,
  );

  static void warning(
    BuildContext context, {
    required String message,
    String? title,
  }) => show(
    context,
    message: message,
    title: title,
    type: AppSnackBarType.warning,
  );

  static void info(
    BuildContext context, {
    required String message,
    String? title,
  }) => show(context, message: message, title: title);

  static void show(
    BuildContext context, {
    required String message,
    String? title,
    AppSnackBarType type = AppSnackBarType.info,
    Duration duration = const Duration(seconds: 4),
  }) {
    _removeNow(); // replace, don't queue

    final key = GlobalKey<_TopBarState>();
    final entry = OverlayEntry(
      builder: (_) => _TopBar(
        key: key,
        type: type,
        title: title,
        message: message,
        duration: duration,
        onGone: _removeNow,
      ),
    );
    _key = key;
    _entry = entry;
    // rootOverlay: above every page, even dialogs pushed later.
    Overlay.of(context, rootOverlay: true).insert(entry);
  }

  /// Slide the current bar away (e.g. when the user tries again).
  static void hide() => _key?.currentState?.dismiss();

  static void _removeNow() {
    _entry?.remove();
    _entry = null;
    _key = null;
  }
}

class _TopBar extends StatefulWidget {
  const _TopBar({
    super.key,
    required this.type,
    required this.title,
    required this.message,
    required this.duration,
    required this.onGone,
  });

  final AppSnackBarType type;
  final String? title;
  final String message;
  final Duration duration;
  final VoidCallback onGone;

  @override
  State<_TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<_TopBar> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  )..forward(); // slide in right away

  late final Animation<Offset> _slide = Tween(
    begin: const Offset(0, -1.2), // start just above the screen
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  Timer? _timer;
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.duration, dismiss);
  }

  /// Slide up, then remove the overlay entry.
  Future<void> dismiss() async {
    if (_dismissing || !mounted) return;
    _dismissing = true;
    _timer?.cancel();
    await _controller.reverse();
    widget.onGone();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final status = context.statusColors; // success · warning · error
    final (background, foreground, icon) = switch (widget.type) {
      AppSnackBarType.error => (
        status.error,
        status.onError,
        Icons.error_outline,
      ),
      AppSnackBarType.warning => (
        status.warning,
        status.onWarning,
        Icons.warning_amber_rounded,
      ),
      AppSnackBarType.success => (
        status.success,
        status.onSuccess,
        Icons.check_circle_outline,
      ),
      AppSnackBarType.info => (
        colors.inverseSurface,
        colors.onInverseSurface,
        Icons.info_outline,
      ),
    };

    return Align(
      alignment: Alignment.topCenter,
      child: SafeArea(
        // below the notch / status bar
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSnackBar._maxWidth),
            child: SlideTransition(
              position: _slide,
              child: Dismissible(
                key: const ValueKey('app-snack-bar'),
                direction: DismissDirection.up, // swipe up to close
                onDismissed: (_) => widget.onGone(),
                child: Material(
                  color: background,
                  elevation: 6,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.sm + 4,
                      AppSpacing.xs,
                      AppSpacing.sm + 4,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(icon, color: foreground, size: 20),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (widget.title != null) ...[
                                  AppLabel(
                                    text: widget.title!,
                                    fontSize: AppFontSize.value14,
                                    fontWeight: FontWeight.w600,
                                    color: foreground,
                                  ),
                                  const SizedBox(height: 2),
                                ],
                                AppLabel(
                                  text: widget.message,
                                  fontSize: AppFontSize.value14,
                                  color: foreground,
                                ),
                              ],
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          visualDensity: VisualDensity.compact,
                          onPressed: dismiss,
                          icon: Icon(Icons.close, color: foreground, size: 18),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
