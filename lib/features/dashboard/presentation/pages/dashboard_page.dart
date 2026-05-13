import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/dashboard/dashboard_grid.dart';
import '../../../../core/dashboard/dashboard_widget.dart';
import '../../../../core/dashboard/widgets/chart_dashboard_widgets.dart';
import '../../../../core/dashboard/widgets/kpi_dashboard_widget.dart';
import '../../../../core/di/app_env.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/push/local_push_simulator.dart';
import '../../../../core/push/push_message_router.dart';
import '../../../../core/push/push_notification_service.dart';
import '../../../../core/realtime/realtime_service.dart';
import '../../../../core/realtime/realtime_status_indicator.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../features/auth/domain/entities/permission.dart';
import '../../../../features/notifications/presentation/widgets/notifications_badge.dart';
import '../../../../features/search/presentation/widgets/global_search_anchor.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/charts/chart_data.dart';
import '../../../../shared/widgets/kpi/kpi_data.dart';
import '../../../../shared/widgets/permission_guard.dart';

/// Dashboard placeholder, fleshed out incrementally:
///
/// - Slice 1.3.2 — `[demo] Open admin-only page` (route guard).
/// - Slice 1.3.3 — live `PermissionGuard` verdict chip.
/// - Slice 2.1.3 — `GlobalSearchAnchor` in the AppBar.
/// - Slice 2.2.1 — KPI cards rendered via [KpiCard].
/// - Slice 2.2.2 — KPI + chart slots composed into a [DashboardLayout]
///   and rendered through [DashboardGrid].
/// - Slice 2.2.3 — `LineChartCard` + `BarChartCard` (fl_chart) added
///   to the default layout.
/// - Slice 2.2.4 — kicks off the [RealtimeService] connection on
///   mount (this slice). The status pill in the AppBar reflects the
///   live connection state. Stateful so we can hook `initState` /
///   `dispose` without leaking the lifecycle into the parent.
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, this.onSignOut});

  final VoidCallback? onSignOut;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  static const _adminPermission = Permission(token: 'admin');

  late final RealtimeService _realtime;
  late final PushMessageRouter _pushRouter;
  late final PushNotificationService _pushService;
  int _demoPushCount = 0;

  @override
  void initState() {
    super.initState();
    _realtime = getIt<RealtimeService>();
    _pushRouter = getIt<PushMessageRouter>();
    _pushService = getIt<PushNotificationService>();
    // Realtime is opt-in via AppEnv.realtimeEnabled — kept off by
    // default until a real WebSocket backend is wired so the placeholder
    // URL doesn't burn DNS lookups + battery on every reconnect tick.
    // The status pill stays at "Offline" while disabled.
    if (getIt<AppEnv>().realtimeEnabled) {
      // Fire-and-forget — `connect()` returns once the first attempt
      // is initiated; the service handles failure / reconnect internally
      // and surfaces state via the indicator's StreamBuilder.
      unawaited(_realtime.connect());
      // Subscribe to the demo dashboard topic so a future server build
      // knows to push KPI / chart updates for these slot ids. Replayed
      // automatically on every reconnect by the service.
      _realtime.subscribe('dashboard.default');
    }
    // Boot the push pipeline — initialises the (simulator) provider,
    // claims the device token, and starts the message → inbox routing.
    unawaited(_pushRouter.start());
  }

  /// Demo-only — lets the user fire a fake push payload through the
  /// router so the inbox bloc / dao machinery can be exercised end-to-end
  /// before a real FCM backend exists. Disappears when
  /// `LocalPushSimulator` is replaced by the real binding.
  ///
  /// When [routeName] is supplied, the resulting Snackbar carries a
  /// "View" action that drops straight onto the deep-link target —
  /// modelling the "user receives a push while the app is open"
  /// foreground UX without needing to open the inbox to act on it.
  void _simulatePush({String? routeName, Map<String, String> routeParams = const {}}) {
    final svc = _pushService;
    if (svc is! LocalPushSimulator) return;
    _demoPushCount++;
    final l10n = AppLocalizations.of(context);
    svc.simulateNow(
      title: l10n.pushDemoTitle(_demoPushCount),
      body: routeName == null ? l10n.pushDemoBody : l10n.pushDemoRoutedBody,
      category: 'system',
      data: {
        if (routeName != null) 'route': routeName,
        for (final e in routeParams.entries) 'route.${e.key}': e.value,
      },
    );
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(l10n.pushDemoSnack),
        action: routeName == null
            ? null
            : SnackBarAction(
                label: l10n.notificationDeepLinkViewAction,
                onPressed: () => context.goNamed(
                  routeName,
                  pathParameters: routeParams,
                ),
              ),
      ));
  }

  /// Builds the default layout. Not `const` because the chart widgets
  /// pull localised titles from [AppLocalizations] which is per-context.
  static DashboardLayout _buildDefaultLayout(AppLocalizations l10n) => [
        const KpiDashboardWidget(
          id: 'revenue-mtd',
          data: KpiData(
            label: 'Revenue (MTD)',
            value: r'$84,210',
            trend: KpiTrend.up,
            trendDelta: '+12.4 %',
            sparkline: [62, 58, 65, 71, 70, 78, 84],
          ),
        ),
        const KpiDashboardWidget(
          id: 'open-invoices',
          data: KpiData(
            label: 'Open invoices',
            value: '47',
            trend: KpiTrend.down,
            trendDelta: '-6 vs prior',
            sparkline: [70, 66, 62, 58, 53, 50, 47],
          ),
        ),
        const KpiDashboardWidget(
          id: 'avg-fulfilment',
          data: KpiData(
            label: 'Avg fulfilment (d)',
            value: '3.2',
            trend: KpiTrend.flat,
            trendDelta: '~0',
            sparkline: [3.1, 3.3, 3.2, 3.2, 3.1, 3.2, 3.2],
          ),
          // Spans 2 cells — exercises the variable-span path on medium /
          // expanded layouts (becomes full-width on compact via clamp).
          colSpan: 2,
        ),
        LineChartDashboardWidget(
          id: 'revenue-trend',
          title: l10n.chartRevenueTrendTitle,
          colSpan: 2,
          series: [
            ChartSeries(
              id: 'revenue',
              label: l10n.chartSeriesRevenue,
              points: const [
                ChartPoint(x: 1, y: 62, label: 'W1'),
                ChartPoint(x: 2, y: 58, label: 'W2'),
                ChartPoint(x: 3, y: 65, label: 'W3'),
                ChartPoint(x: 4, y: 71, label: 'W4'),
                ChartPoint(x: 5, y: 70, label: 'W5'),
                ChartPoint(x: 6, y: 78, label: 'W6'),
                ChartPoint(x: 7, y: 84, label: 'W7'),
              ],
            ),
            ChartSeries(
              id: 'target',
              label: l10n.chartSeriesTarget,
              points: const [
                ChartPoint(x: 1, y: 60),
                ChartPoint(x: 2, y: 62),
                ChartPoint(x: 3, y: 64),
                ChartPoint(x: 4, y: 66),
                ChartPoint(x: 5, y: 68),
                ChartPoint(x: 6, y: 70),
                ChartPoint(x: 7, y: 72),
              ],
            ),
          ],
        ),
        BarChartDashboardWidget(
          id: 'sales-by-region',
          title: l10n.chartSalesByRegionTitle,
          colSpan: 2,
          series: ChartSeries(
            id: 'sales-region',
            label: l10n.chartSeriesSales,
            points: const [
              ChartPoint(x: 0, y: 24, label: 'NA'),
              ChartPoint(x: 1, y: 18, label: 'EU'),
              ChartPoint(x: 2, y: 31, label: 'APAC'),
              ChartPoint(x: 3, y: 11, label: 'LATAM'),
            ],
          ),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.dashboardTitle),
        actions: [
          const RealtimeStatusIndicator(),
          const NotificationsBadge(),
          const GlobalSearchAnchor(),
          if (widget.onSignOut != null)
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: widget.onSignOut,
              tooltip: l10n.signOutTooltip,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DashboardGrid(layout: _buildDefaultLayout(l10n)),
            const SizedBox(height: 24),
            Text(l10n.dashboardPlaceholder),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => context.goNamed(RoutePaths.adminDemoName),
              child: Text(l10n.dashboardAdminDemoLink),
            ),
            // Slice 3.1.1 — bypass link to the chart of accounts. The
            // Modules grid's Finance tile is gated by `finance.*`, so
            // without RBAC seeded the user can't reach it that way.
            // This dev shortcut sidesteps the gate so the feature is
            // visible end-to-end on first run.
            TextButton(
              onPressed: () =>
                  context.goNamed(RoutePaths.chartOfAccountsName),
              child: Text(l10n.dashboardChartOfAccountsLink),
            ),
            const SizedBox(height: 8),
            // Slice 2.3.2 — manual push trigger so the inbox routing
            // pipeline can be exercised end-to-end before a real FCM
            // backend exists. Disappears with the simulator binding.
            if (_pushService is LocalPushSimulator) ...[
              TextButton.icon(
                onPressed: () => _simulatePush(),
                icon: const Icon(Icons.notifications_active_outlined),
                label: Text(l10n.pushDemoButton),
              ),
              // Slice 2.3.4 — second button fires a payload carrying a
              // `route` data field so tapping the resulting notification
              // (or the Snackbar's "View") deep-links to /admin-demo.
              // With no permissions cached the route guard from 1.3.2
              // bounces to /forbidden — both deep-link AND RBAC defense
              // demoed in one tap.
              TextButton.icon(
                onPressed: () =>
                    _simulatePush(routeName: RoutePaths.adminDemoName),
                icon: const Icon(Icons.open_in_new),
                label: Text(l10n.pushDemoRoutedButton),
              ),
            ],
            const SizedBox(height: 8),
            PermissionGuard.builder(
              required: _adminPermission,
              builder: (context, allowed) {
                final color = allowed
                    ? theme.colorScheme.primary
                    : theme.colorScheme.error;
                return Chip(
                  avatar: Icon(
                    allowed ? Icons.check_circle : Icons.lock_outline,
                    color: color,
                    size: 18,
                  ),
                  label: Text(
                    allowed
                        ? l10n.permissionGuardDemoGranted
                        : l10n.permissionGuardDemoDenied,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
