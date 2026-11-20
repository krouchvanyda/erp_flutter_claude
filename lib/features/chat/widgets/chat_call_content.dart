import 'package:flutter/material.dart';

import '../../../core/theme/app_font_size.dart';
import '../../../core/theme/app_label.dart';
import '../../../core/theme/app_spacing.dart';
import '../model/chat_call_info.dart';

/// A call line inside a bubble (6.3d):
///
/// ```
/// ┌───────────────────────────────┐
/// │ (📞↗) Outgoing voice call      │
/// │       2:31 · Tap to call back │
/// └──────────────────────── 10:42 ┘
/// ```
/// Missed (for me) → a red icon and title. Tap → call back (same type).
class ChatCallContent extends StatelessWidget {
  const ChatCallContent({
    super.key,
    required this.info,
    required this.isMine,
    this.onCallBack,
  });

  final ChatCallInfo info;
  final bool isMine;

  /// null → no "Tap to call back" (e.g. already in a call).
  final VoidCallback? onCallBack;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final missed = info.missedFor(mine: isMine);
    final fg = isMine ? colors.onPrimary : colors.onSurface;
    final soft = isMine
        ? colors.onPrimary.withValues(alpha: 0.75)
        : colors.onSurfaceVariant;
    final iconColor = missed ? colors.error : fg;
    final icon = switch ((info.video, missed)) {
      (true, true) => Icons.missed_video_call_rounded,
      (true, false) => Icons.videocam_rounded,
      (false, true) => Icons.call_missed_rounded,
      (false, false) when isMine => Icons.call_made_rounded,
      (false, false) => Icons.call_received_rounded,
    };
    final subtitle = [
      ?info.detail(mine: isMine),
      if (onCallBack != null) 'Tap to call back',
    ].join(' · ');

    return GestureDetector(
      onTap: onCallBack,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: AppSpacing.sm + 2),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                AppLabel(
                  text: info.title(mine: isMine),
                  fontSize: AppFontSize.value14,
                  fontWeight: FontWeight.w600,
                  color: missed ? colors.error : fg,
                ),
                if (subtitle.isNotEmpty)
                  AppLabel(
                    text: subtitle,
                    fontSize: AppFontSize.value12,
                    color: soft,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
