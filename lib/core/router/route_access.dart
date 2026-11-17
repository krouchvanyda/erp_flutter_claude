import '../../features/auth/models/permission.dart';

/// Static permission requirements for permission-gated routes.
///
/// One central table keeps the authorisation surface auditable: every
/// gated location is listed here, and the route guard in
/// `auth_redirect_policy.dart` reads from this single source. Locations
/// not present in the table are treated as "any authenticated user".
///
/// Wildcard semantics (trailing `*`, mid `*`, bare `*`) are inherited
/// from [Permission.grants] — whoever populates this map writes the
/// strictest token; held permissions decide whether it's satisfied.
abstract final class RouteAccess {
  /// Location → Permission required to enter.
  ///
  /// Empty for now — the permission-gated demo route was removed along
  /// with the dashboard. Feature modules append their own requirements
  /// (keyed by a [RoutePaths] constant) as they ship.
  static const Map<String, Permission> requirements = {};

  /// Returns the permission required for [location], or `null` when the
  /// location has no permission gate (any authenticated user can enter).
  static Permission? requiredFor(String location) => requirements[location];
}
