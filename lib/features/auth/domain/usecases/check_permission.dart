import '../entities/permission.dart';
import '../repositories/permissions_repository.dart';

/// "Does this user hold the [required] permission?"
///
/// Trivially delegates to [PermissionsRepository.hasPermission]; the
/// use case exists so future call sites (route guard, `PermissionGuard`
/// widget, BLoCs) depend on a stable domain seam rather than the
/// repository directly.
class CheckPermissionUseCase {
  const CheckPermissionUseCase({
    required PermissionsRepository repository,
  }) : _repository = repository;

  final PermissionsRepository _repository;

  Future<bool> call({
    required String userId,
    required Permission required,
  }) =>
      _repository.hasPermission(userId, required);
}
