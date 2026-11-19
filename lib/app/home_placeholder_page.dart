import 'package:flutter/material.dart';

import '../core/config/flavor.dart';
import '../core/network/api_endpoints.dart';
import '../core/network/app_service.dart';
import '../core/network/helper_service.dart';
import '../core/network/network_error_model.dart';
import '../core/router/auth_session.dart';
import '../core/router/config_router.dart';
import '../core/theme/app_font_size.dart';
import '../core/theme/app_label.dart';
import '../core/theme/app_spacing.dart';

/// Temporary page after login (Step 5 replaces it with the chat inbox).
/// Also keeps the theme preview from Step 1.2.
class HomePlaceholderPage extends StatelessWidget {
  const HomePlaceholderPage({
    super.key,
    required this.session,
    required this.appService,
  });

  final AuthSession session;
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
            // Flip the session; AuthGate swaps Home → Login.
            onPressed: session.markLoggedOut,
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
          FilledButton(
            // ConfigRouter demo: slide right → left.
            onPressed: () => ConfigRouter.pushPageAnimation(
              context,
              _DemoDetailPage(session: session),
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
  const _DemoDetailPage({required this.session});

  final AuthSession session;

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
            onPressed: session.markLoggedOut,
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
