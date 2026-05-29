import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';

import 'chats_remote_data_source.dart';

/// Thin wrapper around `stream_video_flutter` so the rest of the
/// chat module doesn't import the SDK directly. Exposes just three
/// operations: lazy [_ensureClient] (one client per process), [join]
/// (called after our REST POST has produced a `streamCallCid`), and
/// [leave] (called on every end-of-call path).
///
/// Failures are deliberately swallowed — call media is best-effort
/// on top of the chat ceremony. If Stream is unreachable we still
/// want the signalling state machine, timers, and call logs to
/// behave correctly so the user can hang up cleanly.
class StreamCallEngine {
  StreamCallEngine({required this.remote});

  final ChatsRemoteDataSource remote;

  StreamVideo? _client;
  Call? _activeCall;

  /// Cached identity used to bring the client up. We re-fetch the
  /// token if [_clientUserId] doesn't match the one we're being asked
  /// to join as (rare: sign-out → sign-in mid-session).
  String? _clientUserId;

  /// Join the media leg of the call carried by [streamCallCid]
  /// (e.g. `default:abc123`). The chat ceremony is responsible for
  /// reaching the "connected" state BEFORE this is called — Stream
  /// is just the audio/video pipe under it.
  ///
  /// No-op when [streamCallCid] is null/empty (backend hasn't shipped
  /// Stream integration for this call) or the token endpoint fails.
  Future<void> join({
    required String streamCallCid,
    required bool isVideo,
  }) async {
    if (streamCallCid.isEmpty) return;
    try {
      await _ensureClient();
      final client = _client;
      if (client == null) return;

      // CID is `type:id` — split and feed both halves to the SDK.
      // Tolerant of a missing `:` (treat the whole string as the id
      // and use the default call type).
      final parts = streamCallCid.split(':');
      final callType = parts.length > 1 ? parts[0] : 'default';
      final callId = parts.length > 1 ? parts[1] : streamCallCid;

      final call = client.makeCall(
        callType: StreamCallType.fromString(callType),
        id: callId,
      );
      await call.getOrCreate();
      await call.join(
        connectOptions: CallConnectOptions(
          camera: isVideo
              ? TrackOption.enabled()
              : TrackOption.disabled(),
          microphone: TrackOption.enabled(),
        ),
      );
      _activeCall = call;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('StreamCallEngine.join failed: $e\n$st');
      }
    }
  }

  /// Leave the active Stream call (if any) and clear the cached
  /// handle. Safe to call multiple times. Does NOT tear down the
  /// shared client — that stays for the next call.
  Future<void> leave() async {
    final call = _activeCall;
    _activeCall = null;
    if (call == null) return;
    try {
      await call.leave();
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('StreamCallEngine.leave failed: $e\n$st');
      }
    }
  }

  /// Build (or rebuild) the `StreamVideo` client using a fresh token
  /// from `GET /chats/calls/stream-token`. Cached by `userId` so a
  /// sign-out / sign-in rotation rebuilds; otherwise re-used.
  Future<void> _ensureClient() async {
    Map<String, dynamic> tokenJson;
    try {
      tokenJson = await remote.getStreamToken();
    } catch (e) {
      if (kDebugMode) debugPrint('StreamCallEngine token fetch failed: $e');
      return;
    }
    final apiKey = tokenJson['apiKey']?.toString() ?? '';
    final token = tokenJson['token']?.toString() ?? '';
    final userId = tokenJson['userId']?.toString() ?? '';

    if (kDebugMode) {
      debugPrint(
        '[StreamCallEngine] /stream-token → '
        'apiKey=$apiKey '
        'userId=$userId '
        'token=${_redactToken(token)}',
      );
    }

    if (apiKey.isEmpty || token.isEmpty || userId.isEmpty) {
      if (kDebugMode) {
        debugPrint(
          '[StreamCallEngine] missing field(s) from /stream-token — '
          'apiKey.empty=${apiKey.isEmpty} '
          'token.empty=${token.isEmpty} '
          'userId.empty=${userId.isEmpty} — aborting join',
        );
      }
      return;
    }

    if (_client != null && _clientUserId == userId) return;
    // Identity changed (or first use) — rebuild.
    try {
      await _client?.disconnect();
    } catch (_) {/* swallow */}
    _client = StreamVideo(
      apiKey,
      user: User.regular(userId: userId),
      userToken: token,
    );
    _clientUserId = userId;
    try {
      await _client!.connect();
      if (kDebugMode) {
        debugPrint('[StreamCallEngine] connected as userId=$userId');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('StreamVideo.connect failed: $e');
    }
  }

  /// JWTs are sensitive — log only head + tail so we can verify shape
  /// (3 dot-separated base64 segments) without leaking the full token.
  static String _redactToken(String token) {
    if (token.length <= 16) return '***';
    return '${token.substring(0, 8)}…${token.substring(token.length - 6)} '
        '(len=${token.length})';
  }

  /// Tear down for tests / hot-restart. Production code doesn't need
  /// to call this — the client lives for the app's lifetime.
  Future<void> dispose() async {
    await leave();
    try {
      await _client?.disconnect();
    } catch (_) {}
    _client = null;
    _clientUserId = null;
  }
}
