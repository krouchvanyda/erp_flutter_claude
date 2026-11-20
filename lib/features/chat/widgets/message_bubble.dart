import 'package:flutter/material.dart';

import '../../../core/theme/app_font_size.dart';
import '../../../core/theme/app_label.dart';
import '../../../core/theme/app_spacing.dart';

/// The small sign after the time in MY bubbles.
enum BubbleStatus {
  none, //    others' messages
  sending, // 🕓 not confirmed yet
  sent, //    ✓  the server has it
  read, //    ✓✓ someone has read it
  failed, //  ⚠  not sent → tap to retry
}

/// One chat bubble.
///
/// ```
///  theirs (left, grey)               mine (right, primary)
///  Dara                         ┌─────────────────────┐
///  ┌──────────────────┐         │ Yes, 9am 👍          │
///  │ Are we still on? │         └──────────── 08:10 ✓✓┘
///  └────────────18:02─┘
/// ```
/// - [firstInRun] / [lastInRun]: bubbles from the same person close together
///   form a "run". Only the last one gets the sharp "tail" corner.
/// - [leading]: the sender's avatar slot in groups (null = no slot).
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.text,
    required this.time,
    required this.isMine,
    required this.maxWidth,
    this.status = BubbleStatus.none,
    this.isPlaceholder = false,
    this.edited = false,
    this.senderName,
    this.leading,
    this.firstInRun = true,
    this.lastInRun = true,
    this.onRetry,
    this.media,
    this.body,
  });

  final String text;
  final String time; // "08:10"
  final bool isMine;
  final double maxWidth;
  final BubbleStatus status;

  /// Deleted / not-yet-supported types ("📷 Photo" until Step 5.5): softer text.
  final bool isPlaceholder;
  final bool edited;

  /// Shown above the first bubble of a run in groups ("Dara").
  final String? senderName;
  final Widget? leading;
  final bool firstInRun;
  final bool lastInRun;
  final VoidCallback? onRetry;

  /// A photo (Step 5.5): fills the bubble, the time sits ON the photo.
  final Widget? media;

  /// A file / voice row (Step 5.5) instead of [text].
  final Widget? body;

  static const double _radius = 18;

  /// Photo bubbles: at most this big (the photo keeps its shape inside).
  static const double mediaMaxWidth = 260;
  static const double mediaMaxHeight = 320;
  static const double _tail = 4;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final failed = status == BubbleStatus.failed;
    final background = isMine ? colors.primary : colors.surfaceContainerHighest;
    final foreground = isMine ? colors.onPrimary : colors.onSurface;
    final soft = isMine
        ? colors.onPrimary.withValues(alpha: 0.75)
        : colors.onSurfaceVariant;

    // Runs look joined: the corners between two bubbles of the same run
    // are small; only the very last bubble has the "tail" corner.
    const big = Radius.circular(_radius);
    const small = Radius.circular(_tail);
    final shape = BorderRadius.only(
      topLeft: !isMine && !firstInRun ? small : big,
      bottomLeft: !isMine ? small : big,
      topRight: isMine && !firstInRun ? small : big,
      bottomRight: isMine ? small : big,
    );
    final corners = lastInRun
        ? shape
        : shape.copyWith(
            bottomLeft: isMine ? big : small,
            bottomRight: isMine ? small : big,
          );

    Widget timeRow(Color color) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (edited) ...[
          AppLabel(text: 'edited', fontSize: AppFontSize.value11, color: color),
          const SizedBox(width: AppSpacing.xs),
        ],
        AppLabel(text: time, fontSize: AppFontSize.value11, color: color),
        if (isMine && status != BubbleStatus.none) ...[
          const SizedBox(width: 3),
          Icon(_statusIcon, size: 14, color: color),
        ],
      ],
    );

    final Widget bubble;
    if (media != null) {
      // Photo: no padding, rounded like the bubble, time in a dark pill.
      bubble = Opacity(
        opacity: failed ? 0.55 : 1,
        child: ClipRRect(
          borderRadius: corners,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth < mediaMaxWidth ? maxWidth : mediaMaxWidth,
              maxHeight: mediaMaxHeight,
            ),
            child: Stack(
              children: [
                media!,
                PositionedDirectional(
                  end: 6,
                  bottom: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(_radius),
                    ),
                    // white on a dark pill: readable on any photo
                    child: timeRow(Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      bubble = Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm + 4,
          AppSpacing.sm,
          AppSpacing.sm + 4,
          AppSpacing.xs + 2,
        ),
        decoration: BoxDecoration(
          color: failed ? background.withValues(alpha: 0.55) : background,
          borderRadius: corners,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              widthFactor: 1,
              child:
                  body ??
                  AppLabel(
                    text: text,
                    fontSize: AppFontSize.value16,
                    lineHeight: 1.35,
                    color: isPlaceholder ? soft : foreground,
                    fontWeight: isPlaceholder
                        ? FontWeight.w500
                        : FontWeight.normal,
                  ),
            ),
            const SizedBox(height: 2),
            timeRow(soft),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: isMine
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        if (senderName != null)
          Padding(
            padding: EdgeInsetsDirectional.only(
              start: (leading == null ? 0 : 36) + AppSpacing.sm + 4,
              bottom: 2,
            ),
            child: AppLabel(
              text: senderName!,
              fontSize: AppFontSize.value12,
              fontWeight: FontWeight.w600,
              color: colors.primary,
            ),
          ),
        Row(
          mainAxisAlignment: isMine
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (leading != null) ...[
              SizedBox(width: 28, child: leading),
              const SizedBox(width: AppSpacing.sm),
            ],
            Flexible(
              child: failed
                  ? Semantics(
                      button: true,
                      label: 'Not sent. Tap to retry',
                      child: GestureDetector(onTap: onRetry, child: bubble),
                    )
                  : bubble,
            ),
          ],
        ),
        if (failed)
          InkWell(
            onTap: onRetry,
            borderRadius: BorderRadius.circular(_tail),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.xs,
                horizontal: 2,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 14,
                    color: colors.error,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  AppLabel(
                    text: 'Not sent · Tap to retry',
                    fontSize: AppFontSize.value12,
                    fontWeight: FontWeight.w600,
                    color: colors.error,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  IconData get _statusIcon => switch (status) {
    BubbleStatus.sending => Icons.schedule_rounded,
    BubbleStatus.sent => Icons.check_rounded,
    BubbleStatus.read => Icons.done_all_rounded,
    BubbleStatus.failed => Icons.error_outline_rounded,
    BubbleStatus.none => Icons.check_rounded, // never drawn
  };
}
