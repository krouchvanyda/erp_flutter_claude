import 'package:flutter/material.dart';

import '../../../core/widgets/app_confirm_dialog.dart';

/// The ⎋ icon at the top right of the profile AppBar.
///
/// Asks first ([AppConfirmDialog]), then calls [onLogout]
/// (`AuthRepository.logout`, passed in by the app layer — the profile
/// feature doesn't know the auth repository). While it runs (up to ~5 s if
/// the server is slow) the icon becomes a small spinner and ignores taps.
class ProfileLogoutButton extends StatefulWidget {
  const ProfileLogoutButton({super.key, required this.onLogout});

  final Future<void> Function() onLogout;

  @override
  State<ProfileLogoutButton> createState() => _ProfileLogoutButtonState();
}

class _ProfileLogoutButtonState extends State<ProfileLogoutButton> {
  /// UI-only state: is logout running?
  bool _busy = false;

  Future<void> _tap() async {
    final yes = await AppConfirmDialog.show(
      context,
      icon: Icons.logout_rounded,
      title: 'Log out?',
      message: 'You will need to sign in again.',
      confirmText: 'Log out',
      destructive: true,
    );
    if (!yes || !mounted) return;
    setState(() => _busy = true);
    await widget.onLogout(); // AuthGate closes this page when it's done
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: 'Log out',
      onPressed: _busy ? null : _tap,
      color: colors.error, // red = "careful"
      icon: _busy
          ? SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.error,
              ),
            )
          : const Icon(Icons.logout_rounded),
    );
  }
}
