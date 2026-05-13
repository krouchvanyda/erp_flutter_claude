import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/vendor.dart';
import '../../domain/repositories/vendors_repository.dart';
import 'vendor_list_page.dart' show VendorStatusBadge;

/// Vendor detail (Slice 4.3.1) — header card + contact + footer link
/// to the performance scorecard (Slice 4.3.3).
class VendorDetailPage extends StatelessWidget {
  const VendorDetailPage({super.key, required this.vendorId});

  final String vendorId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final repo = getIt<VendorsRepository>();
    return Scaffold(
      appBar: AppBar(title: Text(l10n.vendorDetailTitle)),
      body: FutureBuilder<Vendor?>(
        future: repo.findById(vendorId),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final v = snap.data;
          if (v == null) {
            return Center(child: Text(l10n.vendorDetailNotFound(vendorId)));
          }
          return _Body(vendor: v);
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.vendor});
  final Vendor vendor;
  static final _date = DateFormat('yyyy-MM-dd');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(vendor.name,
                          style: theme.textTheme.titleLarge),
                    ),
                    VendorStatusBadge(status: vendor.status),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    _MetaChip(
                        label: l10n.vendorDetailTaxIdLabel,
                        value: vendor.taxId),
                    _MetaChip(
                      label: l10n.vendorDetailOnboardedLabel,
                      value: _date.format(vendor.onboardedAt.toLocal()),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.vendorDetailContactHeading,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    )),
                const SizedBox(height: 6),
                if (vendor.contactPerson != null)
                  _kv(theme, l10n.vendorDetailContactPersonLabel,
                      vendor.contactPerson!),
                _kv(theme, l10n.vendorDetailEmailLabel, vendor.email),
                _kv(theme, l10n.vendorDetailPhoneLabel, vendor.phone),
                _kv(theme, l10n.vendorDetailAddressLabel, vendor.address),
              ],
            ),
          ),
        ),
        if (vendor.notes != null) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.vendorDetailNotesHeading,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      )),
                  const SizedBox(height: 6),
                  Text(vendor.notes!),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.insights_outlined),
          label: Text(l10n.vendorDetailScorecardAction),
          onPressed: () => context.goNamed(
            RoutePaths.vendorScorecardName,
            pathParameters: {RoutePaths.vendorScorecardIdParam: vendor.id},
          ),
        ),
      ],
    );
  }

  Widget _kv(ThemeData theme, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 96,
              child: Text(label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  )),
            ),
            Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
          ],
        ),
      );
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            )),
        Text(value, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}
