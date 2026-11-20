import 'package:dartz/dartz.dart' show Either, Left, Right;

import '../../../core/network/api_endpoints.dart';
import '../../../core/network/app_service.dart';
import '../../../core/network/helper_service.dart';
import '../../../core/network/network_error_model.dart';
import '../../auth/model/user_model.dart';
import '../model/employee_model.dart';
import '../model/profile_model.dart';

/// Profile business rules. The BLoC calls this; it never touches Dio.
class ProfileRepository {
  ProfileRepository({required AppService appService})
    : _appService = appService;

  final AppService _appService;

  /// Loads my user AND my employee record at the same time.
  ///
  /// - user fails     → Left(error): nothing to show.
  /// - employee fails → employee = null: show the user part anyway.
  ///   (404 = "no linked employee" is normal; any other error must not
  ///   hide the whole profile either.)
  Future<Either<NetworkErrorModel, ProfileModel>> loadProfile() async {
    final (userResult, employeeResult) = await (
      _appService.send(
        httpMethods: HttpMethods.get,
        endPoint: ApiEndPoint.me,
        parse: (data) => UserModel.fromJson(data as Map<String, dynamic>),
      ),
      _appService.send(
        httpMethods: HttpMethods.get,
        endPoint: ApiEndPoint.employeesMe,
        parse: (data) => EmployeeModel.fromJson(data as Map<String, dynamic>),
      ),
    ).wait;

    final employee = employeeResult.fold((_) => null, (e) => e);
    return userResult.fold(
      Left.new, // same as (error) => Left(error)
      (user) => Right(ProfileModel(user: user, employee: employee)),
    );
  }
}
