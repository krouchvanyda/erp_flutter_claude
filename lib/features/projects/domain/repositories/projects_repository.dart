import '../entities/project.dart';

abstract class ProjectsRepository {
  Future<List<Project>> getAll();
  Stream<List<Project>> watchAll();
  Future<Project?> findById(String id);
}
