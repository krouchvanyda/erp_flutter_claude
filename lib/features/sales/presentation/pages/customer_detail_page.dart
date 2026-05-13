import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/activity_event.dart';
import '../../domain/entities/contact.dart';
import '../../domain/entities/customer.dart';
import '../../domain/repositories/activities_repository.dart';
import '../../domain/repositories/contacts_repository.dart';
import '../../domain/repositories/customers_repository.dart';
import 'activity_form_page.dart' show activityTypeIcon, activityTypeLabel;
import 'customer_list_page.dart'
    show
        CustomerStatusBadge,
        customerSegmentLabel,
        customerStatusColor;

/// Customer detail (Slices 6.1.2 + 6.1.3).
///
/// Three stacked cards:
///   1. **Header** — name, status, segment, contact info, lifetime value.
///   2. **Contacts** — list of linked [`CustomerContact`]s with
///      add/edit/delete actions (Slice 6.1.2).
///   3. **Activity timeline** — append-only feed of
///      [`ActivityEvent`]s newest-first (Slice 6.1.3) with a
///      "Log activity" action that pushes the manual composer.
class CustomerDetailPage extends StatefulWidget {
  const CustomerDetailPage({super.key, required this.customerId});

  final String customerId;

  @override
  State<CustomerDetailPage> createState() => _CustomerDetailPageState();
}

class _CustomerDetailPageState extends State<CustomerDetailPage> {
  late Future<_Bundle> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_Bundle> _load() async {
    final customer = await getIt<CustomersRepository>()
        .findById(widget.customerId);
    if (customer == null) {
      return const _Bundle(
          customer: null, contacts: [], activities: []);
    }
    final contacts = await getIt<ContactsRepository>()
        .forCustomer(widget.customerId);
    final activities = await getIt<ActivitiesRepository>()
        .forCustomer(widget.customerId);
    return _Bundle(
      customer: customer,
      contacts: contacts,
      activities: activities,
    );
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _deleteContact(String contactId) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.salesContactDeleteTitle),
        content: Text(l10n.salesContactDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.invoiceActionCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.salesContactDeleteConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await getIt<ContactsRepository>().delete(contactId);
    if (!mounted) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.salesContactDeletedSnack)));
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.salesCustomerDetailTitle)),
      body: FutureBuilder<_Bundle>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final bundle = snap.data;
          if (bundle == null || bundle.customer == null) {
            return Center(
              child: Text(l10n.salesCustomerNotFound(widget.customerId)),
            );
          }
          return _Body(
            bundle: bundle,
            onAddContact: () async {
              await context.pushNamed(
                RoutePaths.salesContactNewName,
                pathParameters: {
                  RoutePaths.salesCustomerDetailIdParam: widget.customerId,
                },
              );
              if (mounted) _reload();
            },
            onEditContact: (c) async {
              await context.pushNamed(
                RoutePaths.salesContactEditName,
                pathParameters: {
                  RoutePaths.salesCustomerDetailIdParam: widget.customerId,
                  RoutePaths.salesContactIdParam: c.id,
                },
                extra: c,
              );
              if (mounted) _reload();
            },
            onDeleteContact: _deleteContact,
            onLogActivity: () async {
              await context.pushNamed(
                RoutePaths.salesActivityNewName,
                pathParameters: {
                  RoutePaths.salesCustomerDetailIdParam: widget.customerId,
                },
              );
              if (mounted) _reload();
            },
          );
        },
      ),
    );
  }
}

class _Bundle {
  const _Bundle({
    required this.customer,
    required this.contacts,
    required this.activities,
  });
  final Customer? customer;
  final List<CustomerContact> contacts;
  final List<ActivityEvent> activities;
}

class _Body extends StatelessWidget {
  const _Body({
    required this.bundle,
    required this.onAddContact,
    required this.onEditContact,
    required this.onDeleteContact,
    required this.onLogActivity,
  });

  final _Bundle bundle;
  final VoidCallback onAddContact;
  final ValueChanged<CustomerContact> onEditContact;
  final ValueChanged<String> onDeleteContact;
  final VoidCallback onLogActivity;

