import 'package:erp_mobile/core/error/failure.dart';
import 'package:erp_mobile/features/settings/domain/entities/device_session.dart';
import 'package:erp_mobile/features/settings/domain/usecases/manage_sessions.dart';
import 'package:test/test.dart';

DeviceSession _s({bool isCurrent = false}) => DeviceSession(
      id: 's',
      deviceLabel: 'Device',
      platform: 'Android 14',
      lastActiveAt: DateTime.utc(2026, 5, 15),
      signedInAt: DateTime.utc(2026, 5, 1),
      location: 'KH',
      isCurrent: isCurrent,
    );

void main() {
  group('ensureSessionIsRevocable', () {
    test('refuses to revoke the current device', () {
      expect(
        () => ensureSessionIsRevocable(_s(isCurrent: true)),
        throwsA(isA<ConflictFailure>()),
      );
    });

    test('passes for any other device', () {
      ensureSessionIsRevocable(_s(isCurrent: false));
    });
  });
}
