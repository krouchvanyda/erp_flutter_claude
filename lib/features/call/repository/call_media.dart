import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState, WidgetsBinding;
import 'package:permission_handler/permission_handler.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';
import 'package:stream_video_push_notification/stream_video_push_notification.dart';

import '../model/call_config.dart';
import '../model/call_kit_action.dart';
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
///
/// iOS ring (7.3):
/// connectForRinging()  at login: the client + its VoIP token → Stream
/// callKit              CallKit Accept / Decline / End → our call id
/// endRing(callId)      close a CallKit screen we no longer need
/// ```
///
/// Signalling (who rings, who accepted, who hung up) is NOT here: that's our
/// backend, in `CallRepository`. Stream only carries the media — and, on iOS
/// only, the VoIP ring push (Step 7.3). Android rings from OUR FCM (7.2) and
/// must never be registered with Stream, or it would ring twice.
class CallMedia {
  CallMedia({
    required Future<StreamTokenModel?> Function() loadToken,
    bool Function()? onScreen,
  }) : _loadToken = loadToken,
       _onScreen = onScreen ?? _appResumed;

  /// Is the app on screen right now? (a parameter for tests)
  final bool Function() _onScreen;

  static bool _appResumed() =>
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  final Future<StreamTokenModel?> Function() _loadToken;

  StreamVideo? _client;
  String? _clientUserId;
  StreamSubscription<List<String>>? _stateSub;
  StreamSubscription<MediaLink>? _linkSub;
  StreamSubscription<RingingEvent>? _ringSub;
  final _peers = StreamController<List<String>>.broadcast();
  final _link = StreamController<MediaLink>.broadcast();
  final _callKit = StreamController<CallKitAction>.broadcast();

  /// The push provider's name in the Stream dashboard (Push Notifications).
  static const String apnProvider = 'apn';

  /// Only iOS rings through Stream (VoIP push + CallKit).
  static bool get _ringsWithCallKit =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// Bumped by [leave]: a join that finishes after it must not stay.
  int _generation = 0;

  /// The joined Stream call (null when none) — `CallVideoView` draws it.
  final ValueNotifier<Call?> call = ValueNotifier(null);

  /// The OTHER people in the media call right now (user ids, sorted).
  /// Empty = nobody else (yet, or they left). Groups: several (6.3c).
  Stream<List<String>> get peers => _peers.stream;

  /// MY connection to the media call: connected · reconnecting · lost.
  Stream<MediaLink> get link => _link.stream;

  /// iOS: the user pressed Accept / Decline / End on the CallKit screen.
  Stream<CallKitAction> get callKit => _callKit.stream;

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
          .map(
            (s) =>
                {for (final p in s.otherParticipants) p.userId}.toList()
                  ..sort(),
          )
          .distinct(const ListEquality<String>().equals)
          .listen(_peers.add);
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

  /// iOS, after login: make the Stream client NOW (not at the first call),
  /// so it gives Stream this iPhone's VoIP token and CallKit can ring.
  /// Then: a call ANSWERED on CallKit before Dart was ready (a killed app
  /// woken by the push) → reported as Accept, so it isn't lost.
  /// Android: nothing (it rings from our FCM). Never throws.
  Future<void> connectForRinging() async {
    if (!_ringsWithCallKit) return;
    try {
      final token = await _loadToken();
      if (token == null || !token.isUsable) return;
      final client = await _clientFor(token);
      unawaited(_logPushSetup(client, token.userId));
      final calls = await client.pushNotificationManager?.activeCalls();
      for (final c in calls ?? const <CallData>[]) {
        final callId = CallKitAction.callIdOf(c.callCid);
        if (c.isAccepted && callId != null) {
          _callKit.add(CallKitAction(CallKitButton.accept, callId));
        }
      }
    } catch (e) {
      debugPrint('[CallMedia] connectForRinging failed: $e');
    }
  }

