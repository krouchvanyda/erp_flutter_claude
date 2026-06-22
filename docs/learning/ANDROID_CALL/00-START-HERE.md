# Android — START HERE: trace ONE call 🧵

This is the Android entry point. A call on Android is the **same** as iOS until
the phone is closed — then **FCM + erp_callkit** ring it (instead of APNs VoIP +
CallKit).

> Base URL of every REST call below is `<apiBaseUrl>/api/v1`. The WebSocket
> (STOMP) is `<apiBaseUrl>/ws`. These are the **same** as iOS.

---

## The shared part (identical to iOS)

When the app is **open**, Android does exactly what iOS does:

```
 Button (chat_conversation_page.dart)
   → VoiceCallPage / VideoCallPage
   → startOutgoing()  (call_signaling_service.dart)
   → POST /api/v1/chats/conversations/{id}/calls
   → backend tells Stream to ring
   → other side Accepts → POST /accept → connected → 🎙 Stream media
   → End → POST /end
```

👉 This whole part "../../../learning/ANDROID_CALL"is taught in [`../IOS_CALL/03-outgoing-call.md`](../IOS_CALL/03-outgoing-call.md)
and [`../IOS_CALL/05-connect-and-end.md`](../IOS_CALL/05-connect-and-end.md). It
applies to Android with **no change**.

The URL order is the same on both platforms:
```
1. GET  /api/v1/chats/calls/stream-token
2. POST /api/v1/chats/conversations/{id}/calls
3. POST /api/v1/chats/calls/{callId}/accept   · or /reject
4. POST /api/v1/chats/calls/{callId}/end
```

---

## The Android-different part"../../../learning/ANDROID_CALL": ringing a CLOSED phone

This is the only thing you must learn fresh. When the callee's app is
**minimized or killed**, Android cannot use the live Stream WebSocket. Instead:

```
 Stream sends a high-priority FCM data message
   { sender: 'stream.video', type: 'call.ring', call_cid, caller_id, caller_name }
        │
        ▼
 Lands in OUR app's FCM background handler
   firebaseMessagingBackgroundHandler   (main.dart registers it)
   → firebase_notification_provider.dart
        │
        ▼
 _showStreamCallkitRinger(message)
   → FlutterCallkitIncoming.showCallkitIncoming(params)
        │
        ▼
 Full-screen ring (via erp_callkit native code on Android)
   Accept / Reject buttons
        │
   Accept ▼                         Reject ▼
 app opens VoiceCallPage/         erp_callkit CallActionReceiver
 VideoCallPage → acceptIncoming   → BackendCallClient → POST /reject
```

**Files to open for this Android part"../../../learning/ANDROID_CALL":**
1. `lib/main.dart` — `FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler)`
2. `lib/shared/firebase_services/firebase_notification_provider.dart` —
   the handler + `_showStreamCallkitRinger` (look for `sender == 'stream.video'`
   and `type == 'call.ring'`).
3. `packages/erp_callkit/android/.../IncomingCallNotifier.kt` — draws the ring.
4. `packages/erp_callkit/android/.../CallActionReceiver.kt` +
   `BackendCallClient.kt` — handle Accept/Reject and POST to the backend.
5. `android/app/src/main/kotlin/.../MainActivity.kt` — show over the lock screen.

---

## Why the keys are snake_case here

iOS reads `callCid` (camelCase). The Android FCM payload uses **snake_case**:
`call_cid`, `caller_id`, `caller_name`. The code checks both, but on the Android
path you'll see the snake_case versions. Don't let it confuse you — it's the
same data, just a different spelling on the wire.

---

## Next

- [01-configuration-android.md](01-configuration-android.md) — set up FCM,
  permissions, the Stream `firebase` provider, `erp_callkit`.
- [02-incoming-call-4-cases-android.md](02-incoming-call-4-cases-android.md) —
  the 4 phone states drawn for Android.

⬅ Back to the [index](README.md).
