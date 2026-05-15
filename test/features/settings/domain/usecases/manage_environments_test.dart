import 'package:erp_mobile/core/error/failure.dart';
import 'package:erp_mobile/features/settings/domain/entities/api_environment.dart';
import 'package:erp_mobile/features/settings/domain/usecases/manage_environments.dart';
import 'package:test/test.dart';

void main() {
  group('validateApiEnvironment', () {
    test('accepts a https URL', () {
      final env = validateApiEnvironment(
        name: 'Tenant A',
        baseUrl: 'https://api.tenant-a.example',
      );
      expect(env.name, 'Tenant A');
      expect(env.baseUrl, 'https://api.tenant-a.example');
      expect(env.isBuiltIn, isFalse);
    });

    test('accepts an http URL (e.g. local dev)', () {
      final env = validateApiEnvironment(
        name: 'Local',
        baseUrl: 'http://localhost:8080',
      );
      expect(env.baseUrl, 'http://localhost:8080');
    });

    test('rejects empty name', () {
      expect(
        () => validateApiEnvironment(name: '', baseUrl: 'https://x.example'),
        throwsA(isA<ValidationFailure>().having(
          (f) => f.fieldErrors,
          'fieldErrors',
          containsPair('name', isNotEmpty),
        )),
      );
    });

    test('rejects non-http(s) scheme', () {
      expect(
        () => validateApiEnvironment(
            name: 'X', baseUrl: 'ftp://files.example'),
        throwsA(isA<ValidationFailure>().having(
          (f) => f.fieldErrors,
          'fieldErrors',
          containsPair('baseUrl', isNotEmpty),
        )),
      );
    });

    test('rejects URL with no host', () {
      expect(
        () => validateApiEnvironment(name: 'X', baseUrl: 'https://'),
        throwsA(isA<ValidationFailure>()),
      );
    });
  });

  group('ensureEnvironmentIsDeletable', () {
    final builtIn = ApiEnvironment(
      id: 'env-prod',
      name: 'Prod',
      baseUrl: 'https://api.example',
      isBuiltIn: true,
    );
    final custom = ApiEnvironment(
      id: 'env-tenant',
      name: 'Tenant',
      baseUrl: 'https://tenant.example',
    );

    test('refuses built-in', () {
      expect(
        () => ensureEnvironmentIsDeletable(
          env: builtIn,
          currentEnvironmentId: 'env-other',
        ),
        throwsA(isA<ConflictFailure>()),
      );
    });

    test('refuses currently selected env', () {
      expect(
        () => ensureEnvironmentIsDeletable(
          env: custom,
          currentEnvironmentId: 'env-tenant',
        ),
        throwsA(isA<ConflictFailure>()),
      );
    });

    test('passes for an inactive custom env', () {
      ensureEnvironmentIsDeletable(
        env: custom,
        currentEnvironmentId: 'env-prod',
      );
    });
  });
}
