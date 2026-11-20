import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';

import '../model/call_config.dart';
import '../model/stream_token_model.dart';

/// MY link to the media call (Step 6.3b).
enum MediaLink {
  /// Sound flows.
  connected,

  /// My network dropped; Stream is trying again ("Reconnecting…").
  reconnecting,

  /// Stream gave up.
  lost,
}

/// What [CallMedia.join] got: which tracks really started.
typedef MediaJoin = ({bool ok, bool micOn, bool cameraOn});

/// The SOUND and PICTURE of a call (Step 6.2) — the only class that talks
/// to the Stream Video SDK (plus `CallVideoView`, which draws its video).
///
/// ```
/// join(cid, video)   token (our server) → StreamVideo client → ask mic / camera
///                    → makeCall(type, id) → call.join(...)
/// peerPresent        true while someone else is in the media call
/// setMicrophone · setCamera · flipCamera · setSpeaker
/// leave()            every end path calls it (safe to call twice)
/// ```
///
/// Signalling (who rings, who accepted, who hung up) is NOT here: that's our
/// backend, in `CallRepository`. Stream only carries the media.
class CallMedia {
  CallMedia({required Future<StreamTokenModel?> Function() loadToken})
    : _loadToken = loadToken;

  final Future<StreamTokenModel?> Function() _loadToken;

  StreamVideo? _client;
  String? _clientUserId;
  StreamSubscription<bool>? _stateSub;
  StreamSubscription<MediaLink>? _linkSub;
  final _peer = StreamController<bool>.broadcast();
  final _link = StreamController<MediaLink>.broadcast();

  /// Bumped by [leave]: a join that finishes after it must not stay.
  int _generation = 0;

  /// The joined Stream call (null when none) — `CallVideoView` draws it.
  final ValueNotifier<Call?> call = ValueNotifier(null);

  /// true when someone else is in the media call, false when they left.
  Stream<bool> get peerPresent => _peer.stream;

  /// MY connection to the media call: connected · reconnecting · lost.
  Stream<MediaLink> get link => _link.stream;

  /// Stream's call status → our 3 words. Other statuses (joining, idle…)
  /// → null (not interesting during a call).
  @visibleForTesting
  static MediaLink? linkOf(CallStatus status) {
    if (status is CallStatusReconnectionFailed) return MediaLink.lost;
    if (status.isReconnecting || status.isMigrating) {
      return MediaLink.reconnecting;
    }
    if (status.isConnected || status.isJoined) return MediaLink.connected;
    return null;
  }

  /// Joins the Stream call `type:id` ([cid] = `ChatCallDto.streamCallCid`).
  /// Never throws: anything wrong → `ok: false`.
  Future<MediaJoin> join({required String cid, required bool video}) async {
    const failed = (ok: false, micOn: false, cameraOn: false);
    final generation = ++_generation;
    try {
      final token = await _loadToken();
      if (token == null || !token.isUsable) return failed;
      final client = await _clientFor(token);

      // CallPermissionGate already asked (at 📞 / Accept). Only CHECK here:
      // a "no" turns that track off instead of failing the whole join.
      final micOn = await Permission.microphone.isGranted;
      final cameraOn = video && await Permission.camera.isGranted;
      if (generation != _generation) return failed; // hung up meanwhile

      final sep = cid.indexOf(':');
      final c = client.makeCall(
        callType: StreamCallType.fromString(
          sep > 0 ? cid.substring(0, sep) : 'default',
        ),
        id: sep > 0 ? cid.substring(sep + 1) : cid,
      );
      final result = await c.join(
        connectOptions: CallConnectOptions(
          microphone: micOn ? TrackOption.enabled() : TrackOption.disabled(),
          camera: cameraOn ? TrackOption.enabled() : TrackOption.disabled(),
          speakerDefaultOn: video, // video → loudspeaker, voice → earpiece
        ),
      );
      if (result.isFailure || generation != _generation) {
        await c.leave();
        return failed;
      }

      call.value = c;
      _stateSub = c.state.valueStream
          .map((s) => s.otherParticipants.isNotEmpty)
          .distinct()
          .listen(_peer.add);
      _linkSub = c.state.valueStream
          .map((s) => linkOf(s.status))
          .where((l) => l != null)
          .cast<MediaLink>()
          .distinct()
          .listen(_link.add);
      return (ok: true, micOn: micOn, cameraOn: cameraOn);
    } catch (e) {
      debugPrint('[CallMedia] join failed: $e');
      return failed;
    }
  }

