# Lesson 0 — START HERE: trace ONE call through the real files 🧵

This is your **entry point**. Read top to bottom. It tells you **exactly which
file to open, which line, and which URL fires** — in order, from pressing Call
to the call ending.

Every line below is a real place in THIS project. Open each file as you read.

> Base URL of every REST call below is `<apiBaseUrl>/api/v1` + the path shown.
> The WebSocket (STOMP) is `<apiBaseUrl>/ws`.

---

## The 10 steps of one call (with file + line + URL)

### ▶ STEP 1 — The Call button (where it all begins)
**File:** `lib/features/chat/views/chat_conversation_page.dart:654-659`
The phone/video icon just opens the call screen — it does NOT start the call.

```dart
VideoCallPage(conversationId: widget.conversationId)   // or VoiceCallPage
```
👉 Start reading the whole project HERE. This is "line 1" of a call.

---

### ▶ STEP 2 — The call screen wakes up and decides its role
**File:** `lib/features/chat/views/voice_call_page.dart:66` (`initState`)
It asks: *is there already a call?* No → I'm the caller → place one.
**File:** `voice_call_page.dart:112` (`_placeOutgoingWithPermission`)
Asks mic permission, then calls the brain.

---

### ▶ STEP 3 — The brain places the call
**File:** `lib/features/chat/repositories/call_signaling_service.dart:399`
(`startOutgoing`)
Sets state = `outgoingRinging` (UI shows "Calling…"), builds `targetIds`,
warms up Stream, then sends the invite.

---

### ▶ STEP 4 — The invite goes to the backend  🌐 URL #1
**File:** `chat_transport.dart:982` (`sendCallInvite`)
calls →
**File:** `chats_remote_data_source.dart:356` (`startCall`)

```
POST /api/v1/chats/conversations/{conversationId}/calls
```
The backend creates the call AND tells Stream to ring the callee.
It replies: `{ id, streamCallCid, participants }`.

---

### ▶ STEP 5 — Get the Stream token (so we can carry audio)  🌐 URL #2
**File:** `stream_call_engine.dart:1636` (`_ensureClientImpl`) calls →
**File:** `chats_remote_data_source.dart:392` (`getStreamToken`)

```
GET /api/v1/chats/calls/stream-token   →  { apiKey, token, userId }
```
(This runs during `warmUp()` in step 3, in parallel.)

---

### ▶ STEP 6 — The caller joins the media leg
**File:** `stream_call_engine.dart:551` (`join`, with `shouldRing: false`)
The caller now sits in the Stream call, waiting. Screen says "Calling…".

---

### ▶ STEP 7 — The OTHER phone rings (callee side)
**File:** `call_signaling_service.dart:915` (`handleIncomingFromPush`)
- App open → reached via Stream WebSocket (`onStreamIncomingCall`).
- App minimized/killed → reached via VoIP push → CallKit
  (`callkit_event_handler.dart`).
Sets callee state = `incomingRinging`.
**File:** `incoming_call_overlay.dart` shows the Accept / Reject sheet.

---

### ▶ STEP 8 — Callee taps Accept  🌐 URL #3
**File:** `incoming_call_overlay.dart` pushes the call page FIRST, then →
**File:** `call_signaling_service.dart:1688` (`acceptIncoming`)
calls `sendCallAccept` (`chat_transport.dart:1018`) →
**File:** `chats_remote_data_source.dart:365` (`acceptCall`)

```
POST /api/v1/chats/calls/{callId}/accept
```
Callee joins Stream media → state = `connected`.

---

### ▶ STEP 9 — The caller learns "accepted" → both connected
The caller flips `outgoingRinging → connected` via EITHER:
- STOMP `call.accept` on `/topic/conversations/{id}/call`, OR
- Stream "peer joined" fallback →
  `call_signaling_service.dart:703` (`_handleStreamPeerJoined`).

Now 🎙 **audio flows through Stream's SFU** and both timers tick.

(Reject path instead: `call_signaling_service.dart:1943` `rejectIncoming` →
`POST /api/v1/chats/calls/{callId}/reject`.)

---

### ▶ STEP 10 — Someone presses End  🌐 URL #4
**File:** `call_signaling_service.dart:1140` (`hangup`)
calls `sendCallHangup` (`chat_transport.dart:1061`) →
**File:** `chats_remote_data_source.dart:384` (`endCall`)

```
POST /api/v1/chats/calls/{callId}/end
```
- Stream `leave()` frees the mic/camera.
- The peer learns via STOMP `call.hangup` OR Stream `remoteLeft`
  (`call_signaling_service.dart:723` `_handleStreamCallEnded`).
- Both screens flip to `ended`, write a call-log + inbox summary, then pop.

---

## The URL sequence, alone (memorize this order)

```
1. GET  /api/v1/chats/calls/stream-token              (build Stream client)
2. POST /api/v1/chats/conversations/{id}/calls        (start call + ring)
3. POST /api/v1/chats/calls/{callId}/accept           (callee picks up)
   (or POST .../reject  if declined)
4. POST /api/v1/chats/calls/{callId}/end              (hang up)
   GET  /api/v1/chats/calls/{callId}                  (reconcile, used as fallback)
```

WebSocket (STOMP) at `<base>/ws`, subscribed topics:
```
/user/queue/calls                       (my personal call events)
/topic/conversations/{id}/call          (this call's invite/accept/reject/hangup)
/topic/conversations/{id}               (chat messages)
/topic/presence                         (who is online)
```

---

## How to actually study it (do this)

1. Open `chat_conversation_page.dart:654` — see the button.
2. Jump to `voice_call_page.dart:66` — see the screen decide.
3. Jump to `call_signaling_service.dart:399` (`startOutgoing`) — the brain.
4. Follow each `transport.sendCall...` into `chat_transport.dart`, then into
   `chats_remote_data_source.dart` to see the real URL.
5. Read `handleIncomingFromPush` (line 915), `acceptIncoming` (1688),
   `hangup` (1140) — these three are 80% of the logic.

Then read the deeper lessons:
[01 big picture](01-big-picture.md) → [02 config](02-configuration.md) →
[03 outgoing](03-outgoing-call.md) → [04 incoming](04-incoming-call.md) →
[05 connect & end](05-connect-and-end.md) → [06 flowcharts](06-flowcharts.md) →
[07 apply elsewhere](07-apply-to-another-project.md) →
[08 the 4 incoming cases](08-incoming-call-4-cases.md).

⬅ Back to the [index](README.md).