  static final _date = DateFormat('yyyy-MM-dd');
  static final _stamp = DateFormat('yyyy-MM-dd HH:mm');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final c = bundle.customer!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Header ───────────────────────────────────────────
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(c.name, style: theme.textTheme.titleLarge),
                    ),
                    CustomerStatusBadge(status: c.status),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${customerSegmentLabel(l10n, c.segment)}'
                  '${c.industry == null ? '' : ' · ${c.industry}'}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                _kv(theme, l10n.salesCustomerDetailEmailLabel, c.email),
                _kv(theme, l10n.salesCustomerDetailPhoneLabel, c.phone),
                _kv(theme, l10n.salesCustomerDetailAddressLabel,
                    c.billingAddress),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    _MetaChip(
                      label: l10n.salesCustomerDetailLifetimeValueLabel,
                      value: c.lifetimeValue,
                    ),
                    _MetaChip(
                      label: l10n.salesCustomerDetailSinceLabel,
                      value: _date.format(c.onboardedAt.toLocal()),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (c.notes != null) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.salesCustomerDetailNotesHeading,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(c.notes!),
                ],
              ),
            ),
          ),
        ],
        // ── Contacts ───────────────────────────────────────
        const SizedBox(height: 12),
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(l10n.salesCustomerDetailContactsHeading,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          )),
                    ),
                    TextButton.icon(
                      onPressed: onAddContact,
                      icon: const Icon(Icons.person_add_outlined),
                      label: Text(l10n.salesContactAddAction),
                    ),
                  ],
                ),
              ),
              if (bundle.contacts.isEmpty)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(l10n.salesCustomerDetailContactsEmpty,
                      style: theme.textTheme.bodySmall),
                )
              else
                for (final contact in bundle.contacts)
                  _ContactTile(
                    contact: contact,
                    onEdit: () => onEditContact(contact),
                    onDelete: () => onDeleteContact(contact.id),
                  ),
              const SizedBox(height: 8),
            ],
          ),
        ),
        // ── Activity timeline ─────────────────────────────
        const SizedBox(height: 12),
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(l10n.salesCustomerDetailTimelineHeading,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          )),
                    ),
                    TextButton.icon(
                      onPressed: onLogActivity,
                      icon: const Icon(Icons.add_comment_outlined),
                      label: Text(l10n.salesActivityLogAction),
                    ),
                  ],
                ),
              ),
              if (bundle.activities.isEmpty)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(l10n.salesCustomerDetailTimelineEmpty,
                      style: theme.textTheme.bodySmall),
                )
              else
                for (final a in bundle.activities)
                  _ActivityTile(activity: a, stamp: _stamp),
              const SizedBox(height: 8),
            ],
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
        Text(value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            )),
      ],
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.contact,
    required this.onEdit,
    required this.onDelete,
  });

  final CustomerContact contact;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: contact.isPrimary
            ? theme.colorScheme.primary.withValues(alpha: 0.15)
            : theme.colorScheme.surfaceContainerHighest,
        foregroundColor: contact.isPrimary
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant,
        child: const Icon(Icons.person_outline),
      ),
      title: Row(
        children: [
          Expanded(child: Text(contact.name, style: theme.textTheme.titleSmall)),
          if (contact.isPrimary)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color:
                    theme.colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                l10n.salesContactPrimaryBadge,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.primary),
              ),
            ),
        ],
      ),
      subtitle: Text(
        '${contact.role} · ${contact.email}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelSmall,
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (v) {
          if (v == 'edit') onEdit();
          if (v == 'delete') onDelete();
        },
        itemBuilder: (_) => [
          PopupMenuItem(value: 'edit', child: Text(l10n.salesContactEditAction)),
          PopupMenuItem(
              value: 'delete', child: Text(l10n.salesContactDeleteAction)),
        ],
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.activity, required this.stamp});
  final ActivityEvent activity;
  final DateFormat stamp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final color = _typeColor(theme, activity.type);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.12),
        foregroundColor: color,
        child: Icon(activityTypeIcon(activity.type), size: 20),
      ),
      title: Text(activity.summary),
      subtitle: Text(
        '${activityTypeLabel(l10n, activity.type)} · '
        '${stamp.format(activity.occurredAt.toLocal())} · ${activity.actor}'
        '${activity.reference == null ? '' : ' · ${activity.reference}'}',
        style: theme.textTheme.labelSmall,
      ),
      trailing: activity.amount == null
          ? null
          : Text(
              activity.amount!,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
    );
  }

  Color _typeColor(ThemeData theme, ActivityEventType t) {
    return switch (t) {
      ActivityEventType.note => theme.colorScheme.onSurfaceVariant,
      ActivityEventType.call => theme.colorScheme.primary,
      ActivityEventType.meeting => theme.colorScheme.secondary,
      ActivityEventType.email => theme.colorScheme.primary,
      ActivityEventType.quotation => theme.colorScheme.tertiary,
      ActivityEventType.order => customerStatusColor(theme, CustomerStatus.active),
      ActivityEventType.payment => theme.colorScheme.tertiary,
    };
  }
}
