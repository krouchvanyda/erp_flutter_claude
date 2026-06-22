# Android — The 4 Incoming-Call Cases (diagrams) 📲

Just like iOS, how the callee's phone rings depends on the app state. The logic
is the **same shape** as iOS — only the *ring delivery* changes (FCM +
`erp_callkit` instead of APNs VoIP + CallKit).

| # | Case | App process? | Stream WebSocket? | What rings the phone (Android) |
|---|------|--------------|-------------------|--------------------------------|
| 1 | **In app (foreground)** | running, on screen | ✅ alive | in-app overlay (same as iOS) |
| 2 | **Minimized (background)** | running, hidden | ❌ dropped | **FCM** → `erp_callkit` full-screen ring |
| 3 | **Killed app** | ❌ not running | ❌ none | **FCM** cold-starts a background isolate → ring |
| 4 | **Killed + locked screen** | ❌ not running | ❌ none | FCM ring + `MainActivity` shows over the lock screen |

> 📘 Compare with the iOS version:
> [`../IOS_CALL/08-incoming-call-4-cases.md`](../IOS_CALL/08-incoming-call-4-cases.md).
> Cases 1 is identical; cases 2–4 swap APNs VoIP/CallKit for FCM/erp_callkit.

---

## 🟢 CASE 1 — In app (foreground) — SAME AS iOS

The app is open, Stream's WebSocket is alive and hands us the call. The in-app
`IncomingCallOverlay` shows Accept/Reject. No FCM needed.

```
  PHONE STATE: app OPEN
  Stream WebSocket event → handleIncomingFromPush → state = incomingRinging
        │
        ▼
  SCREEN ► IncomingCallOverlay  (Accept / Reject)
        │
   Accept ▼
  SCREEN ► VoiceCallPage / VideoCallPage
  URL: POST /api/v1/chats/calls/{id}/accept  → 🎙 connected
```

This is byte-for-byte the same as iOS Case 1.

---

## 🟡 CASE 2 — Minimized (background) — FCM rings it

The app is alive but hidden; the Stream WebSocket is suspended. **Stream sends an
FCM data message**, which our app's background handler turns into a full-screen
ring via `erp_callkit`.

```
  PHONE STATE: app MINIMIZED · Stream WebSocket dropped
  ┌─────────────────────────────────────────────────────────────┐
  │ Stream → high-priority FCM data message                     │
  │   { sender:'stream.video', type:'call.ring',                 │
  │     call_cid, caller_id, caller_name }                       │
  └───────────────────────────┬─────────────────────────────────┘
                              ▼
  ┌─────────────────────────────────────────────────────────────┐
  │ firebaseMessagingBackgroundHandler (main.dart)              │
  │   → _showStreamCallkitRinger(message)                        │
  │   → FlutterCallkitIncoming.showCallkitIncoming(params)       │
  └───────────────────────────┬─────────────────────────────────┘
                              ▼
  ┌─────────────────────────────────────────────────────────────┐
  │ SCREEN ► full-screen ring (erp_callkit IncomingCallNotifier) │
  └─────────────┬───────────────────────────────┬───────────────┘
        Accept ▼                        Reject ▼
  ┌──────────────────────────────┐   ┌──────────────────────────┐
  │ app foregrounds →            │   │ erp_callkit               │
  │ SCREEN ► VoiceCallPage /     │   │ CallActionReceiver →      │
  │          VideoCallPage       │   │ BackendCallClient →       │
  │ POST /api/v1/chats/calls/    │   │ POST /chats/calls/{id}/   │
  │      {id}/accept             │   │      reject               │
  │ 🎙 connected                 │   └──────────────────────────┘
  └──────────────────────────────┘
```

**De-dupe:** if the callee is actually still foreground (got it via WebSocket
already), the FCM copy is dropped by matching the call id — so the ring never
shows twice.

---

## 🟠 CASE 3 — Killed app — FCM cold-starts an isolate

No process at all. The FCM message **cold-starts a background isolate** (that's
why the handler must be top-level + `@pragma('vm:entry-point')`), which shows the
ring. Accept then cold-starts the full app.

```
  PHONE STATE: app KILLED
  Stream → FCM ──► cold-start background ISOLATE (no UI)
                   firebaseMessagingBackgroundHandler runs
                   → _showStreamCallkitRinger → showCallkitIncoming
        │
        ▼
  SCREEN ► full-screen ring (erp_callkit)
        │
   Accept ▼ (app COLD-STARTS)
  SCREEN ► VoiceCallPage / VideoCallPage → acceptIncoming → POST /accept
  🎙 connected · URL on End: POST /api/v1/chats/calls/{id}/end
```

