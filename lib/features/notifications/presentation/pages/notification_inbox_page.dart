import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/notification.dart';
import '../bloc/notification_inbox_bloc.dart';
import '../bloc/notification_inbox_event.dart';
import '../bloc/notification_inbox_state.dart';
import '../notification_category_icon.dart';

/// Full-screen inbox view (Slice 2.3.3).
///
/// **Bloc lifecycle**: created per-mount via `getIt<NotificationInboxBloc>()`
/// (factory-registered in DI) so the watch subscription's lifetime is
/// tied to this page. Closing the page closes the bloc, which cancels
/// the drift watch — the AppBar badge keeps its own subscription so
/// the unread count stays live everywhere.
///
/// **Pull-down refresh** isn't wired — the inbox is already reactive
/// (drift watch + push routing) so there's nothing to "refresh". Add
/// it back when a manual server-pull use case lands.
class NotificationInboxPage extends StatelessWidget {
  const NotificationInboxPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<NotificationInboxBloc>(
      create: (_) => getIt<NotificationInboxBloc>()
        ..add(const NotificationInboxEvent.started()),
      child: const _InboxView(),
    );
  }
}

class _InboxView extends StatelessWidget {
  const _InboxView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.notificationInboxTitle),
        actions: [
          BlocBuilder<NotificationInboxBloc, NotificationInboxState>(
            // Only show "Mark all read" when there's anything to mark.
            buildWhen: (a, b) =>
                a is! NotificationInboxLoaded ||
                b is! NotificationInboxLoaded ||
                a.unreadCount != b.unreadCount,
            builder: (context, state) {
              final hasUnread =
                  state is NotificationInboxLoaded && state.unreadCount > 0;
              if (!hasUnread) return const SizedBox.shrink();
              return IconButton(
                tooltip: l10n.notificationInboxMarkAllRead,
                onPressed: () => context.read<NotificationInboxBloc>().add(
                      const NotificationInboxEvent.markedAllRead(),
                    ),
                icon: const Icon(Icons.done_all),
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<NotificationInboxBloc, NotificationInboxState>(
        builder: (context, state) => switch (state) {
          NotificationInboxInitial() ||
          NotificationInboxLoading() =>
            const Center(child: CircularProgressIndicator()),
          NotificationInboxFailure(:final message) =>
            _CenteredMessage(text: l10n.notificationInboxError(message)),
          NotificationInboxLoaded(:final notifications) =>
            notifications.isEmpty
                ? _CenteredMessage(text: l10n.notificationInboxEmpty)
                : _InboxList(notifications: notifications),
        },
      ),
    );
  }
}

class _InboxList extends StatelessWidget {
  const _InboxList({required this.notifications});

  final List<AppNotification> notifications;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: notifications.length,
      separatorBuilder: (_, __) => const Divider(height: 0),
      itemBuilder: (_, i) => _NotificationTile(notification: notifications[i]),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final bloc = context.read<NotificationInboxBloc>();
    return Dismissible(
      key: ValueKey(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: theme.colorScheme.errorContainer,
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsetsDirectional.only(end: 16),
        child: Icon(Icons.delete_outline,
            color: theme.colorScheme.onErrorContainer),
      ),
      onDismissed: (_) {
        bloc.add(NotificationInboxEvent.dismissed(notification.id));
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text(l10n.notificationInboxDismissedSnack),
          ));
      },
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: notification.isUnread
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          foregroundColor: notification.isUnread
              ? theme.colorScheme.onPrimaryContainer
              : theme.colorScheme.onSurfaceVariant,
          child: Icon(notificationCategoryIcon(notification.category)),
        ),
        title: Text(
          notification.title,
          style: notification.isUnread
              ? theme.textTheme.bodyLarge
                  ?.copyWith(fontWeight: FontWeight.w600)
              : theme.textTheme.bodyLarge,
        ),
        subtitle: Text(
          notification.body,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: notification.isUnread
            ? Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              )
            : null,
        onTap: () => _handleTap(context),
      ),
    );
  }

  /// Tap handler — Slice 2.3.4. Marks the row read, then attempts the
  /// deep-link bounce. Defense in depth: if the target route is
  /// permission-gated and the user lacks access, the route guard
  /// (Slice 1.3.2) bounces to `/forbidden` — we don't pre-check here.
  ///
  /// `context.goNamed` throws on an unregistered route name (e.g. a
  /// stale push payload pointing at a route that's been renamed since).
  /// We surface that as a Snackbar rather than crash the inbox.
  void _handleTap(BuildContext context) {
    final bloc = context.read<NotificationInboxBloc>();
    final l10n = AppLocalizations.of(context);
    if (notification.isUnread) {
      bloc.add(NotificationInboxEvent.markedRead(notification.id));
    }
    if (!notification.hasDeepLink) return;
    try {
      context.goNamed(
        notification.routeName!,
        pathParameters: notification.pathParameters,
      );
    } on Object catch (e) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(l10n.notificationDeepLinkError(e.toString())),
        ));
    }
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_off_outlined,
                size: 64, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
