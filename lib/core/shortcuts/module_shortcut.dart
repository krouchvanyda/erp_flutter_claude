import 'package:flutter/widgets.dart';

import '../../features/auth/entities/permission.dart';
import '../../l10n/app_localizations.dart';

/// One tile in the Modules grid (Slice 2.1.2).
///
/// Const-constructable so the [catalog] is a single, audit-friendly literal.
/// Flutter-tied (because of [icon]) — the filtering logic that decides
/// which tiles are visible lives in `permission_filter.dart`, which is
/// pure Dart and unit-testable.
@immutable
class ModuleShortcut {
  const ModuleShortcut({
    required this.id,
    required this.icon,
    required this.labelOf,
    required this.routeName,
    this.pathParameters = const {},
    this.requiredPermission,
  });

  /// Stable analytics / test key. Never localised.
  final String id;

  /// Material icon shown above the label.
  final IconData icon;

  /// Translation lookup — a callback rather than a raw string so the tile
  /// re-localises on `Locale` changes without rebuilding the catalog.
  final String Function(AppLocalizations l10n) labelOf;

  /// `go_router` route name to push when the tile is tapped.
  final String routeName;

  /// Path parameters passed to `context.goNamed(routeName, pathParameters: ...)`
  /// — used by tiles that target a parameterised route (e.g. the shared
  /// `/coming-soon/:label` page).
  final Map<String, String> pathParameters;

  /// Permission required to see + tap this tile. `null` means ungated
  /// (always visible to any signed-in user).
  ///
  /// Wildcard semantics are inherited from [Permission.grants] — the
  /// catalog can declare e.g. `finance.*` and a held `finance.invoice.read`
  /// will satisfy it.
  final Permission? requiredPermission;
}
