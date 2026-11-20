import 'package:flutter/material.dart';

import '../../../core/theme/app_font_size.dart';
import '../../../core/theme/app_label.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_avatar.dart';
import '../model/call_peer.dart';

/// A group VOICE call: who is in it with me (6.3c).
///
/// ```
///  (DA)   (JD)   (SK)   (+2)
///  Dara   Jane   Sok
/// ```
/// At most [max] faces, then "+N". New people fade in.
class CallParticipantsRow extends StatelessWidget {
  const CallParticipantsRow({
    super.key,
    required this.userIds,
    required this.peer,
    this.max = 4,
  });

  final List<String> userIds;
  final CallPeer peer;
  final int max;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final shown = userIds.take(max).toList();
    final more = userIds.length - shown.length;

    Widget face(Widget avatar, String label) => SizedBox(
      width: 64,
      child: Column(
        children: [
          avatar,
          const SizedBox(height: AppSpacing.xs),
          AppLabel(
            text: label,
            fontSize: AppFontSize.value12,
            color: colors.onSurfaceVariant,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final id in shown)
            face(
              AppAvatar(
                key: ValueKey(id),
                name: peer.member(id).name,
                imageUrl: peer.member(id).avatarUrl,
                size: 48,
              ),
              peer.member(id).firstName,
            ),
          if (more > 0)
            face(
              CircleAvatar(
                radius: 24,
                backgroundColor: colors.surfaceContainerHighest,
                child: AppLabel(
                  text: '+$more',
                  fontSize: AppFontSize.value14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              '',
            ),
        ],
      ),
    );
  }
}
