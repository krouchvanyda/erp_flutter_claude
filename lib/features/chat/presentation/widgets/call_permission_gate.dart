import 'package:permission_handler/permission_handler.dart';

/// Ensures the permissions a call needs are granted before the call is placed
/// or accepted — on **both iOS and Android**. Returns `true` when every needed
/// permission is granted.
///
/// Uses the **native** permission prompt (`request()`):
///   * already granted → proceed
///   * not yet asked / denied-once → the native system Allow / Don't Allow
///     dialog appears (this is what gives an Android user who tapped "Don't
///     Allow" on first launch a second chance when a call comes in)
///   * permanently denied → no re-prompt (the user re-enables it from Settings);
///     we just report the current grant state
///
/// Result is **advisory** — the call pages place/accept the call regardless; a
/// denial just transmits no audio/video and the in-call UI reflects it.
Future<bool> ensureCallPermissions({bool needCamera = false}) async {
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
