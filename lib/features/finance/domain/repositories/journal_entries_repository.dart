import '../entities/journal_entry.dart';

/// Domain contract for the general ledger feed (Slice 3.3.1).
abstract class JournalEntriesRepository {
  Future<List<JournalEntry>> getAll();
  Stream<List<JournalEntry>> watchAll();
  Future<JournalEntry?> findById(String id);
}
