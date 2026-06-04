import 'package:flutter/material.dart';

import 'package:erp_mobile/core/di/app_dependencies.dart';
import 'package:erp_mobile/core/router/config_router.dart';
import 'package:erp_mobile/l10n/app_localizations.dart';
import 'package:erp_mobile/data/repositories/notifications_repository.dart';
import 'package:erp_mobile/features/notifications/views/notification_inbox_screen.dart';

/// AppBar-mounted bell with a Material 3 [Badge] showing the unread
/// count (Slice 2.3.3).
///
/// Subscribes to [NotificationsRepository.watchUnreadCount] directly
/// — no bloc — because the only thing that ever changes here is one
/// integer. Pulling in the inbox bloc would force every screen that
/// shows the badge to host the full state machine and its watch
/// subscription. The dao's `COUNT(*)` query keeps this cheap.
///
/// **Hides the badge at 0** so a "0" decoration doesn't yell at the
/// user. Counts over 99 display as `99+` to keep the bubble small.
class NotificationsBadge extends StatelessWidget {
  const NotificationsBadge({
    super.key,
    NotificationsRepository? repository,
  }) : _repositoryOverride = repository;

  /// Test seam — production code resolves via `AppDependencies.I`.
  final NotificationsRepository? _repositoryOverride;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final repo = _repositoryOverride ?? AppDependencies.I.notificationsRepository;
    return StreamBuilder<int>(
      stream: repo.watchUnreadCount(),
      initialData: 0,
      builder: (context, snap) {
        final count = snap.data ?? 0;
        return IconButton(
          tooltip: l10n.notificationsBadgeTooltip,
          onPressed: () =>
              ConfigRouter.pushPageAnimation(context, const NotificationInboxScreen()),
          icon: Badge(
            isLabelVisible: count > 0,
            label: Text(count > 99 ? '99+' : '$count'),
            child: const Icon(Icons.notifications_outlined),
          ),
        );
      },
    );
  }
}
