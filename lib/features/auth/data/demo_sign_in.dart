import 'package:injectable/injectable.dart';

import '../entities/user.dart';
import 'datasources/cached_user_dao.dart';

/// Seeds a demo user + permission set into drift so the
/// [`StubAuthSession.simulateSignIn`] flow has a real signed-in identity
/// for use cases that consult [`PermissionsSnapshot.currentUserId`] —
/// notably the Slice 3.2.4 approve/reject UseCases.
///
/// **Demo only**: real sign-in lives in `AuthRepositoryImpl`. This
/// service exists so the no-backend developer flow ("simulated login"
/// from `LoginPage`) lands in a state that's structurally identical to
/// a real session — same drift rows, same permissions snapshot.
@lazySingleton
class DemoSignInService {
  DemoSignInService(this._dao);

  final CachedUserDao _dao;

  /// Permissions handed to the demo user. The finance/procurement/etc.
  /// modules were removed; `admin` surfaces the admin-demo tile and chat
  /// is ungated, so a single scope covers what's left. Matches the static
  /// seed in `CachedUserDao`.
  static const Set<String> demoRoles = {
    'admin',
  };

  static const String demoUserId = 'user-demo';

  Future<void> seed() async {
    await _dao.cacheUser(const User(
      id: demoUserId,
      email: 'demo@erp.example',
      displayName: 'Demo Approver',
      roles: demoRoles,
    ));
  }
}
