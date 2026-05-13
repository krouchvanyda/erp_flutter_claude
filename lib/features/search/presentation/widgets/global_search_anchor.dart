import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/permissions_snapshot.dart';
import '../../../../core/shortcuts/module_shortcut_catalog.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/providers/module_shortcut_search_provider.dart';
import '../../domain/entities/search_result.dart';
import '../../domain/usecases/federated_search.dart';
import '../bloc/global_search_bloc.dart';
import '../bloc/global_search_event.dart';
import '../bloc/global_search_state.dart';

/// AppBar-mounted entry point for the global search bar (Slice 2.1.3).
///
/// Renders a Material 3 [SearchAnchor]: a single icon button that opens
/// a full-screen search view overlay. The bloc + use case + provider
/// list are created per-mount in [BlocProvider.create] so each AppBar
/// gets its own scoped instance — no cross-contamination if the user
/// switches branches mid-search.
///
/// **Why per-mount and not @lazySingleton**: the seed
/// [ModuleShortcutSearchProvider] needs current [AppLocalizations] for
/// label matching, which is widget-scoped. Future feature providers
/// will be DI-singletons; the use case will accept them via the
/// registry pattern when more than one provider exists.
class GlobalSearchAnchor extends StatelessWidget {
  const GlobalSearchAnchor({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final permissions = getIt<PermissionsSnapshot>();

    return BlocProvider<GlobalSearchBloc>(
      create: (_) => GlobalSearchBloc(
        federatedSearch: FederatedSearchUseCase(
          providers: [
            ModuleShortcutSearchProvider(
              labelOf: (s) => s.labelOf(l10n),
              shortcutHeld: permissions.holds,
            ),
          ],
          holds: permissions.holds,
        ),
      ),
      child: const _GlobalSearchAnchorView(),
    );
  }
}

class _GlobalSearchAnchorView extends StatelessWidget {
  const _GlobalSearchAnchorView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bloc = context.read<GlobalSearchBloc>();

    return SearchAnchor(
      isFullScreen: false,
      builder: (context, controller) => IconButton(
        tooltip: l10n.globalSearchTooltip,
        icon: const Icon(Icons.search),
        onPressed: controller.openView,
      ),
      viewHintText: l10n.globalSearchHint,
      viewOnChanged: (q) =>
          bloc.add(GlobalSearchEvent.queryChanged(q)),
      viewOnSubmitted: (q) =>
          bloc.add(GlobalSearchEvent.queryChanged(q)),
      suggestionsBuilder: (context, controller) {
        // `SearchAnchor` opens its view in a separate Navigator overlay,
        // so the `BlocProvider` above this widget isn't an ancestor of
        // the suggestions subtree. Re-expose the existing bloc via
        // `BlocProvider.value` so the BlocBuilder below resolves it.
        return [
          BlocProvider<GlobalSearchBloc>.value(
            value: bloc,
            child: BlocBuilder<GlobalSearchBloc, GlobalSearchState>(
              builder: (context, state) => _SuggestionsBody(
                state: state,
                onTapResult: (result) {
                  controller.closeView(result.title);
                  bloc.add(const GlobalSearchEvent.cleared());
                  context.goNamed(
                    result.routeName,
                    pathParameters: result.pathParameters,
                  );
                },
              ),
            ),
          ),
        ];
      },
    );
  }
}

class _SuggestionsBody extends StatelessWidget {
  const _SuggestionsBody({required this.state, required this.onTapResult});

  final GlobalSearchState state;
  final ValueChanged<SearchResult> onTapResult;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return switch (state) {
      GlobalSearchIdle() => _Centered(child: Text(l10n.globalSearchPrompt)),
      GlobalSearchLoading() =>
        const _Centered(child: CircularProgressIndicator()),
      GlobalSearchFailure(:final message) =>
        _Centered(child: Text(l10n.globalSearchError(message))),
      GlobalSearchSuccess(:final query, :final groups) => groups.isEmpty
          ? _Centered(child: Text(l10n.globalSearchNoResults(query)))
          : _GroupedResultsList(groups: groups, onTap: onTapResult),
    };
  }
}

class _GroupedResultsList extends StatelessWidget {
  const _GroupedResultsList({required this.groups, required this.onTap});

  final List<SearchResultGroup> groups;
  final ValueChanged<SearchResult> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      shrinkWrap: true,
      children: [
        for (final g in groups) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              _providerHeader(context, g.providerId),
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: theme.colorScheme.primary),
            ),
          ),
          for (final r in g.results)
            ListTile(
              leading: Icon(_iconFor(r)),
              title: Text(r.title),
              subtitle: r.subtitle == null ? null : Text(r.subtitle!),
              onTap: () => onTap(r),
            ),
        ],
      ],
    );
  }

  String _providerHeader(BuildContext context, String providerId) {
    final l10n = AppLocalizations.of(context);
    return switch (providerId) {
      'modules' => l10n.shellModules,
      _ => providerId,
    };
  }

  /// Maps a result back to the catalog's icon (cheap O(n) lookup over
  /// the small static catalog). Real feature providers will pass an
  /// icon hint on the result itself.
  IconData _iconFor(SearchResult r) {
    if (r.providerId != 'modules') return Icons.description_outlined;
    for (final s in ModuleShortcutCatalog.all) {
      if (s.id == r.id) return s.icon;
    }
    return Icons.search;
  }
}

class _Centered extends StatelessWidget {
  const _Centered({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(child: child),
    );
  }
}
