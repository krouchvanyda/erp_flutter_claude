import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show appFlavor;

import 'core/config/flavor.dart';
import 'core/theme/app_font_size.dart';
import 'core/theme/app_label.dart';
import 'core/theme/app_spacing.dart';
import 'core/theme/app_theme.dart';

/// Plain `flutter run`: flavor comes from `--flavor` (dev when none).
Future<void> main() => bootstrap(Flavor.current);

/// Shared start-up for every entry point (main_dev / main_uat / main_prod).
Future<void> bootstrap(Flavor flavor) async {
  // Debug-only guard: `--flavor` (native side) and the entry point (Dart
  // side) must agree, e.g. `--flavor dev -t lib/main_prod.dart` is a bug.
  // `appFlavor == null` is fine: no `--flavor` given, the entry point wins.
  assert(
    appFlavor == null || appFlavor == flavor.name,
    'Flavor mismatch: --flavor $appFlavor but entry point is ${flavor.name}',
  );
  Flavor.pin(flavor);
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HelloApp());
}

/// Temporary demo screen — replaced by the router + splash in Step 1.4.
/// It only shows the theme tokens working in light and dark mode.
class HelloApp extends StatefulWidget {
  const HelloApp({super.key});

  @override
  State<HelloApp> createState() => _HelloAppState();
}

class _HelloAppState extends State<HelloApp> {
  // Local UI state is OK for this throwaway demo. Real theme switching
  // will live in a Cubit (Step 4/8) and be saved in shared_preferences.
  ThemeMode _mode = ThemeMode.light;

  void _toggle() => setState(() {
        _mode = _mode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
      });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: Flavor.current.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _mode,
      home: _ThemePreviewPage(onToggle: _toggle),
    );
  }
}

class _ThemePreviewPage extends StatelessWidget {
  const _ThemePreviewPage({required this.onToggle});

  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
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
            onPressed: onToggle,
            icon: Icon(
              theme.brightness == Brightness.light
                  ? Icons.dark_mode_outlined
                  : Icons.light_mode_outlined,
            ),
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
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: const Column(
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
          ),
          const SizedBox(height: AppSpacing.md),
          const TextField(
            decoration: InputDecoration(
              hintText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: () {},
            child: const AppLabel(
              text: 'Sign in',
              fontSize: AppFontSize.value14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(
            onPressed: () {},
            child: const AppLabel(
              text: 'Use biometrics',
              fontSize: AppFontSize.value14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
