import 'package:erp_mobile/core/router/auth_redirect_policy.dart';
import 'package:erp_mobile/core/router/route_paths.dart';
import 'package:test/test.dart';

void main() {
  group('resolveAuthRedirect — signed-out user', () {
    test('reaches splash without redirect', () {
      expect(
        resolveAuthRedirect(
          matchedLocation: RoutePaths.splash,
          isAuthenticated: false,
        ),
        isNull,
      );
    });

    test('reaches login without redirect', () {
      expect(
        resolveAuthRedirect(
          matchedLocation: RoutePaths.login,
          isAuthenticated: false,
        ),
        isNull,
      );
    });

    test('is bounced from a protected route to /login', () {
      expect(
        resolveAuthRedirect(
          matchedLocation: RoutePaths.dashboard,
          isAuthenticated: false,
        ),
        RoutePaths.login,
      );
    });

    test('is bounced from an unknown protected path to /login', () {
      expect(
        resolveAuthRedirect(
          matchedLocation: '/finance/invoices/42',
          isAuthenticated: false,
        ),
        RoutePaths.login,
      );
    });
  });

  group('resolveAuthRedirect — signed-in user', () {
    test('hitting /splash is forwarded to /dashboard', () {
      expect(
        resolveAuthRedirect(
          matchedLocation: RoutePaths.splash,
          isAuthenticated: true,
        ),
        RoutePaths.dashboard,
      );
    });

    test('hitting /login is forwarded to /dashboard (no double-login)', () {
      expect(
        resolveAuthRedirect(
          matchedLocation: RoutePaths.login,
          isAuthenticated: true,
        ),
        RoutePaths.dashboard,
      );
    });

    test('reaches /dashboard without redirect', () {
      expect(
        resolveAuthRedirect(
          matchedLocation: RoutePaths.dashboard,
          isAuthenticated: true,
        ),
        isNull,
      );
    });

    test('reaches a deep protected path without redirect', () {
      expect(
        resolveAuthRedirect(
          matchedLocation: '/finance/invoices/42',
          isAuthenticated: true,
        ),
        isNull,
      );
    });
  });
}
