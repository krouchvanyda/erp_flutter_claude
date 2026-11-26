import 'package:erp_mobile/core/network/local_network_probe.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // iOS asks "Local Network?" only for these: the probe runs only for them.
  test('local hosts → yes; internet / loopback / names → no', () {
    for (final h in ['172.26.17.118', '192.168.1.5', '10.0.0.2', 'mac.local']) {
      expect(LocalNetworkProbe.isLocalHost(h), isTrue, reason: h);
    }
    for (final h in [
      'api.example.com',
      '8.8.8.8',
      '172.32.0.1', // just outside 172.16–31
      '127.0.0.1',
      '',
    ]) {
      expect(LocalNetworkProbe.isLocalHost(h), isFalse, reason: h);
    }
  });
}
