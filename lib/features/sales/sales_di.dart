import 'package:get_it/get_it.dart';

import 'data/repositories/stub_activities_repository.dart';
import 'data/repositories/stub_contacts_repository.dart';
import 'data/repositories/stub_customers_repository.dart';
import 'data/repositories/stub_quotations_repository.dart';
import 'data/repositories/stub_sales_orders_repository.dart';
import 'data/repositories/stub_sales_reps_repository.dart';
import 'domain/repositories/activities_repository.dart';
import 'domain/repositories/contacts_repository.dart';
import 'domain/repositories/customers_repository.dart';
import 'domain/repositories/quotations_repository.dart';
import 'domain/repositories/sales_orders_repository.dart';
import 'domain/repositories/sales_reps_repository.dart';
import 'presentation/bloc/customer_list_bloc.dart';

/// Manual DI registration for Module 6 (Sales & CRM).
///
/// **Why manual** (same rationale as Modules 4 + 5): keeps the slice
/// landable without re-running build_runner for every repo / bloc
/// tweak. Call once from `main.dart` after `configureDependencies()`.
void registerSalesModule(GetIt getIt) {
  if (!getIt.isRegistered<CustomersRepository>()) {
    getIt.registerLazySingleton<CustomersRepository>(
      StubCustomersRepository.new,
    );
  }
  if (!getIt.isRegistered<ContactsRepository>()) {
    getIt.registerLazySingleton<ContactsRepository>(
      StubContactsRepository.new,
    );
  }
  if (!getIt.isRegistered<ActivitiesRepository>()) {
    getIt.registerLazySingleton<ActivitiesRepository>(
      StubActivitiesRepository.new,
    );
  }
  if (!getIt.isRegistered<QuotationsRepository>()) {
    getIt.registerLazySingleton<QuotationsRepository>(
      StubQuotationsRepository.new,
    );
  }
  if (!getIt.isRegistered<SalesOrdersRepository>()) {
    getIt.registerLazySingleton<SalesOrdersRepository>(
      StubSalesOrdersRepository.new,
    );
  }
  if (!getIt.isRegistered<SalesRepsRepository>()) {
    getIt.registerLazySingleton<SalesRepsRepository>(
      StubSalesRepsRepository.new,
    );
  }
  if (!getIt.isRegistered<CustomerListBloc>()) {
    getIt.registerFactory<CustomerListBloc>(
      () => CustomerListBloc(repository: getIt()),
    );
  }
}
