import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import 'route_paths.dart';

/// Catch-all destination rendered by GoRouter when no route matches.
class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key, this.location});

  final String? location;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.notFoundTitle)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text(
              l10n.notFoundBody(location ?? '?'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.goNamed(RoutePaths.splashName),
              child: Text(l10n.goHome),
            ),
          ],
        ),
      ),
    );
  }
}
