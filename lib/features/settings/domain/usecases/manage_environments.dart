import '../../../../core/error/failure.dart';
import '../entities/api_environment.dart';

/// Slice 9.2.3 — validate a new custom environment before persisting.
ApiEnvironment validateApiEnvironment({
  required String name,
  required String baseUrl,
}) {
  final errors = <String, List<String>>{};
  if (name.trim().isEmpty) {
    errors.putIfAbsent('name', () => []).add('Required');
  }
  final url = baseUrl.trim();
  if (url.isEmpty) {
    errors.putIfAbsent('baseUrl', () => []).add('Required');
  } else {
    final uri = Uri.tryParse(url);
    final hasScheme =
        uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
    if (!hasScheme || uri.host.isEmpty) {
      errors.putIfAbsent('baseUrl', () => [])
          .add('Must be an http(s) URL');
    }
  }
  if (errors.isNotEmpty) {
    throw ValidationFailure(fieldErrors: errors);
  }
  return ApiEnvironment(
    id: '', // assigned by repo
    name: name.trim(),
    baseUrl: url,
    isBuiltIn: false,
  );
}

/// Slice 9.2.3 — refuse to delete a built-in env or the currently
/// selected one.
void ensureEnvironmentIsDeletable({
  required ApiEnvironment env,
  required String currentEnvironmentId,
}) {
  if (env.isBuiltIn) {
    throw ConflictFailure(
        message: 'Built-in environments cannot be deleted');
  }
  if (env.id == currentEnvironmentId) {
    throw ConflictFailure(
        message: 'Switch to another environment before deleting this one');
  }
}
