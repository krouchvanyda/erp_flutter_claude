import 'package:erp_mobile/core/router/route_access.dart';
import 'package:erp_mobile/core/router/route_paths.dart';
import 'package:test/test.dart';

void main() {
  group('RouteAccess.requiredFor', () {
    test('returns null for an ungated location', () {
      expect(RouteAccess.requiredFor(RoutePaths.chat), isNull);
    });

    test('returns null for an unknown / future location', () {
      expect(RouteAccess.requiredFor('/finance/invoices/42'), isNull);
    });

    test(
        'requirements map only contains real RoutePaths constants — '
        'guards against typos that would silently disable a gate', () {
      const knownPaths = <String>{
        RoutePaths.splash,
        RoutePaths.login,
        RoutePaths.otp,
        RoutePaths.chat,
        RoutePaths.settings,
        RoutePaths.forbidden,
      };
      for (final location in RouteAccess.requirements.keys) {
        expect(
          knownPaths,
          contains(location),
          reason: 'RouteAccess gates "$location", which is not a known '
              'RoutePaths constant — typo or stale entry?',
        );
      }
    });
  });
}
