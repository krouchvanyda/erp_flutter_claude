import '../entities/activity_event.dart';

/// Domain contract for the customer activity timeline (Slice 6.1.3).
abstract class ActivitiesRepository {
  /// Returns the timeline newest-first.
  Future<List<ActivityEvent>> forCustomer(String customerId);

  /// Appends a new event (e.g. a posted order or call note).
  Future<ActivityEvent> append(ActivityEvent draft);

  /// Cross-customer feed — drives analytics aggregations (Phase 6.3).
  Future<List<ActivityEvent>> allOfType(ActivityEventType type);
}
