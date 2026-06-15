import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:erp_mobile/core/di/service_locator.dart';

import '../../../../core/router/app_router.dart';
import '../../data/call_signaling_service.dart';
import '../pages/video_call_page.dart';
import '../pages/voice_call_page.dart';

/// Routes a tap or action button from a `call.invite` heads-up
/// notification into the call ceremony.
///
/// Called from `LocalNotificationProvider`'s `onDidReceiveNotificationResponse`
/// once the payload has been identified as a call invite (`type ==
/// "call.invite"`). Three entry points:
///
/// - **Body tap** (`actionId == null`) — open the in-app
///   `IncomingCallOverlay` for this call so the user sees the same
///   sheet they'd see if they were foregrounded when the invite
///   arrived. Achieved by seeding `_active` and letting the overlay
///   listener pick it up. We do NOT auto-accept here.
/// - **Accept action** — seed `_active`, push the in-call page via
///   `AppRouter.rootNavigatorKey`, then call `acceptIncoming()` so the
///   POST + Stream join fire.
/// - **Reject action** — seed `_active` (so we have a callId to
///   reference) and call `rejectIncoming()` so the caller gets the
///   `declined` signal.
///
/// Runs in the main isolate (the OS routes notification responses to
/// the foreground app's isolate when the app is alive — even when
/// paused — and to the dedicated background isolate when killed). The
/// background-isolate branch is handled in
/// `onDidReceiveBackgroundNotificationResponse` at the bottom of
/// `local_notification_provider.dart`; this file is for the live-app
/// path.
class CallNotificationRouter {
  CallNotificationRouter._();

  /// Decode the JSON payload and dispatch. Safe to call with a payload
  /// that turns out NOT to be a call invite — it just returns false
  /// so the caller can fall through to the legacy handler.
  static Future<bool> dispatch(String payload, {String? actionId}) async {
    Map<String, dynamic> data;
    try {
      data = jsonDecode(payload) as Map<String, dynamic>;
    } catch (e) {
      if (kDebugMode) log('CallNotificationRouter: bad payload — $e');
      return false;
    }
    if (data['type'] != 'call.invite') return false;

    if (kDebugMode) {
      log('📞 [call.invite] TAP · actionId=${actionId ?? "body"} · '
          'callId=${data['callId']} · '
          'callerName=${data['callerName']} · '
          'callType=${data['callType']}');
    }

    final signaling = _safelyGet<CallSignalingService>();
    if (signaling == null) {
      if (kDebugMode) {
        log('📞 [call.invite] CallSignalingService not registered yet — '
            'skipping (this happens on a killed-app cold start before '
            'the DI graph boots)');
      }
      return false;
    }

    await signaling.handleIncomingFromPush(data);

    switch (actionId) {
      case kCallAcceptActionId:
        if (kDebugMode) log('📞 [call.invite] → ACCEPT, pushing call page');
        _pushCallPage(data);
        // Fire-and-forget — the page subscribes to the service and
        // reacts to the connected-state transition on its own.
        unawaited(signaling.acceptIncoming());
      case kCallRejectActionId:
        if (kDebugMode) log('📞 [call.invite] → REJECT');
        unawaited(signaling.rejectIncoming());
      default:
        // Body tap. Let the in-app `IncomingCallOverlay` render the
        // Accept/Reject sheet — it's already a listener on
        // `signaling.activeCallListenable` and will rebuild as soon as
        // `handleIncomingFromPush` flips `_active` to incomingRinging.
        if (kDebugMode) log('📞 [call.invite] → BODY TAP, opening overlay');
        break;
    }
    return true;
  }

  static void _pushCallPage(Map<String, dynamic> data) {
    final navigator = AppRouter.rootNavigatorKey.currentState;
    if (navigator == null) return;
    final conversationId = data['conversationId']?.toString() ?? '';
    final isVideo = data['callType']?.toString() == 'video';
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => isVideo
            ? VideoCallPage(conversationId: conversationId)
            : VoiceCallPage(conversationId: conversationId),
        fullscreenDialog: true,
      ),
    );
  }

  /// `GetIt.I<T>()` throws if T isn't registered. The notification
  /// can arrive before the DI graph has fully booted (cold start on a
  /// killed-app push), so we'd rather log + skip than crash on the
  /// notification isolate.
  static T? _safelyGet<T extends Object>() {
    try {
      return GetIt.I<T>();
    } catch (_) {
      return null;
    }
  }
}

/// Shared action ids. Single source of truth — referenced both by
/// the renderer (`AndroidNotificationAction.id`) and by this router's
/// `actionId` switch.
const String kCallAcceptActionId = 'accept_call';
const String kCallRejectActionId = 'reject_call';
