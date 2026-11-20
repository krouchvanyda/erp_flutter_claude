import '../../auth/model/user_model.dart';
import 'employee_model.dart';

/// What the profile page shows: my login user + my employee record (if any).
///
/// ```
/// GET /users/me      → user      (always)
/// GET /employees/me  → employee  (null when the server says 404)
/// ```
///
/// The page never asks "user or employee?": these getters decide once.
class ProfileModel {
  const ProfileModel({required this.user, this.employee});

  final UserModel user;
  final EmployeeModel? employee;

  String get displayName => user.displayName;

  String get email => user.email;

  /// Prefer the login phone; fall back to the employee record.
  String? get phone => _firstNotEmpty(user.phone, employee?.phone);

  /// The avatar upload (Step 4.2) goes to `/employees/me/avatar`, so the
  /// employee's avatar is newest; fall back to the user's.
  String? get avatarUrl => _firstNotEmpty(employee?.avatarUrl, user.avatarUrl);

  static String? _firstNotEmpty(String? a, String? b) =>
      (a != null && a.trim().isNotEmpty) ? a : b;

  @override
  bool operator ==(Object other) =>
      other is ProfileModel && other.user == user && other.employee == employee;

  @override
  int get hashCode => Object.hash(user, employee);

  @override
  String toString() => 'ProfileModel($user, $employee)';
}
