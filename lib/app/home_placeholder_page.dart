import 'package:flutter/material.dart';

import '../core/config/flavor.dart';
import '../core/network/api_endpoints.dart';
import '../core/network/app_service.dart';
import '../core/network/helper_service.dart';
import '../core/network/network_error_model.dart';
import '../core/router/config_router.dart';
import '../core/theme/app_font_size.dart';
import '../core/theme/app_label.dart';
import '../core/theme/app_spacing.dart';

/// Temporary page after login (Step 5 replaces it with the chat inbox).
/// Also keeps the theme preview from Step 1.2.
class HomePlaceholderPage extends StatelessWidget {
  const HomePlaceholderPage({
    super.key,
    required this.onLogout,
    required this.appService,
  });

  /// `AuthRepository.logout` (Step 3.2): server revoke → clear tokens →
  /// close the session → AuthGate shows Login.
  final Future<void> Function() onLogout;
  final AppService appService;

  /// Step 2.1 demo: GET /health through AppService, show the result.
  /// (Real screens do this in a BLoC → Repository, from Step 3.)
  Future<void> _checkServer(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context); // read BEFORE the await
    final result = await appService.send<String>(
      httpMethods: HttpMethods.get,
      endPoint: ApiEndPoint.health,
      parse: (data) => (data as Map<String, dynamic>)['status'] as String,
    );
    final text = result.fold(
      (error) => switch (error) {
        ServerError(:final statusCode) =>
          '❌ $statusCode ${error.title}: '
              '${error.description}',
        NoInternetError() ||
        UnauthorizedError() ||
        UnknownError() => '❌ ${error.title}: ${error.description}',
      },
      (status) => '✅ Server is $status',
    );
    messenger.showSnackBar(SnackBar(content: Text(text)));
  }

  /// Step 2.2 demo: GET /users/me needs a token. After a real login (or an
  /// auto-login) the AuthInterceptor adds it → "Signed in as …".
  Future<void> _callMe(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context); // read BEFORE the await
    final result = await appService.send<String>(
      httpMethods: HttpMethods.get,
      endPoint: ApiEndPoint.me,
      parse: (data) => (data as Map<String, dynamic>)['email'] as String,
    );
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          result.fold(
            (error) =>
                '❌ ${error.statusCode} ${error.title}: '
                '${error.description}',
            (email) => '✅ Signed in as $email',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final flavor = Flavor.current;

    return Scaffold(
      appBar: AppBar(
        title: AppLabel(
          text: flavor.appName,
          fontSize: AppFontSize.value20,
          fontWeight: FontWeight.w600,
        ),
        actions: [
          IconButton(
            tooltip: 'Log out',
            onPressed: () => confirmLogout(context, onLogout),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const AppLabel(
            text: 'Welcome back',
            fontSize: AppFontSize.value24,
            fontWeight: FontWeight.w700,
          ),
          AppLabel(
            text: flavor.apiBaseUrl,
            fontSize: AppFontSize.value14,
            color: colors.onSurfaceVariant,
          ),
          const SizedBox(height: AppSpacing.lg),
          const _DemoCard(),
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton(
            onPressed: () => _checkServer(context),
            child: const AppLabel(
              text: 'Check server (GET /health)',
              fontSize: AppFontSize.value14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(
            onPressed: () => _callMe(context),
            child: const AppLabel(
              text: 'Call GET /users/me (needs a token)',
              fontSize: AppFontSize.value14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            // ConfigRouter demo: slide right → left.
            onPressed: () => ConfigRouter.pushPageAnimation(
              context,
              _DemoDetailPage(onLogout: onLogout),
            ),
            child: const AppLabel(
              text: 'Open detail (ConfigRouter)',
              fontSize: AppFontSize.value14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DemoCard extends StatelessWidget {
  const _DemoCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppLabel(
              text: 'Card title',
              fontSize: AppFontSize.value16,
              fontWeight: FontWeight.w600,
            ),
            SizedBox(height: AppSpacing.xs),
            AppLabel(
              text: 'សួស្តី — Khmer uses the fallback font.',
              fontSize: AppFontSize.value14,
            ),
          ],
        ),
      ),
    );
  }
}

/// A pushed page — shows that logout from here also closes it
/// (AuthGate pops everything back to the first route).
class _DemoDetailPage extends StatelessWidget {
  const _DemoDetailPage({required this.onLogout});

  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const AppLabel(
          text: 'Detail',
          fontSize: AppFontSize.value20,
          fontWeight: FontWeight.w600,
        ),
        actions: [
          IconButton(
            tooltip: 'Log out',
            onPressed: () => confirmLogout(context, onLogout),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: const Center(
        child: AppLabel(
          text: 'Pushed with ConfigRouter.pushPageAnimation',
          fontSize: AppFontSize.value14,
        ),
      ),
    );
  }
}

/// "Log out?" → Cancel / Log out. Only on "Log out" do we call [onLogout].
/// A mistake tap must not throw the user out (design guide: destructive
/// actions ask first).
Future<void> confirmLogout(
  BuildContext context,
  Future<void> Function() onLogout,
) async {
  final yes = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const AppLabel(
        text: 'Log out?',
        fontSize: AppFontSize.value20,
        fontWeight: FontWeight.w600,
      ),
      content: const AppLabel(
        text: 'You will need to sign in again.',
        fontSize: AppFontSize.value14,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const AppLabel(text: 'Cancel', fontSize: AppFontSize.value14),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const AppLabel(
            text: 'Log out',
            fontSize: AppFontSize.value14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
  if (yes == true) await onLogout();
}
