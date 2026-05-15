import 'package:erp_mobile/features/settings/domain/entities/audit_log_entry.dart';
import 'package:erp_mobile/features/settings/domain/usecases/query_audit_log.dart';
import 'package:test/test.dart';

AuditLogEntry _e({
  String id = 'a',
  String actorId = 'user-1',
  String actorName = 'Alice',
  AuditAction action = AuditAction.update,
  String targetLabel = 'Invoice',
  DateTime? at,
  String? detail,
}) =>
    AuditLogEntry(
      id: id,
      actorId: actorId,
      actorName: actorName,
      action: action,
      targetType: 'invoice',
      targetId: 't',
      targetLabel: targetLabel,
      occurredAt: at ?? DateTime.utc(2026, 5, 15),
      detail: detail,
    );

void main() {
  group('queryAuditLog', () {
    final all = [
      _e(id: '1', actorId: 'u1', actorName: 'Alice',
          action: AuditAction.approve,
          at: DateTime.utc(2026, 5, 14, 10, 0)),
      _e(id: '2', actorId: 'u2', actorName: 'Bob',
          action: AuditAction.reject,
          at: DateTime.utc(2026, 5, 15, 11, 0),
          detail: 'budget overrun'),
      _e(id: '3', actorId: 'u1', actorName: 'Alice',
          action: AuditAction.signIn,
          targetLabel: 'Pixel 7',
          at: DateTime.utc(2026, 5, 13, 9, 0)),
    ];

    test('default sort is most recent first', () {
      final out = queryAuditLog(all);
      expect(out.map((e) => e.id).toList(), ['2', '1', '3']);
    });

    test('action filter narrows results', () {
      final out =
          queryAuditLog(all, actionFilter: {AuditAction.approve});
      expect(out, hasLength(1));
      expect(out.single.id, '1');
    });

    test('actor filter narrows results', () {
      final out = queryAuditLog(all, actorFilter: {'u1'});
      expect(out.map((e) => e.id).toSet(), {'1', '3'});
    });

    test('search hits actor, target, and detail', () {
      // Detail match.
      expect(queryAuditLog(all, searchQuery: 'budget').single.id, '2');
      // Target label match.
      expect(queryAuditLog(all, searchQuery: 'pixel').single.id, '3');
    });

    test('date filter inclusive on both ends', () {
      final out = queryAuditLog(
        all,
        from: DateTime.utc(2026, 5, 14),
        to: DateTime.utc(2026, 5, 14),
      );
      expect(out.single.id, '1');
    });

    test('empty input → empty output', () {
      expect(queryAuditLog(const []), isEmpty);
    });
  });

  group('extractActors', () {
    test('returns distinct actors sorted by name', () {
      final out = extractActors([
        _e(actorId: 'u-z', actorName: 'Zach'),
        _e(actorId: 'u-a', actorName: 'Alice'),
        _e(actorId: 'u-z', actorName: 'Zach'),
      ]);
      expect(out.map((a) => a.id).toList(), ['u-a', 'u-z']);
    });
  });
}
