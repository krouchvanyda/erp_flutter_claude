import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/widgets/app_confirm_dialog.dart';
import '../../../core/widgets/app_snack_bar.dart';

/// Asks for the microphone (+ camera for video) BEFORE a call starts —
/// when I tap 📞 / 🎥, or Accept on an incoming call.
///
/// ```
/// mic granted             → go (camera: asked too for video; "no" = camera off)
/// mic denied              → no call, "Calls need the microphone."
/// mic denied for good     → "Open Settings?" dialog → the phone's settings
/// ```
///
/// Lives in the UI because the system dialog and our own dialog are UI
/// (like picking a photo, 5.5). The bloc never asks.
abstract final class CallPermissionGate {
  static Future<bool> ensure(
    BuildContext context, {
    required bool video,
  }) async {
    final mic = await Permission.microphone.request();
    if (mic.isGranted || mic.isLimited) {
      // The camera is nice to have: a "no" still lets the call go on with
      // the camera off (the other side sees my photo).
      if (video) await Permission.camera.request();
      return true;
    }
    if (!context.mounted) return false;

    if (mic.isPermanentlyDenied || mic.isRestricted) {
      // The phone won't ask again — only Settings can change it.
      final open = await AppConfirmDialog.show(
        context,
        title: 'Allow the microphone',
        message:
            'Calls need the microphone. Turn it on for this app in Settings.',
        confirmText: 'Open Settings',
        icon: Icons.mic_off_rounded,
      );
      if (open) await openAppSettings();
      return false;
    }
    AppSnackBar.warning(context, message: 'Calls need the microphone.');
    return false;
  }
}
