import 'package:erp_mobile/core/analytics/analytics_event.dart';
import 'package:erp_mobile/core/analytics/analytics_service.dart';
import 'package:erp_mobile/core/network/session_signal.dart';
import 'package:erp_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:erp_mobile/features/auth/domain/usecases/sign_out.dart';
import 'package:test/test.dart';

import '../../../../_support/recording_analytics_service.dart';

/// Each collaborator appends a marker to the shared [log] so we can
/// assert orchestration order without juggling separate spies.
class _OrderingRepo implements AuthRepository {
  _OrderingRepo(this.log, {this.onSignOut});
  final List<String> log;
  final Future<void> Function()? onSignOut;

  @override
  Future<void> signOut() async {
    log.add('repo.signOut');
    if (onSignOut != null) await onSignOut!();
  }
}

class _OrderingSessionSignal implements SessionSignal {
  _OrderingSessionSignal(this.log);
  final List<String> log;

  @override
  Future<void> invalidate() async {
    log.add('session.invalidate');
  }
}

class _OrderingAnalytics implements AnalyticsService {
  _OrderingAnalytics(this.log);
  final List<String> log;

  @override
  Future<void> reset() async {
    log.add('analytics.reset');
  }

  // Unused for these tests, required by the interface.
  @override
  void track(AnalyticsEvent event) {}
  @override
  void screen(String name, {Map<String, Object?>? properties}) {}
  @override
  void setUserProperty(String key, Object? value) {}
  @override
  Future<void> identify(String userId, {Map<String, Object?>? traits}) async {}
  @override
  Future<void> flush() async {}
}

void main() {
  group('SignOutUseCase', () {
    test('runs repo → session → analytics in that exact order', () async {
      final order = <String>[];
      final useCase = SignOutUseCase(
        authRepository: _OrderingRepo(order),
        sessionSignal: _OrderingSessionSignal(order),
        analytics: _OrderingAnalytics(order),
      );

      await useCase.call();

      expect(order, [
        'repo.signOut',
        'session.invalidate',
        'analytics.reset',
      ]);
    });

    test('a repo throw aborts the use case before session/analytics fire',
        () async {
      final order = <String>[];
      final useCase = SignOutUseCase(
        authRepository: _OrderingRepo(
          order,
          onSignOut: () async => throw StateError('local cleanup failed'),
        ),
        sessionSignal: _OrderingSessionSignal(order),
        analytics: _OrderingAnalytics(order),
      );

      await expectLater(useCase.call(), throwsStateError);

      // Repo ran (and threw); session + analytics did not.
      expect(order, ['repo.signOut']);
    });

    test(
      'integration sanity: real RecordingAnalyticsService receives Reset',
      () async {
        final analytics = RecordingAnalyticsService();
        final order = <String>[];
        final useCase = SignOutUseCase(
          authRepository: _OrderingRepo(order),
          sessionSignal: _OrderingSessionSignal(order),
          analytics: analytics,
        );

        await useCase.call();

        expect(analytics.calls, hasLength(1));
        expect(analytics.calls.single, isA<Reset>());
      },
    );
  });
}
