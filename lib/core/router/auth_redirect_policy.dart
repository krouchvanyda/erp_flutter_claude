import 'route_paths.dart';

/// Pure auth redirection policy — no Flutter imports.
///
/// Owns the *decision* "given a target location and an auth state, should the
/// router redirect, and where to?". Kept Flutter-free so the rule set can be
/// unit-tested cheaply and audited in one place.
///
/// Intentionally a function, not a class: the policy is stateless and the
/// inputs are explicit, which makes the rules easy to reason about and to
/// extend (e.g. role-based gating in later modules).
String? resolveAuthRedirect({
  required String matchedLocation,
  required bool isAuthenticated,
}) {
  final isPublic = RoutePaths.publicLocations.contains(matchedLocation);

  if (!isAuthenticated && !isPublic) {
    return RoutePaths.login;
  }
  if (isAuthenticated &&
      (matchedLocation == RoutePaths.login ||
          matchedLocation == RoutePaths.splash)) {
    return RoutePaths.dashboard;
  }
  return null;
}
