import 'dart:io' show Platform;

import 'package:permission_handler/permission_handler.dart';

/// Ensures the permissions a call needs are granted before the call is placed.
/// Returns `true` when the call may proceed.
///
/// **iOS-only** — on Android this returns `true` immediately so the existing
/// (working) Android call flow is completely unchanged.
///
/// Uses the **native** iOS permission prompt (`request()`) — the same
/// Allow / Don't Allow dialog iOS shows for notifications. No custom dialog:
///   * already granted → proceed
///   * not yet asked → the native system prompt appears
///   * denied → returns `false` and the caller simply doesn't open the call
///     (iOS won't re-show the native prompt once denied; the user re-enables
///     it from Settings)
Future<bool> ensureCallPermissions({bool needCamera = false}) async {
  if (!Platform.isIOS) return true; // Android flow unaffected.

  Future<bool> ensure(Permission permission) async {
    var status = await permission.status;
    if (status.isGranted) return true;
    if (status.isDenied) status = await permission.request(); // native prompt
    return status.isGranted;
  }

  final micOk = await ensure(Permission.microphone);
  final camOk = needCamera ? await ensure(Permission.camera) : true;
  return micOk && camOk;
}

/// Whether the OS currently grants the microphone. Used by the in-call UI to
/// reflect a "Don't Allow" choice: the mic track is already disabled at join
/// when permission is denied, but the mute button defaults to "unmuted", so the
/// callee saw an active mic ("looks like allowed"). Lets the page show it muted.
Future<bool> isMicrophoneGranted() => Permission.microphone.isGranted;

/// Camera equivalent for the video call page (denied camera → show camera off).
Future<bool> isCameraGranted() => Permission.camera.isGranted;
