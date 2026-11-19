import 'package:flutter/material.dart';

import '../../../core/config/flavor.dart';
import '../../../core/router/auth_session.dart';
import '../../../core/theme/app_font_size.dart';
import '../../../core/theme/app_label.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';

/// Screen 0.1 — logo + name + small spinner, then decide where to go.
///
/// The ONLY place that decides "auto-login or not" (CLAUDE.md).
/// Now: session is always false on a cold start → AuthGate shows Login.
/// Step 3: read tokens from secure storage → markAuthenticated() → Home.
///
/// The splash does NOT navigate: it updates the session, then calls
/// [onFinished], and `AuthGate` picks the next screen.
class SplashPage extends StatefulWidget {
  const SplashPage({
    super.key,
    required this.session,
    required this.onFinished,
  });

  final AuthSession session;
  final VoidCallback onFinished;

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  // Design guide: logo fade + scale, 900ms, easeOutBack.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  late final Animation<double> _scale = Tween<double>(
    begin: 0.8,
    end: 1,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

  @override
  void initState() {
    super.initState();
    _decide();
  }

  Future<void> _decide() async {
    // Let the logo animation play. Step 3 does the token check here instead.
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    // Step 3 here: tokens found → widget.session.markAuthenticated();
    if (!mounted) return; // the page may be gone after the await
    widget.onFinished();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: FadeTransition(
                opacity: _controller,
                child: ScaleTransition(
                  scale: _scale,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: colors.primary,
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                        ),
                        child: Icon(
                          Icons.forum_rounded,
                          size: 48,
                          color: colors.onPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppLabel(
                        text: Flavor.current.appName,
                        fontSize: AppFontSize.value32,
                        fontWeight: FontWeight.w700,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.xxl),
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ],
      ),
    );
  }
}