  /// One client per user. A different user (logout → login) → a new one.
  Future<StreamVideo> _clientFor(StreamTokenModel token) async {
    final current = _client;
    if (current != null && _clientUserId == token.userId) return current;
    await StreamVideo.reset(disconnect: true); // the SDK keeps a singleton
    final client = StreamVideo(
      token.apiKey,
      user: User.regular(userId: token.userId),
      userToken: token.token,
      // Stream asks again when the token expires (calls can be long).
      tokenLoader: (_) async => (await _loadToken())?.token ?? '',
      failIfSingletonExists: false,
      // Give up after 30 s without network (Stream's default: forever),
      // so "Reconnecting…" can't hang (Step 6.3b).
      options: StreamVideoOptions(
        defaultCallPreferences: DefaultCallPreferences(
          reconnectTimeout: CallConfig.reconnectTimeout,
          networkAvailabilityTimeout: CallConfig.reconnectTimeout,
        ),
      ),
    );
    _client = client;
    _clientUserId = token.userId;
    return client;
  }

  Future<bool> setMicrophone(bool on) async {
    final c = call.value;
    if (c == null) return false;
    if (on && !await Permission.microphone.request().isGranted) return false;
    return (await c.setMicrophoneEnabled(enabled: on)).isSuccess;
  }

  Future<bool> setCamera(bool on) async {
    final c = call.value;
    if (c == null) return false;
    if (on && !await Permission.camera.request().isGranted) return false;
    return (await c.setCameraEnabled(enabled: on)).isSuccess;
  }

  Future<bool> flipCamera() async {
    final c = call.value;
    if (c == null) return false;
    return (await c.flipCamera()).isSuccess;
  }

  /// Loudspeaker on / off (off = the earpiece, or the headset when one is
  /// plugged in — the phone decides).
  Future<bool> setSpeaker(bool on) async {
    final c = call.value;
    if (c == null) return false;
    final outputs =
        (await RtcMediaDeviceNotifier.instance.audioOutputs())
            .getDataOrNull() ??
        const <RtcMediaDevice>[];
    var device = outputs.firstWhereOrNull(
      (d) => d.id.toLowerCase() == (on ? 'speaker' : 'earpiece'),
    );
    // iOS doesn't list the earpiece; Stream accepts this id anyway.
    if (device == null && !on && defaultTargetPlatform == TargetPlatform.iOS) {
      device = const RtcMediaDevice(
        id: 'earpiece',
        label: 'Earpiece',
        kind: RtcMediaDeviceKind.audioOutput,
      );
    }
    if (device == null) return false;
    return (await c.setAudioOutputDevice(device)).isSuccess;
  }

  /// Leaves the media call. Safe to call when nothing is joined.
  Future<void> leave() async {
    _generation++;
    await _stateSub?.cancel();
    _stateSub = null;
    await _linkSub?.cancel();
    _linkSub = null;
    final c = call.value;
    call.value = null;
    if (c != null) {
      try {
        await c.leave();
      } catch (_) {
        // the call is over for us anyway
      }
    }
  }

  /// Logout → forget the Stream user.
  Future<void> signOut() async {
    await leave();
    _client = null;
    _clientUserId = null;
    try {
      await StreamVideo.reset(disconnect: true);
    } catch (_) {}
  }
}
