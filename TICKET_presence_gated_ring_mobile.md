# [MOBILE] Client side of the presence-gated incoming-call ring

**Component:** `erp_flutter_claude` · `CallSignalingService` / `StreamCallEngine` / `ChatLifecycleBridge` / `IncomingCallOverlay` / iOS `AppDelegate.swift`
**Type:** Behavior contract (already implemented — this documents & protects it)
**Pairs with:** backend `TICKET_presence_gated_ring.md` (`erp_java_backend_claude`)
**Platform:** iOS-specific fixes only — **Android call flow is untouched** (all changes are `Platform.isIOS`-guarded / additive)
**Status:** Confirmed working alongside backend gate 2026-06-11

## Why this exists
The backend rings via Stream VoIP **only OFFLINE callees**; ONLINE/BUSY callees get a STOMP `call.invite` and nothing else. "OFFLINE" is defined by the backend as "no live STOMP session" — which is created and torn down **by this app**. So the contract only holds if the client drops/raises its STOMP + Stream sessions on the right lifecycle edges, and renders the foreground invite in-app instead of via CallKit. This note records the client responsibilities so a refactor doesn't silently break the gate.

## Client responsibilities (all verified in source)

### 1. Drive the presence signal — STOMP up = ONLINE, down = OFFLINE
`ChatLifecycleBridge` (`lib/features/chat/repositories/chat_lifecycle_bridge.dart:37`) registers a `WidgetsBindingObserver` and on each transition:
- `paused`/`hidden`/`detached` → `transport.pause()` (`:133`), `streamEngine.disconnectForBackground(force: _noActiveCall())` (`:156`), `presence.reportBackground()` (`:163`)
- `resumed` → `transport.resume()` (`:168`), `streamEngine.warmUp()` (`:179`), `presence.reportForeground()` (`:172`)

**Do not** keep STOMP alive while backgrounded — a backgrounded device that stays ONLINE would be denied the VoIP ring by the backend gate and miss the call entirely.

### 2. Render the foreground invite in-app, never via CallKit
`IncomingCallOverlay` (`lib/features/chat/widgets/incoming_call_overlay.dart:24`) is mounted via `MaterialApp.builder` (`lib/app.dart:230`) and shows the Accept/Reject sheet when `CallSignalState.incomingRinging` (`incoming_call_overlay.dart:223`). The STOMP `call.invite` handler in `CallSignalingService` (`lib/features/chat/repositories/call_signaling_service.dart:1937`) sets `ActiveCall(state: incomingRinging)`. Foreground = WebRTC owns `AVAudioSession` alone (mute/speaker work).

Native safety net: `AppDelegate.swift` `CXCallObserver` (`ios/Runner/AppDelegate.swift:72`, delegate `:140`) suppresses any CallKit ring that slips through while `isAppForeground` via `reportCall(endedAt:)` (`:217–221`) — covers the presence-race window only; it is **not** a substitute for the backend gate.

### 3. Keep the Stream WS state correct across a backgrounded call end
`StreamCallEngine.disconnectForBackground({bool force})` (`lib/features/chat/repositories/stream_call_engine.dart:1376`) — `force` is honored on iOS only (`final forced = force && Platform.isIOS`, `:1377`). Mid-call minimize keeps the WS warm (audio survives); once the call is provably over, `force: _noActiveCall()` drops it so a 2nd call to a still-minimized callee rings over a fresh APNs VoIP push instead of a warm WS.

### 4. Recover the call from `streamCallCid`
`streamCallCid` (`call_signaling_service.dart:109`) is read from the `call.invite` response (`:586`) and from `GET /chats/calls/{id}` polling (`:988`), then passed to `StreamCallEngine.join(...)` (`:357`) to bridge signalling → media. The killed/minimized path depends on the backend including this id in **both** `call.invite` and `call.cancel` FCM payloads.

### 5. Dismiss a minimized CallKit ring on caller-cancel via REST poll
`CallSignalingService.watchBackgroundRingForCancel(callId)` (`call_signaling_service.dart:1363`, iOS-only at `:1364`) polls `GET /chats/calls/{id}` every 3s (≤36s). On terminal status (`ENDED`/`MISSED`/`REJECTED`/`CANCELLED`) it calls `_clearNativeIncoming(callId)` → native `erp/ios_callkit` → `dismissIncoming` → `reportCall(endedAt:)` (`AppDelegate.swift:114`). PushKit rings can't be dismissed by a late push — only `reportCall(endedAt:)` works, so this poll is the deterministic path for a minimized-but-alive callee.

## Backend dependencies this client relies on (mirror of the backend ticket)
- `streamCallCid` present in `call.invite` **and** `call.cancel` FCM payloads.
- Every terminal path hits Stream `mark_ended`, and `GET /api/v1/chats/calls/{id}` returns terminal `status`/`endedAt` promptly (the 3s poll reads it).
- `FCM_ENABLED` set appropriately for prod — without it, killed-app callees have no backup delivery path (a minimized-alive callee still recovers via the REST poll; a fully-killed app cannot poll).

## Guardrails for future edits
- All call fixes are **iOS-only and additive**. Keep `Platform.isIOS` guards; never change the Android path. Representative guards: `call_signaling_service.dart:1364` (`watchBackgroundRingForCancel`), `:1860` (`goOfflineForPushIfBackground`), `stream_call_engine.dart:82` (`primeWebRtcAudioEventSink`), `:494` (`prepareIncoming`).
- Do not re-add an unconditional Stream ring on the client, and do not keep STOMP warm while backgrounded — both break the backend presence gate.

## Known-open (separate from this contract)
- Fully-killed app: no engine to poll → relies on Stream APN VoIP device registration + sandbox cert. Tracked separately.
- 2nd-call-no-ring while minimized: addressed by the `force`-drop in #3; if it recurs, watch the `disconnectForBackground: dropping WS` vs `skipped (...)` log line.
