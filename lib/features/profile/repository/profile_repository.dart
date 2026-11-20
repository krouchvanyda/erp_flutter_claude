import 'package:dartz/dartz.dart' show Either, Left, Right;
import 'package:dio/dio.dart' show DioMediaType, FormData, MultipartFile;

import '../../../core/network/api_endpoints.dart';
import '../../../core/network/app_service.dart';
import '../../../core/network/helper_service.dart';
import '../../../core/network/network_error_model.dart';
import '../../../core/storage/user_cache.dart';
import '../../auth/model/user_model.dart';
import '../model/employee_model.dart';
import '../model/profile_model.dart';

/// Profile business rules. The BLoC calls this; it never touches Dio.
class ProfileRepository {
  ProfileRepository({
    required AppService appService,
    required UserCache userCache,
  }) : _appService = appService,
       _userCache = userCache;

  final AppService _appService;
  final UserCache _userCache;

  /// My profile = my employee record + my login user.
  ///
  /// ```
  /// user in the cache?
  ///   yes → GET /employees/me                      (1 request, normal)
  ///          └ 404 (no employee) → GET /users/me   (fresh user, re-cached)
  ///   no  → GET /users/me + GET /employees/me      (together, fills the cache)
  /// ```
  ///
  /// - The cache is filled at login. It is empty only for a session that
  ///   was restored from tokens saved before the cache existed.
  /// - 404 on the employee = "no linked employee" → show the user part.
  /// - Any OTHER employee error (offline, 500) → Left: the employee is now
  ///   the main source (name, phone, photo), so a half page would mislead.
  Future<Either<NetworkErrorModel, ProfileModel>> loadProfile() async {
    final cachedJson = _userCache.read();
    if (cachedJson == null) {
      final (userResult, employeeResult) = await (
        _fetchUser(),
        _fetchEmployee(),
      ).wait;
      return userResult.fold(
        Left.new, // same as (error) => Left(error)
        (user) => _combine(user, employeeResult),
      );
    }

    final employeeResult = await _fetchEmployee();
    if (_isNotFound(employeeResult)) {
      // No employee → the user is ALL we show, so make sure it's fresh.
      // (If that fails, the cached one is still good enough.)
      final fresh = await _fetchUser();
      final user = fresh.getOrElse(() => UserModel.fromJson(cachedJson));
      return Right(ProfileModel(user: user));
    }
    return _combine(UserModel.fromJson(cachedJson), employeeResult);
  }

  /// `GET /users/me` → UserModel, and remember the raw JSON for next time.
  Future<Either<NetworkErrorModel, UserModel>> _fetchUser() async {
    final result = await _appService.send(
      httpMethods: HttpMethods.get,
      endPoint: ApiEndPoint.me,
      parse: (data) => data as Map<String, dynamic>,
    );
    return result.fold<Future<Either<NetworkErrorModel, UserModel>>>(
      (error) async => Left(error),
      (json) async {
        await _userCache.save(json);
        return Right(UserModel.fromJson(json));
      },
    );
  }

  Future<Either<NetworkErrorModel, EmployeeModel>> _fetchEmployee() =>
      _appService.send(
        httpMethods: HttpMethods.get,
        endPoint: ApiEndPoint.employeesMe,
        parse: (data) => EmployeeModel.fromJson(data as Map<String, dynamic>),
      );

  static bool _isNotFound(Either<NetworkErrorModel, EmployeeModel> result) =>
      result.fold((error) => error.statusCode == 404, (_) => false);

  /// user + employee result → the profile (see the rules above).
  static Either<NetworkErrorModel, ProfileModel> _combine(
    UserModel user,
    Either<NetworkErrorModel, EmployeeModel> employeeResult,
  ) => employeeResult.fold(
    (error) => error.statusCode == 404
        ? Right(ProfileModel(user: user)) // no linked employee → still show
        : Left(error),
    (employee) => Right(ProfileModel(user: user, employee: employee)),
  );

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
