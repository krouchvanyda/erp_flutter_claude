import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/customer.dart';
import '../bloc/customer_list_bloc.dart';
import '../bloc/customer_list_event.dart';
import '../bloc/customer_list_state.dart';

/// Customer list (Slice 6.1.1).
class CustomerListPage extends StatelessWidget {
  const CustomerListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CustomerListBloc>(
      create: (_) =>
          getIt<CustomerListBloc>()..add(const CustomerListStarted()),
      child: const _ListView(),
    );
  }
}

class _ListView extends StatelessWidget {
  const _ListView();
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.salesCustomersTitle),
        actions: [
          IconButton(
            tooltip: l10n.salesAnalyticsTooltip,
            icon: const Icon(Icons.analytics_outlined),
            onPressed: () =>
                context.goNamed(RoutePaths.salesAnalyticsName),
          ),
        ],
      ),
      body: const Column(
        children: [_Toolbar(), Expanded(child: _Body())],
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar();
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bloc = context.read<CustomerListBloc>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: l10n.salesCustomersSearchHint,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (q) => bloc.add(CustomerListSearchChanged(q)),
          ),
          const SizedBox(height: 8),
          BlocBuilder<CustomerListBloc, CustomerListState>(
            buildWhen: (a, b) =>
                a.statusFilter != b.statusFilter ||
                a.segmentFilter != b.segmentFilter ||
                a.sort != b.sort,
            builder: (context, state) => Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final s in CustomerStatus.values) ...[
                          FilterChip(
                            label: Text(customerStatusLabel(l10n, s)),
                            selected: state.statusFilter.contains(s),
                            onSelected: (_) =>
                                bloc.add(CustomerListStatusToggled(s)),
                          ),
                          const SizedBox(width: 8),
                        ],
                        for (final s in CustomerSegment.values) ...[
                          FilterChip(
                            label: Text(customerSegmentLabel(l10n, s)),
                            selected: state.segmentFilter.contains(s),
                            onSelected: (_) =>
                                bloc.add(CustomerListSegmentToggled(s)),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _SortMenu(current: state.sort),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SortMenu extends StatelessWidget {
  const _SortMenu({required this.current});
  final CustomerSort current;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<CustomerSort>(
      tooltip: l10n.salesCustomersSortTooltip,
      icon: const Icon(Icons.sort),
      initialValue: current,
      onSelected: (s) =>
          context.read<CustomerListBloc>().add(CustomerListSortChanged(s)),
      itemBuilder: (_) => [
        for (final s in CustomerSort.values)
          PopupMenuItem(value: s, child: Text(_sortLabel(l10n, s))),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body();
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocBuilder<CustomerListBloc, CustomerListState>(
      builder: (context, state) {
        if (state.isLoading && state.source.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.errorMessage != null && state.source.isEmpty) {
          return _CenteredMessage(
              text: l10n.salesCustomersError(state.errorMessage!));
        }
        if (state.visible.isEmpty) {
          return _CenteredMessage(text: l10n.salesCustomersEmpty);
        }
        return ListView.separated(
          itemCount: state.visible.length,
          separatorBuilder: (_, __) => const Divider(height: 0),
          itemBuilder: (_, i) => _Tile(customer: state.visible[i]),
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.customer});
  final Customer customer;
  static final _date = DateFormat('yyyy-MM-dd');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final color = customerStatusColor(theme, customer.status);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        foregroundColor: color,
        child: const Icon(Icons.business_outlined),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(customer.name, style: theme.textTheme.titleSmall),
          ),
          CustomerStatusBadge(status: customer.status),
        ],
      ),
      subtitle: Text(
        '${customerSegmentLabel(l10n, customer.segment)} · '
        '${l10n.salesCustomersOnboardedLabel(_date.format(customer.onboardedAt.toLocal()))}',
        style: theme.textTheme.labelSmall,
      ),
      trailing: Text(
        customer.lifetimeValue,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      onTap: () => context.goNamed(
        RoutePaths.salesCustomerDetailName,
        pathParameters: {
          RoutePaths.salesCustomerDetailIdParam: customer.id,
        },
      ),
    );
  }
}

class CustomerStatusBadge extends StatelessWidget {
  const CustomerStatusBadge({super.key, required this.status});
  final CustomerStatus status;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final color = customerStatusColor(theme, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        customerStatusLabel(l10n, status),
        style: theme.textTheme.labelSmall?.copyWith(color: color),
      ),
    );
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
            Icon(Icons.business_outlined,
                size: 64, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

String customerStatusLabel(AppLocalizations l10n, CustomerStatus s) {
  return switch (s) {
    CustomerStatus.prospect => l10n.salesStatusProspect,
    CustomerStatus.active => l10n.salesStatusActive,
    CustomerStatus.onHold => l10n.salesStatusOnHold,
    CustomerStatus.churned => l10n.salesStatusChurned,
  };
}

Color customerStatusColor(ThemeData theme, CustomerStatus s) {
  return switch (s) {
    CustomerStatus.prospect => theme.colorScheme.secondary,
    CustomerStatus.active => theme.colorScheme.tertiary,
    CustomerStatus.onHold => theme.colorScheme.error,
    CustomerStatus.churned => theme.colorScheme.outline,
  };
}

String customerSegmentLabel(AppLocalizations l10n, CustomerSegment s) {
  return switch (s) {
    CustomerSegment.smb => l10n.salesSegmentSmb,
    CustomerSegment.midMarket => l10n.salesSegmentMidMarket,
    CustomerSegment.enterprise => l10n.salesSegmentEnterprise,
  };
}

String _sortLabel(AppLocalizations l10n, CustomerSort s) {
  return switch (s) {
    CustomerSort.nameAsc => l10n.salesCustomersSortName,
    CustomerSort.lifetimeValueDesc => l10n.salesCustomersSortLtv,
    CustomerSort.recentlyAdded => l10n.salesCustomersSortRecent,
  };
}
