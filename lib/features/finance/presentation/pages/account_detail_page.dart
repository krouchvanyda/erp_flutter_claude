import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/injection.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/account.dart';
import '../../domain/entities/transaction.dart';
import '../account_type_visual.dart';
import '../bloc/account_detail_bloc.dart';
import '../bloc/account_detail_event.dart';
import '../bloc/account_detail_state.dart';

/// Account detail + ledger transactions (Slice 3.1.2).
///
/// **Bloc lifecycle**: created per-mount via the DI factory and seeded
/// with the route's `:id` path param. Navigating to a different account
/// re-uses the bloc and fires a fresh `Started` (the bloc swaps watch
/// subscriptions internally).
class AccountDetailPage extends StatelessWidget {
  const AccountDetailPage({super.key, required this.accountId});

  final String accountId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AccountDetailBloc>(
      create: (_) => getIt<AccountDetailBloc>()
        ..add(AccountDetailEvent.started(accountId)),
      child: _DetailView(accountId: accountId),
    );
  }
}

class _DetailView extends StatelessWidget {
  const _DetailView({required this.accountId});

  final String accountId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: BlocBuilder<AccountDetailBloc, AccountDetailState>(
          buildWhen: (a, b) =>
              (a is AccountDetailLoaded ? a.account.id : null) !=
              (b is AccountDetailLoaded ? b.account.id : null),
          builder: (context, state) => Text(
            state is AccountDetailLoaded
                ? '${state.account.code}  ${state.account.name}'
                : l10n.accountDetailTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      body: BlocBuilder<AccountDetailBloc, AccountDetailState>(
        builder: (context, state) => switch (state) {
          AccountDetailInitial() ||
          AccountDetailLoading() =>
            const Center(child: CircularProgressIndicator()),
          AccountDetailFailure(:final message) =>
            _CenteredMessage(text: l10n.accountDetailError(message)),
          AccountDetailNotFound(:final accountId) =>
            _CenteredMessage(
              icon: Icons.search_off,
              text: l10n.accountDetailNotFound(accountId),
            ),
          AccountDetailLoaded(:final account, :final transactions) =>
            _LoadedBody(account: account, transactions: transactions),
        },
      ),
    );
  }
}

class _LoadedBody extends StatelessWidget {
  const _LoadedBody({required this.account, required this.transactions});

  final Account account;
  final List<LedgerTransaction> transactions;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _AccountHeader(account: account)),
        if (transactions.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _CenteredMessage(
              text: AppLocalizations.of(context).accountDetailNoTransactions,
            ),
          )
        else
          SliverList.separated(
            itemCount: transactions.length,
            separatorBuilder: (_, __) => const Divider(height: 0),
            itemBuilder: (_, i) =>
                _TransactionRow(transaction: transactions[i]),
          ),
      ],
    );
  }
}

class _AccountHeader extends StatelessWidget {
  const _AccountHeader({required this.account});

  final Account account;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: theme.colorScheme.primaryContainer,
                foregroundColor: theme.colorScheme.onPrimaryContainer,
                child: Icon(accountTypeIcon(account.type), size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.code,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      account.name,
                      style: theme.textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text(
                            accountTypeLabel(l10n, account.type),
                            style: theme.textTheme.labelSmall,
                          ),
                        ),
                        if (account.formattedBalance != null)
                          Text(
                            account.formattedBalance!,
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: theme.colorScheme.primary,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({required this.transaction});

  final LedgerTransaction transaction;

  // Date formatter — short ISO-ish for unambiguous display across
  // locales without depending on the device's date format choice.
  static final _date = DateFormat('yyyy-MM-dd');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = transaction;
    final isDebit = t.debit != null;
    final amountText = t.debit ?? t.credit ?? '—';
    final amountColor = isDebit
        ? theme.colorScheme.primary
        : theme.colorScheme.tertiary;
    return ListTile(
      contentPadding:
          const EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 4),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      _date.format(t.postedAt.toLocal()),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (t.reference != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '· ${t.reference!}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amountText,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: amountColor,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                t.runningBalance,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({required this.text, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon ?? Icons.receipt_long_outlined,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
