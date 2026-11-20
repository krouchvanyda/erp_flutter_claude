import 'package:flutter/material.dart';

import '../../../core/theme/app_font_size.dart';
import '../../../core/theme/app_label.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_avatar.dart';
import '../model/call_peer.dart';

/// The middle of the call screen: who + what is happening.
///
/// ```
///        (JD)
///      Jane Doe
///   📞 Voice call        ← [kind]
///      Ringing…          ← [status] (text, or the timer)
/// ```
class CallPeerHeader extends StatelessWidget {
  const CallPeerHeader({
    super.key,
    required this.peer,
    required this.kind,
    required this.kindIcon,
    required this.status,
  });

  final CallPeer peer;
  final String kind;
  final IconData kindIcon;
  final Widget status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: colors.primary.withValues(alpha: 0.25),
              width: 6,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: AppAvatar(
              name: peer.name,
              imageUrl: peer.avatarUrl,
              size: 112,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        // the name loads a moment after an incoming call shows
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: AppLabel(
            key: ValueKey(peer.name),
            text: peer.name.isEmpty ? '…' : peer.name,
            fontSize: AppFontSize.value28,
            fontWeight: FontWeight.w700,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(kindIcon, size: 16, color: colors.onSurfaceVariant),
            const SizedBox(width: AppSpacing.xs),
            AppLabel(
              text: kind,
              fontSize: AppFontSize.value14,
              color: colors.onSurfaceVariant,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: status,
        ),
      ],
    );
  }
}
