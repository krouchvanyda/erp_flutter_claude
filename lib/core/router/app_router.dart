import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:injectable/injectable.dart';

import '../../features/auth/presentation/pages/biometric_unlock_page.dart';
import '../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/otp_entry_page.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/dashboard/presentation/pages/admin_demo_page.dart';
import '../../features/dashboard/presentation/pages/coming_soon_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/dashboard/presentation/pages/modules_page.dart';
import '../../features/auth/data/demo_sign_in.dart';
import '../../features/auth/data/repositories/auth_repository.dart';
import '../di/injection.dart';
import '../../features/notifications/presentation/pages/notification_inbox_page.dart';
import '../../features/settings/presentation/pages/api_config_page.dart';
import '../../features/settings/presentation/pages/app_lock_page.dart';
import '../../features/settings/presentation/pages/appearance_page.dart';
import '../../features/settings/presentation/pages/assignments_page.dart';
import '../../features/settings/presentation/pages/audit_log_page.dart';
import '../../features/settings/presentation/pages/language_page.dart';
import '../../features/settings/presentation/pages/notification_preferences_page.dart';
import '../../features/settings/presentation/pages/role_editor_page.dart';
import '../../features/settings/presentation/pages/sessions_page.dart';
import '../../features/settings/presentation/pages/settings_home_page.dart';
import '../../features/search/presentation/pages/global_search_page.dart';
import '../../features/settings/presentation/pages/user_management_page.dart';
import 'app_shell.dart';
import 'auth_redirect_policy.dart';
import 'auth_session.dart';
import 'forbidden_page.dart';
import 'not_found_page.dart';
import 'permissions_snapshot.dart';
import 'route_access.dart';
import 'route_paths.dart';

/// Owns the app's [GoRouter] instance and wires both [AuthSession] and
/// [PermissionsSnapshot] in as the `refreshListenable`, so a sign-in/out
/// OR a permission-set change instantly re-evaluates the guard.
///
/// **Route topology** (Slice 2.1.1):
/// - Top-level (no nav chrome): `/splash`, `/login`, `/mfa/otp` — pre-auth
///   takeovers.
/// - [StatefulShellRoute.indexedStack] hosting three sibling branches:
///   - **Home** branch: `/dashboard`, `/admin-demo`, `/forbidden`,
///     `/notifications`, `/search`.
///   - **Modules** branch: `/modules`.
///   - **Settings** branch: `/settings` + sub-pages.
///
/// Note: the Finance / Procurement / Inventory / Sales / HR / Projects
/// modules were removed; their routes are gone with them.
///
/// The redirect rules live in [resolveAuthRedirect] (pure Dart) so they
/// can be unit-tested without Flutter. Permission lookups go through
/// [RouteAccess] (the location → required Permission table) and
/// [PermissionsSnapshot.holds] (the in-memory mirror of drift).
@lazySingleton
class AppRouter {
  AppRouter(AuthSession session, PermissionsSnapshot permissions)
      : config = _build(session, permissions);

  final GoRouter config;

