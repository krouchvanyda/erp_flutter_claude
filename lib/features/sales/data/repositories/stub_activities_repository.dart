import '../../domain/entities/activity_event.dart';
import '../../domain/repositories/activities_repository.dart';
import '../sales_seed.dart';

class StubActivitiesRepository implements ActivitiesRepository {
  StubActivitiesRepository();

  static final List<ActivityEvent> _seed =
      List<ActivityEvent>.of(SalesSeed.activities);

  static int _idCounter = 100;

  @override
  Future<List<ActivityEvent>> forCustomer(String customerId) async {
    final rows = _seed.where((a) => a.customerId == customerId).toList();
    rows.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return List.unmodifiable(rows);
  }

  @override
  Future<ActivityEvent> append(ActivityEvent draft) async {
    _idCounter++;
    final persisted = ActivityEvent(
      id: 'act-${_idCounter.toString().padLeft(3, '0')}',
      customerId: draft.customerId,
      type: draft.type,
      occurredAt: draft.occurredAt,
      summary: draft.summary,
      actor: draft.actor,
      amount: draft.amount,
      reference: draft.reference,
    );
    _seed.add(persisted);
    return persisted;
  }

  @override
  Future<List<ActivityEvent>> allOfType(ActivityEventType type) async {
    return _seed.where((a) => a.type == type).toList(growable: false);
  }
}
