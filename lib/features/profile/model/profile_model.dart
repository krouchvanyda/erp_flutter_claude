import '../../auth/model/user_model.dart';
import 'employee_model.dart';

/// What the profile page shows: my login user + my employee record (if any).
///
/// ```
/// user      → cached at login (UserCache), or GET /users/me
/// employee  → GET /employees/me, fresh every load (null when 404)
/// ```
///
/// The page never asks "user or employee?": these getters decide once.
class ProfileModel {
  const ProfileModel({required this.user, this.employee});

  final UserModel user;
  final EmployeeModel? employee;

  /// The employee record is loaded fresh every time; the user may come from
  /// the login-time cache. So for name + phone the EMPLOYEE wins.
  String get displayName =>
      _firstNotEmpty(employee?.fullName, null) ?? user.displayName;

  /// The LOGIN email (what you type to sign in), not the HR `workEmail`.
  String get email => user.email;

  /// Prefer the employee phone (fresh); fall back to the login user's.
  String? get phone => _firstNotEmpty(employee?.phone, user.phone);

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
