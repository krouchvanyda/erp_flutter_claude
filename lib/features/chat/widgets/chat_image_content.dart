import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_font_size.dart';
import '../../../core/theme/app_label.dart';

/// A photo inside a bubble: from the server ([url], cached) or — while I'm
/// still sending it — from my phone ([localPath]) with an upload ring.
///
/// ```
/// ┌──────────────┐
/// │   [photo]    │   tap → full screen
/// │     ◔ 62%    │   ← only while uploading
/// └──────────────┘
/// ```
class ChatImageContent extends StatelessWidget {
  const ChatImageContent({
    super.key,
    this.url,
    this.localPath,
    this.progress,
    this.onTap,
  });

  final String? url;
  final String? localPath;
  final double? progress; // 0–1 while uploading
  final VoidCallback? onTap;

  /// Before the photo loads we don't know its shape → a square box.
  static const double placeholderSize = 220;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Widget placeholder([IconData? icon]) => Container(
      width: placeholderSize,
      height: placeholderSize,
      color: colors.surfaceContainerHighest,
      alignment: Alignment.center,
      child: icon == null
          ? const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, size: 36, color: colors.onSurfaceVariant),
    );

    final Widget image = localPath != null
        ? Image.file(
            File(localPath!),
            fit: BoxFit.cover,
            // Until the first frame the image has NO size (0×0 → an
            // invisible bubble) → show the square placeholder.
            frameBuilder: (_, child, frame, sync) =>
                frame == null && !sync ? placeholder() : child,
            errorBuilder: (_, _, _) => placeholder(Icons.broken_image_outlined),
          )
        : CachedNetworkImage(
            imageUrl: url ?? '',
            fit: BoxFit.cover,
            placeholder: (_, _) => placeholder(),
            errorWidget: (_, _, _) => placeholder(Icons.broken_image_outlined),
          );

    final p = progress;
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          image,
          if (p != null)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.35),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox.square(
                        dimension: 40,
                        child: CircularProgressIndicator(
                          value: p == 0 ? null : p,
                          strokeWidth: 3,
                          color: Colors.white,
                          backgroundColor: Colors.white24,
                        ),
                      ),
                      const SizedBox(height: 6),
                      AppLabel(
                        text: '${(p * 100).round()}%',
                        fontSize: AppFontSize.value12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white, // on the dark veil
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
