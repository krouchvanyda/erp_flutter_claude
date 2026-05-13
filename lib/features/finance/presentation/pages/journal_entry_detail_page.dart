import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/injection.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/journal_entry.dart';
import '../../domain/repositories/journal_entries_repository.dart';

/// Journal entry detail (Slice 3.3.1) — header + line table.
///
/// Shows the debit / credit columns side-by-side with totals at the
/// bottom, matching how accountants read entries on paper.
class JournalEntryDetailPage extends StatelessWidget {
  const JournalEntryDetailPage({super.key, required this.entryId});

  final String entryId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final repo = getIt<JournalEntriesRepository>();
    return Scaffold(
      appBar: AppBar(title: Text(l10n.journalEntryDetailTitle)),
      body: FutureBuilder<JournalEntry?>(
        future: repo.findById(entryId),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final entry = snap.data;
          if (entry == null) {
            return Center(child: Text(l10n.journalEntryNotFound(entryId)));
          }
          return _Body(entry: entry);
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.entry});
  final JournalEntry entry;
  static final _date = DateFormat('yyyy-MM-dd HH:mm');

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
                Text(entry.reference, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(entry.description),
                const SizedBox(height: 8),
                Text(
                  _date.format(entry.postedAt.toLocal()),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(l10n.journalEntryAccountColumn,
                          style: theme.textTheme.labelMedium),
                    ),
                    Expanded(
                      child: Text(
                        l10n.journalEntryDebitColumn,
                        textAlign: TextAlign.end,
                        style: theme.textTheme.labelMedium,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        l10n.journalEntryCreditColumn,
                        textAlign: TextAlign.end,
                        style: theme.textTheme.labelMedium,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 0),
              for (final line in entry.lines)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          '${line.accountCode}  ${line.accountName}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontFeatures: const [
                              FontFeature.tabularFigures()
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          line.debit ?? '—',
                          textAlign: TextAlign.end,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: line.debit == null
                                ? theme.colorScheme.outline
                                : theme.colorScheme.primary,
                            fontFeatures: const [
                              FontFeature.tabularFigures()
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          line.credit ?? '—',
                          textAlign: TextAlign.end,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: line.credit == null
                                ? theme.colorScheme.outline
                                : theme.colorScheme.tertiary,
                            fontFeatures: const [
                              FontFeature.tabularFigures()
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const Divider(height: 0),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(l10n.journalEntryTotalLabel,
                          style: theme.textTheme.titleSmall),
                    ),
                    Text(
                      entry.formattedTotal,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
