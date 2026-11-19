import 'package:flutter/foundation.dart';

/// "Is the user signed in?" — in memory only.
///
/// The router listens to this ([ChangeNotifier]) and re-runs its `redirect`
/// every time it changes. So pages never navigate after login/logout
/// themselves — they flip the session, and the router moves them.
///
/// Boots to `false` on every cold start. In Step 3 the splash reads the
/// stored tokens and calls [markAuthenticated] when they exist.
class AuthSession extends ChangeNotifier {
  bool _isAuthenticated = false;

  bool get isAuthenticated => _isAuthenticated;

  void markAuthenticated() => _set(true);

  void markLoggedOut() => _set(false);

  void _set(bool value) {
    if (_isAuthenticated == value) return; // no change → don't wake the router
    _isAuthenticated = value;
    notifyListeners();
  }
}
