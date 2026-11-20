import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_status_colors.dart';
import '../model/presence_model.dart';

/// A small dot on an avatar: 🟢 online · 🟠 in a call · nothing offline.
///
/// ```dart
/// Stack(children: [AppAvatar(...), PositionedDirectional(end: 0, bottom: 0,
///   child: PresenceDot(userId: id, presence: store.presence))])
/// ```
class PresenceDot extends StatelessWidget {
  const PresenceDot({
    super.key,
    required this.userId,
    required this.presence,
    this.size = 14,
  });

  final String userId;
  final ValueListenable<Map<String, PresenceModel>> presence;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final status = context.statusColors;
    return ValueListenableBuilder<Map<String, PresenceModel>>(
      valueListenable: presence,
      builder: (context, map, _) {
        final p = map[userId];
        if (p == null || !p.isOnline) return const SizedBox.shrink();
        final busy = p.status == PresenceStatus.busy;
        return Semantics(
          label: busy ? 'In a call' : 'Online',
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: busy ? status.warning : status.success,
              shape: BoxShape.circle,
              // a ring in the page colour → the dot stands out on any photo
              border: Border.all(color: colors.surface, width: 2.5),
            ),
          ),
        );
      },
    );
  }
}
