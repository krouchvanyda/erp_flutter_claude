import 'package:flutter/material.dart';

import '../../../core/theme/app_font_size.dart';
import '../../../core/theme/app_label.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../model/chat_attachment.dart';

/// A PDF inside a bubble.
///
/// ```
/// [📄]  PDF document
///       1.2 MB · Tap to open        (uploading: 62% …)
/// ```
/// The server keeps no file name (it stores "uuid.pdf"), so we can't show
/// "Report.pdf" yet.
class ChatFileContent extends StatelessWidget {
  const ChatFileContent({
    super.key,
    required this.isMine,
    this.sizeBytes,
    this.progress,
    this.onTap,
  });

  final bool isMine;
  final int? sizeBytes;
  final double? progress;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final fg = isMine ? colors.onPrimary : colors.onSurface;
    final soft = isMine
        ? colors.onPrimary.withValues(alpha: 0.75)
        : colors.onSurfaceVariant;
    final p = progress;
    final size = sizeBytes == null ? '' : AttachmentRules.sizeLabel(sizeBytes!);
    final subtitle = p != null
        ? 'Uploading ${(p * 100).round()}%'
        : [
            size,
            if (onTap != null) 'Tap to open',
          ].where((x) => x.isNotEmpty).join(' · ');

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: fg.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: p != null
                ? Padding(
                    padding: const EdgeInsets.all(10),
                    child: CircularProgressIndicator(
                      value: p == 0 ? null : p,
                      strokeWidth: 2.5,
                      color: fg,
                    ),
                  )
                : Icon(Icons.picture_as_pdf_rounded, color: fg),
          ),
          const SizedBox(width: AppSpacing.sm + 2),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                AppLabel(
                  text: 'PDF document',
                  fontSize: AppFontSize.value14,
                  fontWeight: FontWeight.w600,
                  color: fg,
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
