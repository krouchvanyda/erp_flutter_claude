import 'package:flutter/services.dart' show appFlavor;

import 'environments.dart';

/// Build flavors: `dev`, `uat`, `prod`.
///
/// Chosen at build time: `flutter run --flavor dev -t lib/main_dev.dart`.
enum Flavor {
  dev,
  uat,
  prod;

  static Flavor? _pinned;

  /// The running flavor.
  /// 1. the one pinned by `main_<flavor>.dart`, else
  /// 2. the `--flavor` build flag (Flutter's [appFlavor]), else
  /// 3. [dev].
  static Flavor get current => _pinned ?? fromName(appFlavor) ?? dev;

  /// Called once at start-up by the entry point.
  static void pin(Flavor flavor) => _pinned = flavor;

  static Flavor? fromName(String? name) {
    for (final f in values) {
      if (f.name == name) return f;
    }
    return null;
  }

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

  /// Print HTTP requests/responses — never in prod.
  bool get enableNetworkLogging => this != prod;
}
