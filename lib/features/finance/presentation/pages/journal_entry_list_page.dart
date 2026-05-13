import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/journal_entry.dart';
import '../../domain/repositories/journal_entries_repository.dart';

/// Journal entry list (Slice 3.3.1).
///
/// **No bloc** — read-only feed off a `Future<List<JournalEntry>>`.
/// Slice 3.3.2's trial balance shares the same pattern.
class JournalEntryListPage extends StatelessWidget {
  const JournalEntryListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final repo = getIt<JournalEntriesRepository>();
    return Scaffold(
      appBar: AppBar(title: Text(l10n.journalEntriesTitle)),
      body: FutureBuilder<List<JournalEntry>>(
        future: repo.getAll(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = snap.data ?? const <JournalEntry>[];
          if (entries.isEmpty) {
            return Center(child: Text(l10n.journalEntriesEmpty));
          }
          return ListView.separated(
            itemCount: entries.length,
            separatorBuilder: (_, __) => const Divider(height: 0),
            itemBuilder: (_, i) => _JournalRow(entry: entries[i]),
          );
        },
      ),
    );
  }
}

class _JournalRow extends StatelessWidget {
  const _JournalRow({required this.entry});
  final JournalEntry entry;
  static final _date = DateFormat('yyyy-MM-dd');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: const Icon(Icons.receipt_outlined),
      title: Text(entry.description),
      subtitle: Text(
        '${entry.reference} · ${_date.format(entry.postedAt.toLocal())}',
        style: theme.textTheme.labelSmall,
      ),
      trailing: Text(
        entry.formattedTotal,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
          fontWeight: FontWeight.w600,
        ),
      ),
      onTap: () => context.goNamed(
        RoutePaths.journalEntryDetailName,
        pathParameters: {RoutePaths.journalEntryDetailIdParam: entry.id},
      ),
    );
  }
}
