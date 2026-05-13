import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/vendor.dart';
import '../../domain/repositories/vendors_repository.dart';

/// Vendor list (Slice 4.3.1).
class VendorListPage extends StatelessWidget {
  const VendorListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final repo = getIt<VendorsRepository>();
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.vendorListTitle),
        actions: [
          IconButton(
            tooltip: l10n.vendorListNewTooltip,
            icon: const Icon(Icons.add),
            onPressed: () => context.goNamed(RoutePaths.vendorNewName),
          ),
        ],
      ),
      body: FutureBuilder<List<Vendor>>(
        future: repo.getAll(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final vendors = snap.data ?? const <Vendor>[];
          if (vendors.isEmpty) {
            return Center(child: Text(l10n.vendorListEmpty));
          }
          return ListView.separated(
            itemCount: vendors.length,
            separatorBuilder: (_, __) => const Divider(height: 0),
            itemBuilder: (_, i) => _Tile(vendor: vendors[i]),
          );
        },
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.vendor});
  final Vendor vendor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor:
            vendorStatusColor(theme, vendor.status).withValues(alpha: 0.15),
        foregroundColor: vendorStatusColor(theme, vendor.status),
        child: const Icon(Icons.storefront_outlined),
      ),
      title: Text(vendor.name, style: theme.textTheme.titleSmall),
      subtitle: Text(
        '${vendor.taxId} · ${vendor.email}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelSmall,
      ),
      trailing: VendorStatusBadge(status: vendor.status),
      onTap: () => context.goNamed(
        RoutePaths.vendorDetailName,
        pathParameters: {RoutePaths.vendorDetailIdParam: vendor.id},
      ),
    );
  }
}

class VendorStatusBadge extends StatelessWidget {
  const VendorStatusBadge({super.key, required this.status});
  final VendorStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final color = vendorStatusColor(theme, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        vendorStatusLabel(l10n, status),
        style: theme.textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}

String vendorStatusLabel(AppLocalizations l10n, VendorStatus s) {
  return switch (s) {
    VendorStatus.active => l10n.vendorStatusActive,
    VendorStatus.onHold => l10n.vendorStatusOnHold,
    VendorStatus.archived => l10n.vendorStatusArchived,
  };
}

Color vendorStatusColor(ThemeData theme, VendorStatus s) {
  return switch (s) {
    VendorStatus.active => theme.colorScheme.primary,
    VendorStatus.onHold => theme.colorScheme.error,
    VendorStatus.archived => theme.colorScheme.outline,
  };
}