  /// DIAGNOSTIC (Xcode console, filter `[CallMedia]`): does Stream have
  /// this iPhone's VoIP token? Waits a few seconds: the SDK registers it
  /// in the background after connecting. Only token TAILS are printed.
  ///
  /// ```
  /// [CallMedia] push · user 12 · VoIP token …a1b2c3 · Stream devices (1):
  /// [CallMedia]   apn "apn" voip=true disabled=false token …a1b2c3 ✅ this iPhone
  /// ```
  Future<void> _logPushSetup(StreamVideo client, String userId) async {
    await Future<void>.delayed(const Duration(seconds: 5));
    try {
      String tail(String? t) =>
          t == null || t.length < 6 ? '(none)' : '…${t.substring(t.length - 6)}';
      final voip = await client.pushNotificationManager
          ?.getDevicePushTokenVoIP();
      final devices =
          (await client.getDevices()).getDataOrNull() ?? const <PushDevice>[];
      debugPrint(
        '[CallMedia] push · user $userId · VoIP token ${tail(voip)} · '
        'Stream devices (${devices.length}):',
      );
      for (final d in devices) {
        final mine = voip != null && d.pushToken == voip;
        debugPrint(
          '[CallMedia]   ${d.pushProvider.name} "${d.pushProviderName}" '
          'voip=${d.voip} disabled=${d.disabled ?? false}'
          '${d.disabledReason == null ? '' : ' (${d.disabledReason})'} '
          'token ${tail(d.pushToken)}${mine ? ' ✅ this iPhone' : ''}',
        );
      }
      if (voip == null) {
        debugPrint('[CallMedia]   ❌ iOS gave NO VoIP token (PushKit / voip mode)');
      } else if (!devices.any((d) => d.pushToken == voip)) {
        debugPrint('[CallMedia]   ❌ this iPhone is NOT registered at Stream');
      }
    } catch (e) {
      debugPrint('[CallMedia] push diagnostic failed: $e');
    }
  }

  /// Closes the CallKit screen of [callId], if one is showing (the call
  /// ended in the app, or the caller gave up). Silent: CallKit must not
  /// report it back to us as an "End" press.
  Future<void> endRing(String callId) async {
    if (!_ringsWithCallKit) return;
    try {
      await _client?.pushNotificationManager?.endCallByCid(
        CallKitAction.cidOf(callId),
        silent: true,
      );
    } catch (_) {}
  }

  /// CallKit's events → ours. Only the 3 buttons; the rest (incoming,
  /// mute…) is handled by Stream itself.
  void _listenToCallKit(StreamVideo client) {
    _ringSub?.cancel();
    _ringSub = client.pushNotificationManager?.onCallEvent.listen((event) {
      final (button, cid) = switch (event) {
        ActionCallAccept(:final data) => (CallKitButton.accept, data.callCid),
        ActionCallDecline(:final data) => (CallKitButton.decline, data.callCid),
        ActionCallEnded(:final data) => (CallKitButton.end, data.callCid),
        _ => (null, null),
      };
      final callId = CallKitAction.callIdOf(cid);
      if (button == null || callId == null) return;
      // App ON SCREEN: CallKit's buttons can't be seen, so a Decline / End
      // now is the AppDelegate closing a racing ring (our screen shows the
      // call). Passing it on would decline the call the user is looking at.
      if (button != CallKitButton.accept && _onScreen()) return;
      _callKit.add(CallKitAction(button, callId));
    });
  }

  /// One client per user. A different user (logout → login) → a new one.
  /// Two callers at once (login + a first call) share ONE creation.
  Future<StreamVideo> _clientFor(StreamTokenModel token) async {
    final current = _client;
    if (current != null && _clientUserId == token.userId) return current;
    final pending = _creating;
    if (pending != null && _creatingFor == token.userId) return pending;
    _creatingFor = token.userId;
    final created = _create(token);
    _creating = created;
    try {
      return await created;
    } finally {
      if (identical(_creating, created)) _creating = null;
    }
  }

  Future<StreamVideo>? _creating;
  String? _creatingFor;

  Future<StreamVideo> _create(StreamTokenModel token) async {
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
        // DIAGNOSTIC (iOS ring, 7.3): Stream's own logs for the socket
        // (SV:Client: "close connection" on minimize) and the ring
        // (SV:PNManager: incoming / ended). Xcode console → filter [Stream].
        logPriority: _ringsWithCallKit ? Priority.debug : Priority.none,
        logHandlerFunction: (priority, tag, message, [error, stk]) {
          if (tag != 'SV:Client' && tag != 'SV:PNManager') return;
          debugPrint('[Stream] $tag ${priority.name}: ${message()}');
        },
      ),
      // iOS only (7.3): registers the VoIP token with Stream at connect,
      // and removes it at disconnect (logout). Android: none, on purpose.
      pushNotificationManagerProvider: _ringsWithCallKit
          ? StreamVideoPushNotificationManager.create(
              iosPushProvider: const StreamVideoPushProvider.apn(
                name: apnProvider,
              ),
              // required by the API, never used on iOS
              androidPushProvider: const StreamVideoPushProvider.firebase(
                name: 'firebase',
              ),
            )
          : null,
    );
    _client = client;
    _clientUserId = token.userId;
    if (_ringsWithCallKit) _listenToCallKit(client);
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

  /// Logout → forget the Stream user (on iOS this also removes the VoIP
  /// token from Stream: the next user of this iPhone won't get my calls).
  Future<void> signOut() async {
    await leave();
    await _ringSub?.cancel();
    _ringSub = null;
    _client = null;
    _clientUserId = null;
    try {
      await StreamVideo.reset(disconnect: true);
    } catch (_) {}
  }
}
