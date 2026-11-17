import 'package:erp_mobile/core/config/environments.dart';
import 'package:erp_mobile/core/config/flavor.dart';
import 'package:erp_mobile/core/di/app_env.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fromName maps the --flavor names', () {
    expect(Flavor.fromName('dev'), Flavor.dev);
    expect(Flavor.fromName('uat'), Flavor.uat);
    expect(Flavor.fromName('prod'), Flavor.prod);
    expect(Flavor.fromName('staging'), isNull);
    expect(Flavor.fromName(null), isNull);
  });

  test('each flavor points at its backend', () {
    expect(Flavor.dev.apiBaseUrl, Environments.localApiBaseUrl);
    expect(Flavor.uat.apiBaseUrl, Environments.stagingApiBaseUrl);
    expect(Flavor.prod.apiBaseUrl, Environments.prodApiBaseUrl);
    expect(Flavor.uat.realtimeUrl, Environments.stagingRealtimeUrl);
  });

  test('network logging is off only in prod', () {
    expect(Flavor.dev.enableNetworkLogging, isTrue);
    expect(Flavor.uat.enableNetworkLogging, isTrue);
    expect(Flavor.prod.enableNetworkLogging, isFalse);
  });

  test('pin() decides Flavor.current and AppEnv.defaults()', () {
    Flavor.pin(Flavor.prod);
    expect(Flavor.current, Flavor.prod);
    final env = AppEnv.defaults();
    expect(env.apiBaseUrl, Environments.prodApiBaseUrl);
    expect(env.enableNetworkLogging, isFalse);
    Flavor.pin(Flavor.dev);
  });
}
