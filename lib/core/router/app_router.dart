import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:erp_mobile/features/authentication/views/biometric_unlock_screen.dart';
import 'package:erp_mobile/features/authentication/views/forgot_password_screen.dart';
import 'package:erp_mobile/features/authentication/views/login_screen.dart';
import 'package:erp_mobile/features/authentication/views/otp_entry_screen.dart';
import 'package:erp_mobile/features/authentication/views/splash_screen.dart';
import 'package:erp_mobile/features/dashboard/views/admin_demo_screen.dart';
import 'package:erp_mobile/features/dashboard/views/coming_soon_screen.dart';
import 'package:erp_mobile/features/dashboard/views/dashboard_screen.dart';
import 'package:erp_mobile/features/dashboard/views/modules_screen.dart';
import 'package:erp_mobile/core/di/app_dependencies.dart';
import 'package:erp_mobile/features/notifications/views/notification_inbox_screen.dart';
import 'package:erp_mobile/features/settings/views/api_config_screen.dart';
import 'package:erp_mobile/features/settings/views/app_lock_screen.dart';
import 'package:erp_mobile/features/settings/views/appearance_screen.dart';
import 'package:erp_mobile/features/settings/views/assignments_screen.dart';
import 'package:erp_mobile/features/settings/views/audit_log_screen.dart';
import 'package:erp_mobile/features/settings/views/language_screen.dart';
import 'package:erp_mobile/features/settings/views/notification_preferences_screen.dart';
import 'package:erp_mobile/features/settings/views/role_editor_screen.dart';
import 'package:erp_mobile/features/settings/views/sessions_screen.dart';
import 'package:erp_mobile/features/settings/views/settings_home_screen.dart';
import 'package:erp_mobile/features/search/views/global_search_screen.dart';
import 'package:erp_mobile/features/settings/views/user_management_screen.dart';
import 'package:erp_mobile/core/router/app_shell.dart';
import 'package:erp_mobile/core/router/auth_redirect_policy.dart';
import 'package:erp_mobile/core/router/auth_session.dart';
import 'package:erp_mobile/core/router/forbidden_page.dart';
import 'package:erp_mobile/core/router/not_found_page.dart';
import 'package:erp_mobile/core/router/permissions_snapshot.dart';
import 'package:erp_mobile/core/router/route_access.dart';
import 'package:erp_mobile/core/router/route_paths.dart';

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
            builder: (_, __) => const SplashScreen(),
          ),
          GoRoute(
            path: RoutePaths.login,
            name: RoutePaths.loginName,
            builder: (_, __) => LoginScreen(
              // Placeholder wiring until the real AuthBloc lands: flipping
              // the stub auth session emits a listener notification, which
              // GoRouter picks up via `refreshListenable` and bounces to
              // /dashboard via the redirect policy. No `context.go` here.
              onSimulatedLogin: () async {
                // Slice 3.2.4 — write the demo user + finance.approve
                // permission BEFORE flipping the auth flag so the
                // permissions snapshot has a current user by the time
                // the redirect bounces us into the dashboard.
                await AppDependencies.I.demoSignInService.seed();
                if (session is StubAuthSession) {
                  session.simulateSignIn();
                }
              },
            ),
          ),
          GoRoute(
            path: RoutePaths.otp,
            name: RoutePaths.otpName,
            builder: (_, __) => const OtpEntryScreen(),
          ),
          GoRoute(
            path: RoutePaths.biometricUnlock,
            name: RoutePaths.biometricUnlockName,
            builder: (_, __) => const BiometricUnlockScreen(),
          ),
          GoRoute(
            path: RoutePaths.forgotPassword,
            name: RoutePaths.forgotPasswordName,
            builder: (_, __) => const ForgotPasswordScreen(),
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
                    builder: (_, __) => const DashboardScreen(),
                  ),
                  GoRoute(
                    path: RoutePaths.adminDemo,
                    name: RoutePaths.adminDemoName,
                    builder: (_, __) => const AdminDemoScreen(),
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
                    builder: (_, __) => const NotificationInboxScreen(),
                  ),
                  GoRoute(
                    path: RoutePaths.search,
                    name: RoutePaths.searchName,
                    builder: (_, __) => const GlobalSearchScreen(),
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
                    builder: (_, __) => const ModulesScreen(),
                  ),
                  GoRoute(
                    path: RoutePaths.comingSoon,
                    name: RoutePaths.comingSoonName,
                    builder: (_, state) => ComingSoonScreen(
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
                    builder: (_, __) => SettingsHomeScreen(
                      // Full sign-out via AuthRepository — revokes the
                      // refresh token server-side, clears
                      // flutter_secure_storage, wipes the cached user from
                      // drift, then SessionSignal.invalidate() flips the
                      // AuthSession bool and the router bounces to /login.
                      onSignOut: () => AppDependencies.I.authRepository.signOut(),
                    ),
                  ),
                  // Phase 9.1 — preferences.
                  GoRoute(
                    path: RoutePaths.settingsAppearance,
                    name: RoutePaths.settingsAppearanceName,
                    builder: (_, __) => const AppearanceScreen(),
                  ),
                  GoRoute(
                    path: RoutePaths.settingsLanguage,
                    name: RoutePaths.settingsLanguageName,
                    builder: (_, __) => const LanguageScreen(),
                  ),
                  GoRoute(
                    path: RoutePaths.settingsNotifications,
                    name: RoutePaths.settingsNotificationsName,
                    builder: (_, __) => const NotificationPreferencesScreen(),
                  ),
                  // Phase 9.2 — admin.
                  GoRoute(
                    path: RoutePaths.settingsUsers,
                    name: RoutePaths.settingsUsersName,
                    builder: (_, __) => const UserManagementScreen(),
                  ),
                  GoRoute(
                    path: RoutePaths.settingsRoles,
                    name: RoutePaths.settingsRolesName,
                    builder: (_, __) => const RoleEditorScreen(),
                  ),
                  GoRoute(
                    path: RoutePaths.settingsAssignments,
                    name: RoutePaths.settingsAssignmentsName,
                    builder: (_, __) => const AssignmentsScreen(),
                  ),
                  GoRoute(
                    path: RoutePaths.settingsApiConfig,
                    name: RoutePaths.settingsApiConfigName,
                    builder: (_, __) => const ApiConfigScreen(),
                  ),
                  // Phase 9.3 — security.
                  GoRoute(
                    path: RoutePaths.settingsSessions,
                    name: RoutePaths.settingsSessionsName,
                    builder: (_, __) => const SessionsScreen(),
                  ),
                  GoRoute(
                    path: RoutePaths.settingsAuditLog,
                    name: RoutePaths.settingsAuditLogName,
                    builder: (_, __) => const AuditLogScreen(),
                  ),
                  GoRoute(
                    path: RoutePaths.settingsAppLock,
                    name: RoutePaths.settingsAppLockName,
                    builder: (_, __) => const AppLockScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      );
}
