import 'package:get_it/get_it.dart';

import '../../core/database/sync_queue_dao.dart';
import '../../core/push/push_notification_service.dart';
import 'data/datasources/items_dao.dart';
import 'data/low_stock_notifier.dart';
import 'data/repositories/drift_items_repository.dart';
import 'data/repositories/drift_stock_movements_repository.dart';
import 'domain/repositories/items_repository.dart';
import 'domain/repositories/stock_movements_repository.dart';
import 'domain/usecases/apply_cycle_count.dart';
import 'domain/usecases/record_stock_movement.dart';
import 'domain/usecases/transfer_stock.dart';
import 'presentation/bloc/items_list_bloc.dart';

/// Manual DI registration for Module 5 (Inventory).
///
/// **Why manual** (same rationale as `registerProcurementModule`):
/// avoids re-running build_runner for every repo / use-case tweak.
/// The drift `ItemsDao` itself is registered upstream in
/// `register_module.dart` (alongside the other DAO bindings); this
/// function consumes that registration.
///
/// Call once from `main.dart` after `configureDependencies()`. Also
/// starts the [`LowStockNotifier`] watcher so Slice 5.1.3 alerts
/// fire from boot.
void registerInventoryModule(GetIt getIt) {
  if (!getIt.isRegistered<ItemsRepository>()) {
    getIt.registerLazySingleton<ItemsRepository>(
      () => DriftItemsRepository(
        dao: getIt<ItemsDao>(),
        syncQueue: getIt<SyncQueueDao>(),
      ),
    );
  }
  if (!getIt.isRegistered<StockMovementsRepository>()) {
    getIt.registerLazySingleton<StockMovementsRepository>(
      () => DriftStockMovementsRepository(
        dao: getIt<ItemsDao>(),
        syncQueue: getIt<SyncQueueDao>(),
      ),
    );
  }
  if (!getIt.isRegistered<RecordStockMovementUseCase>()) {
    getIt.registerLazySingleton<RecordStockMovementUseCase>(
      () => RecordStockMovementUseCase(
        itemsRepository: getIt(),
        movementsRepository: getIt(),
      ),
    );
  }
  if (!getIt.isRegistered<TransferStockUseCase>()) {
    getIt.registerLazySingleton<TransferStockUseCase>(
      () => TransferStockUseCase(
        itemsRepository: getIt(),
        movementsRepository: getIt(),
      ),
    );
  }
  if (!getIt.isRegistered<ApplyCycleCountUseCase>()) {
    getIt.registerLazySingleton<ApplyCycleCountUseCase>(
      () => ApplyCycleCountUseCase(
        itemsRepository: getIt(),
        movementsRepository: getIt(),
      ),
    );
  }
  if (!getIt.isRegistered<ItemsListBloc>()) {
    getIt.registerFactory<ItemsListBloc>(
      () => ItemsListBloc(repository: getIt()),
    );
  }
  if (!getIt.isRegistered<LowStockNotifier>()) {
    getIt.registerLazySingleton<LowStockNotifier>(
      () => LowStockNotifier(
        items: getIt(),
        push: getIt<PushNotificationService>(),
      ),
    );
    // Kick the watcher into life so the first low-stock dip fires a
    // notification without waiting for the alerts page to open.
    getIt<LowStockNotifier>().start();
  }
}
