import 'package:flutter/services.dart' show appFlavor;

import 'environments.dart';

/// Build flavors: `dev`, `uat`, `prod`.
///
/// Selected at build time with `--flavor <name>` (Android product flavor /
/// iOS scheme of the same name). Flutter bakes that name into the
/// [appFlavor] constant, so [Flavor.current] works everywhere — including
/// background isolates (FCM handler, native call Reject) that never run
/// `main()`. The `lib/main_<flavor>.dart` entry points pin it explicitly
/// as well, so `-t lib/main_uat.dart` and `--flavor uat` always agree.
///
/// All flavors share the same app ID (one Firebase / push / CallKit
/// registration); they differ by backend, app name and logging.
enum Flavor {
  dev,
  uat,
  prod;

  static Flavor? _override;

  /// The running flavor: the one pinned by a `main_<flavor>.dart` entry
  /// point, else the `--flavor` build flag, else [dev] (plain `flutter run`
  /// without a flavor).
  static Flavor get current => _override ?? fromName(appFlavor) ?? dev;

  /// Called once by the `main_<flavor>.dart` entry points.
  static void pin(Flavor flavor) => _override = flavor;

  static Flavor? fromName(String? name) {
    for (final f in values) {
      if (f.name == name) return f;
    }
    return null;
  }

  /// App name shown in debug banners / logs (the launcher name is set
  /// natively per flavor: Android `resValue`, iOS `FLAVOR_APP_NAME`).
  String get appName => switch (this) {
        dev => 'ERP Dev',
        uat => 'ERP UAT',
        prod => 'ERP',
      };

  String get apiBaseUrl => switch (this) {
        dev => Environments.localApiBaseUrl,
        uat => Environments.stagingApiBaseUrl,
        prod => Environments.prodApiBaseUrl,
      };

  String get realtimeUrl => switch (this) {
        dev => Environments.localRealtimeUrl,
        uat => Environments.stagingRealtimeUrl,
        prod => Environments.prodRealtimeUrl,
      };

  /// dio request/response logging — never in prod.
  bool get enableNetworkLogging => this != prod;
}
