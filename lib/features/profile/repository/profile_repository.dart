import 'package:dartz/dartz.dart' show Either, Left, Right;
import 'package:dio/dio.dart' show DioMediaType, FormData, MultipartFile;

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

  /// Step 4.2: upload a new avatar, then load the profile again.
  ///
  /// `POST /employees/me/avatar` as multipart, field name `file`
  /// (API_LIST_BACKEND.md §5). We don't guess the response shape: after a
  /// successful upload we just reload, so the page shows exactly what the
  /// server now has.
  Future<Either<NetworkErrorModel, ProfileModel>> uploadAvatar(
    String filePath,
  ) async {
    final name = filePath.split('/').last;
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        filePath,
        filename: name,
        contentType: DioMediaType.parse(_imageType(name)),
      ),
    });
    final result = await _appService.send<void>(
      httpMethods: HttpMethods.post,
      endPoint: ApiEndPoint.employeesMeAvatar,
      formData: form,
      parse: (_) {},
    );
    return result.fold(Left.new, (_) => loadProfile());
  }

  /// Step 4.2: remove my avatar (`DELETE /employees/me/avatar`), then reload.
  Future<Either<NetworkErrorModel, ProfileModel>> removeAvatar() async {
    final result = await _appService.send<void>(
      httpMethods: HttpMethods.delete,
      endPoint: ApiEndPoint.employeesMeAvatar,
      parse: (_) {},
    );
    return result.fold(Left.new, (_) => loadProfile());
  }

  /// "photo.PNG" → "image/png". Servers often reject
  /// "application/octet-stream" (Dio's default) for images.
  static String _imageType(String fileName) =>
      switch (fileName.split('.').last.toLowerCase()) {
        'png' => 'image/png',
        'heic' => 'image/heic',
        'webp' => 'image/webp',
        _ => 'image/jpeg', // jpg, jpeg, and the picker's default output
      };
}
