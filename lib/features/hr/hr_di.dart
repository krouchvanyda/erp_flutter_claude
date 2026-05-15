import 'package:get_it/get_it.dart';

import 'data/repositories/stub_attendance_repository.dart';
import 'data/repositories/stub_employees_repository.dart';
import 'data/repositories/stub_leave_repository.dart';
import 'data/repositories/stub_payslips_repository.dart';
import 'domain/repositories/attendance_repository.dart';
import 'domain/repositories/employees_repository.dart';
import 'domain/repositories/leave_requests_repository.dart';
import 'domain/repositories/payslips_repository.dart';
import 'presentation/bloc/employee_list_bloc.dart';

/// Manual DI registration for Module 7 (Human Resources).
///
/// **Why manual** (same rationale as Modules 4 + 5 + 6): keeps the
/// slice landable without re-running build_runner for every repo / bloc
/// tweak. Call once from `main.dart` after `configureDependencies()`.
void registerHrModule(GetIt getIt) {
  if (!getIt.isRegistered<EmployeesRepository>()) {
    getIt.registerLazySingleton<EmployeesRepository>(
      StubEmployeesRepository.new,
    );
  }
  if (!getIt.isRegistered<LeaveRequestsRepository>()) {
    getIt.registerLazySingleton<LeaveRequestsRepository>(
      StubLeaveRequestsRepository.new,
    );
  }
  if (!getIt.isRegistered<LeaveBalancesRepository>()) {
    getIt.registerLazySingleton<LeaveBalancesRepository>(
      StubLeaveBalancesRepository.new,
    );
  }
  if (!getIt.isRegistered<AttendanceRepository>()) {
    getIt.registerLazySingleton<AttendanceRepository>(
      StubAttendanceRepository.new,
    );
  }
  if (!getIt.isRegistered<PayslipsRepository>()) {
    getIt.registerLazySingleton<PayslipsRepository>(
      StubPayslipsRepository.new,
    );
  }
  if (!getIt.isRegistered<EmployeeListBloc>()) {
    getIt.registerFactory<EmployeeListBloc>(
      () => EmployeeListBloc(repository: getIt()),
    );
  }
}