  /// Slice 10.2.9 — handle on the root navigator GoRouter creates, so
  /// widgets that live OUTSIDE the router subtree (e.g. the
  /// `IncomingCallOverlay` mounted via `MaterialApp.builder`) can push
  /// full-screen routes without depending on `Navigator.of(context)`.
  static final GlobalKey<NavigatorState> rootNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'rootNavigator');

  static GoRouter _build(
    AuthSession session,
    PermissionsSnapshot permissions,
  ) =>
      GoRouter(
        navigatorKey: rootNavigatorKey,
        initialLocation: RoutePaths.splash,
        debugLogDiagnostics: kDebugMode,
        // Either signal triggers a redirect re-evaluation. Listenable.merge
        // keeps both subscriptions live for the router's lifetime; both
        // are app-scoped singletons so there's no leak risk on dispose.
        refreshListenable: Listenable.merge([session, permissions]),
        redirect: (context, state) {
          final required =
              RouteAccess.requiredFor(state.matchedLocation);
          final hasAccess =
              required == null || permissions.holds(required);
          return resolveAuthRedirect(
            matchedLocation: state.matchedLocation,
            isAuthenticated: session.isAuthenticated,
            hasRouteAccess: hasAccess,
          );
        },
        errorBuilder: (context, state) =>
            NotFoundPage(location: state.matchedLocation),
        routes: [
          // ── Pre-auth takeovers (no shell chrome) ─────────────────
          GoRoute(
            path: RoutePaths.splash,
            name: RoutePaths.splashName,
            builder: (_, __) => const SplashPage(),
          ),
          GoRoute(
            path: RoutePaths.login,
            name: RoutePaths.loginName,
            builder: (_, __) => LoginPage(
              // Placeholder wiring until the real AuthBloc lands: flipping
              // the stub auth session emits a listener notification, which
              // GoRouter picks up via `refreshListenable` and bounces to
              // /dashboard via the redirect policy. No `context.go` here.
              onSimulatedLogin: () async {
                // Slice 3.2.4 — write the demo user + finance.approve
                // permission BEFORE flipping the auth flag so the
                // permissions snapshot has a current user by the time
                // the redirect bounces us into the dashboard.
                await getIt<DemoSignInService>().seed();
                if (session is StubAuthSession) {
                  session.simulateSignIn();
                }
              },
            ),
          ),
          GoRoute(
            path: RoutePaths.otp,
            name: RoutePaths.otpName,
            builder: (_, __) => const OtpEntryPage(),
          ),
          GoRoute(
            path: RoutePaths.biometricUnlock,
            name: RoutePaths.biometricUnlockName,
            builder: (_, __) => const BiometricUnlockPage(),
          ),
          GoRoute(
            path: RoutePaths.forgotPassword,
            name: RoutePaths.forgotPasswordName,
            builder: (_, __) => const ForgotPasswordPage(),
          ),

          // ── Authenticated shell (bottom nav / rail / drawer) ─────
          StatefulShellRoute.indexedStack(
            builder: (context, state, navigationShell) =>
                AppShell(navigationShell: navigationShell),
            branches: [
              // Branch 0 — Home / Dashboard. Hosts /admin-demo and
              // /forbidden so they keep the chrome and the user can
              // recover via bottom nav after a permission bounce.
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: RoutePaths.dashboard,
                    name: RoutePaths.dashboardName,
                    builder: (_, __) => const DashboardPage(),
                  ),
                  GoRoute(
                    path: RoutePaths.adminDemo,
                    name: RoutePaths.adminDemoName,
                    builder: (_, __) => const AdminDemoPage(),
                  ),
                  GoRoute(
                    path: RoutePaths.forbidden,
                    name: RoutePaths.forbiddenName,
                    builder: (_, state) => ForbiddenPage(
                      attemptedLocation: state.uri.queryParameters['from'],
                    ),
                  ),
                  GoRoute(
                    path: RoutePaths.notificationInbox,
                    name: RoutePaths.notificationInboxName,
                    builder: (_, __) => const NotificationInboxPage(),
                  ),
                  GoRoute(
                    path: RoutePaths.search,
                    name: RoutePaths.searchName,
                    builder: (_, __) => const GlobalSearchPage(),
                  ),
                ],
              ),
              // Branch 1 — Modules. Hosts the permission-filtered shortcut
              // grid (Slice 2.1.2) and the shared `/coming-soon/:label`
              // landing for tiles whose feature module hasn't shipped.
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: RoutePaths.modules,
                    name: RoutePaths.modulesName,
                    builder: (_, __) => const ModulesPage(),
                  ),
                  GoRoute(
                    path: RoutePaths.comingSoon,
                    name: RoutePaths.comingSoonName,
                    builder: (_, state) => ComingSoonPage(
                      moduleLabel: state.pathParameters[
                              RoutePaths.comingSoonLabelParam] ??
                          '',
                    ),
                  ),
                ],
              ),
              // Branch 2 — Settings (Module 9). Hosts the settings hub
              // and all 9 sub-pages so they all live under the Settings
              // shell branch and the bottom nav stays on Settings while
              // the user drills down.
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: RoutePaths.settings,
                    name: RoutePaths.settingsName,
                    builder: (_, __) => SettingsHomePage(
                      // Full sign-out via AuthRepository — revokes the
                      // refresh token server-side, clears
                      // flutter_secure_storage, wipes the cached user from
                      // drift, then SessionSignal.invalidate() flips the
                      // AuthSession bool and the router bounces to /login.
                      onSignOut: () => getIt<AuthRepository>().signOut(),
                    ),
                  ),
                  // Phase 9.1 — preferences.
                  GoRoute(
                    path: RoutePaths.settingsAppearance,
                    name: RoutePaths.settingsAppearanceName,
                    builder: (_, __) => const AppearancePage(),
                  ),
                  GoRoute(
                    path: RoutePaths.settingsLanguage,
                    name: RoutePaths.settingsLanguageName,
                    builder: (_, __) => const LanguagePage(),
                  ),
                  GoRoute(
                    path: RoutePaths.settingsNotifications,
                    name: RoutePaths.settingsNotificationsName,
                    builder: (_, __) => const NotificationPreferencesPage(),
                  ),
                  // Phase 9.2 — admin.
                  GoRoute(
                    path: RoutePaths.settingsUsers,
                    name: RoutePaths.settingsUsersName,
                    builder: (_, __) => const UserManagementPage(),
                  ),
                  GoRoute(
                    path: RoutePaths.settingsRoles,
                    name: RoutePaths.settingsRolesName,
                    builder: (_, __) => const RoleEditorPage(),
                  ),
                  GoRoute(
                    path: RoutePaths.settingsAssignments,
                    name: RoutePaths.settingsAssignmentsName,
                    builder: (_, __) => const AssignmentsPage(),
                  ),
                  GoRoute(
                    path: RoutePaths.settingsApiConfig,
                    name: RoutePaths.settingsApiConfigName,
                    builder: (_, __) => const ApiConfigPage(),
                  ),
                  // Phase 9.3 — security.
                  GoRoute(
                    path: RoutePaths.settingsSessions,
                    name: RoutePaths.settingsSessionsName,
                    builder: (_, __) => const SessionsPage(),
                  ),
                  GoRoute(
                    path: RoutePaths.settingsAuditLog,
                    name: RoutePaths.settingsAuditLogName,
                    builder: (_, __) => const AuditLogPage(),
                  ),
                  GoRoute(
                    path: RoutePaths.settingsAppLock,
                    name: RoutePaths.settingsAppLockName,
                    builder: (_, __) => const AppLockPage(),
                  ),
                ],
              ),
            ],
          ),
        ],
      );
}
