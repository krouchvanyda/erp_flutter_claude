import 'package:get_it/get_it.dart';

import 'data/repositories/stub_projects_repository.dart';
import 'data/repositories/stub_tasks_repository.dart';
import 'data/repositories/stub_timesheets_repository.dart';
import 'domain/repositories/projects_repository.dart';
import 'domain/repositories/tasks_repository.dart';
import 'domain/repositories/timesheets_repository.dart';
import 'presentation/bloc/project_list_bloc.dart';

/// Manual DI registration for Module 8 (Project Management).
///
/// Same pattern as Modules 4–7: avoids re-running build_runner per
/// repo/bloc tweak. Call once from `main.dart` after
/// `configureDependencies()`.
void registerProjectsModule(GetIt getIt) {
  if (!getIt.isRegistered<ProjectsRepository>()) {
    getIt.registerLazySingleton<ProjectsRepository>(
      StubProjectsRepository.new,
    );
  }
  if (!getIt.isRegistered<TasksRepository>()) {
    getIt.registerLazySingleton<TasksRepository>(
      StubTasksRepository.new,
    );
  }
  if (!getIt.isRegistered<TaskCommentsRepository>()) {
    getIt.registerLazySingleton<TaskCommentsRepository>(
      StubTaskCommentsRepository.new,
    );
  }
  if (!getIt.isRegistered<TimesheetsRepository>()) {
    getIt.registerLazySingleton<TimesheetsRepository>(
      StubTimesheetsRepository.new,
    );
  }
  if (!getIt.isRegistered<ProjectListBloc>()) {
    getIt.registerFactory<ProjectListBloc>(
      () => ProjectListBloc(repository: getIt()),
    );
  }
}