> 🧠 Android's killed-app path is **simpler than iOS's**. iOS needs the
> WebRTC-audio crash prime, early-accept, stale-accept recovery, and a global
> navigator key. Android mostly just needs the isolate + `erp_callkit` to show
> the ring and route Accept/Reject.

---

## 🔴 CASE 4 — Killed + locked screen — `MainActivity` shows over the lock

Same as Case 3, plus the screen is locked. The native `MainActivity.kt` makes
the call UI appear **over the lock screen**.

```
  PHONE STATE: app KILLED + LOCKED
  Stream → FCM cold-start → erp_callkit ring (full-screen intent)
        │
   Accept ▼
  ┌─────────────────────────────────────────────────────────────┐
  │ MainActivity.maybeShowOverLockscreen():                     │
  │   setShowWhenLocked(true) + setTurnScreenOn(true)           │
  │   → call UI shows ON TOP of the keyguard (device stays locked)│
  └───────────────────────────┬─────────────────────────────────┘
                              ▼
  SCREEN ► VoiceCallPage / VideoCallPage → POST /accept → 🎙 connected
                              │
                          End ▼
  ┌─────────────────────────────────────────────────────────────┐
  │ MainActivity.returnToLockScreenIfNeeded():                  │
  │   if still locked → moveTaskToBack(true)                    │
  │   → drops the app BACK behind the lock screen               │
  └─────────────────────────────────────────────────────────────┘
```

**Why this matters:** without it, answering a call on a locked phone would leave
the app sitting **unlocked** on the dashboard after the call. `MainActivity`
puts it back behind the keyguard.

> 🧠 On iOS this is automatic (CallKit owns the lock-screen UI). On Android we do
> it ourselves in `MainActivity.kt` with `USE_FULL_SCREEN_INTENT` +
> `setShowWhenLocked`.

---

## 📊 All 4 cases (Android)

```
            ┌──────────────┬───────────────┬─────────────────┬─────────────────────┐
            │ 1 FOREGROUND │ 2 MINIMIZED   │ 3 KILLED        │ 4 KILLED + LOCKED   │
 ───────────┼──────────────┼───────────────┼─────────────────┼─────────────────────┤
 rings via  │ in-app       │ FCM →         │ FCM cold-start  │ FCM + MainActivity  │
            │ overlay      │ erp_callkit   │ isolate → ring  │ over lock screen    │
 Stream WS  │ alive ✅     │ dropped ❌    │ none ❌         │ none ❌             │
 cold start │ no           │ no            │ YES (isolate)   │ YES (isolate)       │
 accept     │ overlay btn  │ CallKit btn   │ CallKit btn     │ CallKit btn (locked)│
 reject     │ overlay btn  │ CallActionReceiver → BackendCallClient → POST /reject │
 ───────────┴──────────────┴───────────────┴─────────────────┴─────────────────────┘
```

---

## How Android differs from iOS — quick recap

| Step | iOS | Android |
|------|-----|---------|
| Ring a closed phone | APNs VoIP (PushKit) | **FCM** data message |
| Show the ring | Stream PushKit → CallKit | **our FCM handler** → `showCallkitIncoming` (erp_callkit) |
| Payload keys | `callCid` | `call_cid` / `caller_id` / `caller_name` |
| Lock screen | CallKit (automatic) | `MainActivity` `setShowWhenLocked` + `USE_FULL_SCREEN_INTENT` |
| Killed-app reject | CallKit native | `CallActionReceiver` → `BackendCallClient` (JWT from Dart) |
| Audio re-assert | required | **not needed** (Android manages audio) |

---

## ✅ Check yourself

1. What rings a closed Android phone? *(An FCM high-priority data message.)*
2. Which function shows the ring on Android? *(`_showStreamCallkitRinger` →
   `FlutterCallkitIncoming.showCallkitIncoming`, from the FCM background
   handler.)*
3. What makes the call UI appear over a locked Android screen? *(`MainActivity`
   `setShowWhenLocked` + `USE_FULL_SCREEN_INTENT`.)*
4. How is a killed-app Reject sent to the backend on Android? *(`erp_callkit`
   `CallActionReceiver` → `BackendCallClient` POSTs `/reject`, with the JWT
   passed from Dart.)*

⬅ Back to the [index](README.md).
