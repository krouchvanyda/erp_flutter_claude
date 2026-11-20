import 'package:erp_mobile/core/network/network_error_model.dart';
import 'package:erp_mobile/core/utils/constants.dart';
import 'package:erp_mobile/core/widgets/app_error_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('each error type gets a matching icon', () {
    expect(
      AppErrorView.iconFor(const NoInternetError()),
      Icons.wifi_off_rounded,
    );
    expect(
      AppErrorView.iconFor(
        const NoInternetError(
          title: Constants.serverUnreachable,
          description: Constants.pleaseTryLater,
        ),
      ),
      Icons.cloud_off_rounded,
    );
    expect(
      AppErrorView.iconFor(
        const NoInternetError(
          title: Constants.timeout,
          description: Constants.serverTooSlow,
        ),
      ),
      Icons.hourglass_empty_rounded,
    );
    expect(
      AppErrorView.iconFor(
        const ServerError(description: 'boom', statusCode: 500),
      ),
      Icons.error_outline_rounded,
    );
    expect(
      AppErrorView.iconFor(const UnauthorizedError()),
      Icons.lock_outline_rounded,
    );
    expect(
      AppErrorView.iconFor(const UnknownError()),
      Icons.help_outline_rounded,
    );
  });

  test('fromError copies title + message; server errors look "red"', () {
    final view = AppErrorView.fromError(
      const ServerError(description: 'Database is down', statusCode: 500),
      onRetry: () {},
    );
    expect(view.title, Constants.serverError);
    expect(view.message, 'Database is down');
    expect(view.isServerProblem, isTrue);

    final offline = AppErrorView.fromError(
      const NoInternetError(),
      onRetry: () {},
    );
    expect(offline.isServerProblem, isFalse); // calm grey
  });
}
