import 'package:permission_handler/permission_handler.dart';

/// Requests the permissions a call needs BEFORE the call is placed, so the
/// native system prompt appears up front (the moment the call page opens)
/// instead of mid-call when WebRTC first touches the camera/mic.
///
/// Returns `true` when every needed permission is granted. The result is
/// **advisory** — the call pages place the call regardless (a denial just
/// transmits no audio/video rather than blocking the ring), so this never
/// stops the callee from ringing.
///
/// Runs on **both iOS and Android**. (It used to be iOS-only; Android now
/// also prompts — for a video call that means **camera + mic up front**,
/// which is the requested behaviour.)
///
/// Uses the native permission prompt (`request()`):
///   * already granted        → proceed
///   * denied / not yet asked  → the native system prompt appears
///   * permanently denied      → no re-prompt (the user re-enables it from
///     Settings); we just report the current grant state
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
