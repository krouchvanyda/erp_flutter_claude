import 'package:drift/drift.dart';

import '../../features/auth/data/datasources/biometric_settings_dao.dart';
import '../../features/auth/data/datasources/cached_user_dao.dart';
import '../../features/auth/data/datasources/tables/biometric_settings.dart';
import '../../features/auth/data/datasources/tables/cached_user.dart';
import '../../features/auth/data/datasources/tables/user_permissions.dart';
import '../../features/notifications/data/datasources/notifications_dao.dart';
import '../../features/notifications/data/datasources/tables/cached_notifications.dart';
import '../sync/sync_op_status.dart';
import '../sync/sync_op_type.dart';
import '../utils/uuid_generator.dart';
import 'app_metadata_dao.dart';
import 'cache_freshness_dao.dart';
import 'sync_queue_dao.dart';
import 'tables/app_metadata.dart';
import 'tables/cache_freshness.dart';
import 'tables/sync_queue.dart';

part 'app_database.g.dart';

/// Single source of truth for the on-device sqlite store.
///
/// Per the strict folder contract every feature owns its own DAO, but the
/// schema is centralised here so drift can generate one cohesive set of
/// table classes and produce a single migration ledger.
///
/// **Adding a table**:
/// 1. Drop the table file in `lib/core/database/tables/` (or under the
///    feature's `data/datasources/` if it's feature-scoped).
/// 2. Add it to the `tables:` list below and add the DAO to `daos:`.
/// 3. Bump [schemaVersion] and add a `case` to [_migrateStep].
///
/// Constructor takes the [QueryExecutor] explicitly so the production wiring
/// (DI module → `openAppDatabase()` → file-backed sqlite) and tests
/// (`NativeDatabase.memory()`) share one entry point and the class itself
/// stays Flutter-free for unit-testability.
@DriftDatabase(
  tables: [
    AppMetadata,
    CacheFreshness,
    SyncQueue,
    CachedUser,
    UserPermissions,
    BiometricSettings,
    CachedNotifications,
  ],
  daos: [
    AppMetadataDao,
    CacheFreshnessDao,
    SyncQueueDao,
    CachedUserDao,
    BiometricSettingsDao,
    NotificationsDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 9;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async => m.createAll(),
        onUpgrade: (m, from, to) async {
          for (var v = from + 1; v <= to; v++) {
            await _migrateStep(v, m);
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  /// Forward-only migration step dispatch.
  ///
  /// Add a new `case` here every time you bump [schemaVersion]. The default
  /// branch throws so a forgotten step fails loudly during the upgrade test.
  Future<void> _migrateStep(int targetVersion, Migrator m) async {
    switch (targetVersion) {
      case 2:
        await m.createTable(cacheFreshness);
      case 3:
        await m.createTable(syncQueue);
      case 4:
        // Slice 1.1.2b — auth profile cache + offline RBAC.
        await m.createTable(cachedUser);
        await m.createTable(userPermissions);
      case 5:
        // Slice 1.2.3 — biometric unlock preference.
        await m.createTable(biometricSettings);
      case 6:
        // Slice 2.3.1 — notification inbox cache.
        await m.createTable(cachedNotifications);
      case 7:
      case 8:
      case 9:
        // Schema bumps 7–9 originally created the finance + inventory
        // caches (Slices 3.1.3 / 3.2.4 / 5.3.1). Those modules were
        // removed, so these are now no-ops: fresh installs never create
        // the tables, and existing installs upgrade past these versions
        // without recreating them (any leftover tables are harmless).
        break;
      default:
        throw StateError(
          'No migration registered to reach schema version $targetVersion. '
          'Add a `case $targetVersion` to AppDatabase._migrateStep when '
          'bumping schemaVersion.',
        );
    }
  }
}
