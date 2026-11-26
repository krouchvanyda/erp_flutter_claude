import 'dart:async';

import 'package:flutter/foundation.dart';

import 'api_endpoints.dart';
import 'app_service.dart';
import 'helper_service.dart';

/// Makes iOS ask "Allow … to find devices on local networks?" on the SPLASH,
/// not on the first real request (the login).
///
/// iOS blocks the FIRST connection to a local address (`172.26.x.x`,
/// `192.168.x.x`, …) while that question is open, so a login tapped first
/// failed with `connectionError`. One tiny request at start-up (its answer
/// is ignored) moves the question to the splash.
///
/// Only when the server is on a LOCAL network (dev against your Mac) and
/// only on iOS: a real server on the internet never triggers the question.
class LocalNetworkProbe {
  LocalNetworkProbe(this._appService, {required String baseUrl})
    : _host = Uri.tryParse(baseUrl)?.host ?? '';

  final AppService _appService;
  final String _host;

  /// Private IPv4 ranges + `.local` names: what iOS calls "local network".
  @visibleForTesting
  static bool isLocalHost(String host) {
    if (host.endsWith('.local')) return true;
    final parts = host.split('.').map(int.tryParse).toList();
    if (parts.length != 4 || parts.contains(null)) return false;
    final a = parts[0]!, b = parts[1]!;
    return a == 10 ||
        (a == 172 && b >= 16 && b <= 31) ||
        (a == 192 && b == 168) ||
        (a == 169 && b == 254);
  }

  /// Fire and forget: never awaited, never throws, result ignored.
  void ping() {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    if (!isLocalHost(_host)) return;
    unawaited(
      _appService.send<void>(
        httpMethods: HttpMethods.get,
        endPoint: ApiEndPoint.health,
        parse: (_) {},
      ),
    );
  }
}
