import 'dart:async';
import 'dart:ui' show DartPluginRegistrant;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart' show RemoteMessage;
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    show NotificationResponse;

import '../core/di/service_locator.dart';
import '../core/push/push_messaging.dart';
import '../features/call/model/call_push.dart';
import '../features/call/repository/background_call_api.dart';
import '../features/call/repository/call_notifications.dart';
import '../features/call/repository/call_sounds.dart';
import '../features/call/viewmodel/call/call_view_model_bloc.dart';

// Call pushes (Step 7.2) — in `app/` because core/push must not know calls.
//
// ```
// app KILLED / MINIMIZED                     app OPEN (main isolate)
// FCM ─► callPushBackgroundHandler           STOMP shows the call (Step 6)
//        (background isolate, no DI)          FCM call.cancel ─► stop a ring
//        invite ─► ring notification          tap / Answer ─► OnCallOpenedFromPushEvent
//        cancel ─► stop it                    Decline ─► the bloc declines
//        Decline ─► callDeclineInBackground ─► POST /calls/{id}/reject
// ```

/// FCM, app minimized or killed. A TOP-LEVEL function: Android starts it in
/// a fresh background isolate where `main()` never ran (no DI, no Flavor pin
/// → `Flavor.current` falls back to the `--flavor` build flag).
@pragma('vm:entry-point')
Future<void> callPushBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  final push = CallPush.fromData(message.data);
  if (push == null) return; // a chat message push: not handled yet
  final notifications = CallNotifications();
  await notifications.init(onBackgroundAction: callDeclineInBackground);
  switch (push) {
    case CallPushInvite(:final callId):
      await notifications.showIncoming(push);
      // The app may be KILLED (no call bloc): tell the caller it rings here,
      // or their screen stays on "Calling…". If the app is alive too, its
      // bloc also sends it — harmless (the caller just sees "Ringing…").
      await BackgroundCallApi.ringing(callId);
    case CallPushCancel(:final callId):
      await notifications.cancel(callId); // answered elsewhere / gave up
  }
}

/// "Decline" on the ring notification while the app isn't running.
/// Another TOP-LEVEL function, in another background isolate.
@pragma('vm:entry-point')
Future<void> callDeclineInBackground(NotificationResponse response) async {
  if (response.actionId != CallNotifications.actionDecline) return;
  final callId = CallNotifications.callIdOf(response.payload);
  if (callId == null) return;
  DartPluginRegistrant.ensureInitialized(); // secure storage needs plugins
  await BackgroundCallApi.reject(callId);
}

/// Before `runApp`: who handles pushes while the app is in the background.
void setUpCallPushBackground() =>
    PushMessaging.setBackgroundHandler(callPushBackgroundHandler);

/// After `runApp` (main isolate): notifications → the call bloc.
/// [fcm] false = Firebase didn't start: the notifications still work, only
/// FCM isn't listened to.
Future<void> attachCallPush({required bool fcm}) async {
  final calls = getIt<CallViewModelBloc>();
  final notifications = getIt<CallNotifications>();
  getIt<CallSounds>().attach(); // ringtone waits while in the background

  void open(String callId, {required bool answer}) =>
      calls.add(OnCallOpenedFromPushEvent(callId, answer: answer));

  await notifications.init(
    onOpen: open,
    onDecline: (callId) {
      // ringing on screen too → the bloc declines (and closes its screen)
      if (calls.state case CallIncomingState(
        :final call,
      ) when call.id == callId) {
        calls.add(OnCallDeclineEvent());
      } else {
        unawaited(BackgroundCallApi.reject(callId));
      }
    },
    onBackgroundAction: callDeclineInBackground,
  );
  notifications.attach();

  // A call.cancel while the app is open: stop any ring notification.
  if (fcm) {
    getIt<PushMessaging>().onForegroundData.listen((data) {
      if (CallPush.fromData(data) case CallPushCancel(:final callId)) {
        notifications.cancel(callId);
      }
    });
  }

  // Started by tapping the notification / Answer, or opened while it rings.
  final launched = await notifications.launchedFrom();
  if (launched != null) {
    open(launched.callId, answer: launched.answer);
  } else if (await notifications.ringingNow() case final ringing?) {
    open(ringing, answer: false);
  }
}
