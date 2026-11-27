import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_font_size.dart';
import '../theme/app_label.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import 'app_avatar.dart';

/// An in-app "new message" banner at the TOP of the screen (Step 5.7):
/// photo + name + text, like a phone notification, but drawn by the app
/// while it is OPEN (the OS banner is for a closed app).
///
/// ```
/// ┌──────────────────────────────────────┐
/// │ (MB)  Mr Bin                          │  ← tap → onTap (open the chat)
/// │       Hello, are you there?           │  ← swipe up / 4 s → gone
/// └──────────────────────────────────────┘
/// ```
///
/// Like [AppSnackBar]: a root `OverlayEntry` (above every page), a new one
/// REPLACES the old one, colours from the theme (dark mode works).
abstract final class AppMessageBanner {
  static const double _maxWidth = 420;

  static OverlayEntry? _entry;
  static GlobalKey<_BannerState>? _key;

  static void show(
    BuildContext context, {
    required String title,
    required String message,
    String? imageUrl,
    VoidCallback? onTap,
    Duration duration = const Duration(seconds: 4),
  }) {
    _removeNow(); // replace, don't queue
    final key = GlobalKey<_BannerState>();
    final entry = OverlayEntry(
      builder: (_) => _Banner(
        key: key,
        title: title,
        message: message,
        imageUrl: imageUrl,
        onTap: onTap,
        duration: duration,
        onGone: _removeNow,
      ),
    );
    _key = key;
    _entry = entry;
    Overlay.of(context, rootOverlay: true).insert(entry);
  }

  static void hide() => _key?.currentState?.dismiss();

  static void _removeNow() {
    _entry?.remove();
    _entry = null;
    _key = null;
  }
}

class _Banner extends StatefulWidget {
  const _Banner({
    super.key,
    required this.title,
    required this.message,
    required this.imageUrl,
    required this.onTap,
    required this.duration,
    required this.onGone,
  });

  final String title;
  final String message;
  final String? imageUrl;
  final VoidCallback? onTap;
  final Duration duration;
  final VoidCallback onGone;

  @override
  State<_Banner> createState() => _BannerState();
}

class _BannerState extends State<_Banner> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  )..forward();

  late final Animation<Offset> _slide = Tween(
    begin: const Offset(0, -1.2),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  Timer? _timer;
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.duration, dismiss);
  }

  Future<void> dismiss() async {
    if (_dismissing || !mounted) return;
    _dismissing = true;
    _timer?.cancel();
    await _controller.reverse();
    widget.onGone();
  }

  void _tap() {
    widget.onGone(); // close at once, then open
    widget.onTap?.call();
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
    return Align(
      alignment: Alignment.topCenter,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppMessageBanner._maxWidth,
            ),
            child: SlideTransition(
              position: _slide,
              child: Dismissible(
                key: const ValueKey('app-message-banner'),
                direction: DismissDirection.up, // swipe up to close
                onDismissed: (_) => widget.onGone(),
                child: Material(
                  color: colors.surfaceContainerHigh,
                  elevation: 6,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: _tap,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.sm + 4),
                      child: Row(
                        children: [
                          AppAvatar(
                            name: widget.title,
                            imageUrl: widget.imageUrl,
                          ),
                          const SizedBox(width: AppSpacing.sm + 4),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AppLabel(
                                  text: widget.title,
                                  fontSize: AppFontSize.value14,
                                  fontWeight: FontWeight.w600,
                                  maxLines: 1,
                                ),
                                const SizedBox(height: 2),
                                AppLabel(
                                  text: widget.message,
                                  fontSize: AppFontSize.value14,
                                  color: colors.onSurfaceVariant,
                                  maxLines: 2,
                                ),
                              ],
                            ),
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
      ),
    );
  }
}
