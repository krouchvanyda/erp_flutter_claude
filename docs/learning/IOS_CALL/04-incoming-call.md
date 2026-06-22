# Lesson 4 — Incoming Call (B's phone rings) 🔔

In Lesson 3, A pressed Call and the backend told Stream to ring B. Now we are
on **B's phone**. How B finds out about the call depends on B's app state:

```
   Is B's app...
   ┌──────────────────────────────────────────────────────────────┐
   │  OPEN (foreground)   →  Stream WebSocket delivers the ring     │  Path 1
   │  MINIMIZED (bg)      →  VoIP push → native CallKit ring screen │  Path 2
   │  KILLED (closed)     →  VoIP push wakes a tiny isolate → ring  │  Path 3
   └──────────────────────────────────────────────────────────────┘
```

All three paths end at the **same place**: the brain's `_active` becomes
`incomingRinging`, and B gets an Accept / Reject choice.

---

## 4.1 — Path 1: app is OPEN (foreground)

When B's app is open, Stream's **WebSocket** is already connected. Stream pushes
the incoming-call event over that socket. The media engine catches it:

```dart
// stream_call_engine.dart exposes a stream of incoming calls:
Stream<Call> get onStreamIncomingCall => _incomingCallController.stream;
```

The brain listens and **bridges** it into the same handler the push path uses:

```dart
// call_signaling_service.dart (constructor)
_streamIncomingSub = streamEngine.onStreamIncomingCall.listen(_handleStreamIncomingCall);
```

`_handleStreamIncomingCall` figures out three things from the Stream call:
1. **Who is calling** (`callerName` — from Stream's `createdByUser.name`, or our
   local `UsersCache`, or last resort the id).
2. **The backend call id** (parsed from the CID `erp-call-42` → `42`).
3. **Which local conversation** this belongs to (so we can show the right name
   + photo). It uses `findDirectWith(callerId)` when needed.

Then it builds a normal `call.invite` payload and calls the shared handler:

```dart
await handleIncomingFromPush(payload);   // ◄── the ONE handler all paths use
```

> 🧠 Lesson — **funnel many sources into one handler.** Foreground, background,
> killed: three different ways to *learn* about the call, but they all build the
> same `{type:'call.invite', callId, conversationId, callerId, callerName,
> callType, streamCallCid}` map and call `handleIncomingFromPush`. One handler =
> one place for bugs to live = easy to fix.

---

## 4.2 — The shared handler: `handleIncomingFromPush`

This is where `_active` becomes `incomingRinging`. Simplified:

```dart
Future<void> handleIncomingFromPush(Map<String, dynamic> data) async {
  if (data['type'] != 'call.invite') return;

  // (a) Dedupe: if we already have this callId, do nothing (the WS and the
  //     push can both deliver the same invite — don't show the sheet twice).
  if (_active?.callId == data['callId']) return;

  // (b) Busy check: if I'm already in another (non-ended) call, auto-reject
  //     with reason 'busy' and keep my own call.
  if (_active != null && _active.state != incomingRinging && != ended) {
    transport.sendCallReject(callId, reason: 'busy');
    return;
  }

  // (c) Log a "missed by default" call-log row (so history is right even if
  //     I never pick up).
  final logged = await callLog.logStart(...);

  // (d) Resolve the conversation so the sheet shows name + photo.
  var conv = await conversations.findById(conversationId)
          ?? await conversations.findDirectWith(callerId);

  // (e) Build ActiveCall in incomingRinging → the overlay lights up.
  _setActive(ActiveCall(
    state: CallSignalState.incomingRinging,
    callId: callId, peerId: callerId, peerName: callerName,
    callType: callType, callerId: callerId,
    streamCallCid: streamCallCid, ...
  ));

  // (f) Subscribe so the later call.accept / call.hangup frames land here.
  transport.subscribeConversation(conversationId);

  // (g) iOS: warm up Stream + pre-getOrCreate the call WHILE ringing, so
  //     pressing Accept only has to do the final media connect (fast).
  if (Platform.isIOS) {
    unawaited(streamEngine.warmUp());
    unawaited(_prepareIncomingStream(callId, callType));
  }
}
```

> 🧠 Lesson — **prepare during the ring.** On iOS we do the slow Stream setup
> (`prepareIncoming` = `getOrCreate` without joining) *while the phone is still
> ringing*. So when B finally taps Accept, only the last fast step remains. This
> is why the call connects quickly instead of after an awkward 3–5 second pause.

---

## 4.3 — The in-app popup: `IncomingCallOverlay`

`IncomingCallOverlay` is mounted at the very top of the app (via
`MaterialApp.builder`), so it can paint **over any screen** B happens to be on.
It watches `activeCallListenable`. When state becomes `incomingRinging`, it
shows a full-screen sheet:

- Direct call → caller's avatar + name + "Incoming voice/video call".
- Group call → group photo/cluster + group name + "Vibol is calling…" subtitle.
- Two buttons: **Reject** (red) and **Accept** (green).

```
 ┌──────────────────────────────┐
 │                              │
 │         (caller photo)       │
 │           Vibol Sok          │
 │     Incoming voice call      │
 │                              │
 │     ⛔ Reject     ✅ Accept    │
 └──────────────────────────────┘
```

---

## 4.4 — Path 2: app is MINIMIZED (background)

When B's app is backgrounded, Stream's WebSocket is dropped (to save battery /
because iOS suspends it). So the foreground path can't fire. Instead:

```
 Stream ── VoIP push (high priority) ──► iOS system
 iOS ── shows the native CallKit ring screen (green call UI) ──► B sees it
        even though the app is not on screen
```

When B taps **Accept** on that native screen, iOS launches/wakes the app and
delivers a CallKit "accept" event. That lands in `callkit_event_handler.dart`,
which calls into the brain (`signaling.acceptIncoming()`), exactly like the
in-app Accept button would.

> 🧠 Lesson — **CallKit is iOS's pre-built call screen.** You don't draw it.
> You feed it a call (via the VoIP push + `flutter_callkit_incoming`), and it
> hands you back "user accepted" / "user declined" events. Your job is to turn
> those events into the same `acceptIncoming()` / `rejectIncoming()` calls.

---

## 4.5 — Path 3: app is KILLED (fully closed)

This is the hardest. There is **no app running at all** — no widgets, no
WebSocket, nothing.

```
 Stream ── VoIP push ──► iOS ── wakes a tiny background ISOLATE (no UI)
 The isolate shows the CallKit ring via the native side
 B taps Accept → app cold-starts → callkit_event_handler runs early
 → it tells the backend "accepted" ASAP (notifyBackendAcceptEarly)
 → then seeds _active and pushes the call page once the UI is ready
```

Because a cold start is slow and fragile, the code has safety nets:

- `notifyBackendAcceptEarly(numericCallId)` POSTs `/accept` **immediately**,
  decoupled from the full accept flow, so the **caller stops ringing fast** even
  if the rest of B's startup is slow.
- `primeWebRtcAudioEventSinkEarly()` (Lesson 2) runs first in `main()` to avoid
  a crash when the mic turns on during cold start.
- The accept is pushed through `AppRouter.rootNavigatorKey` (a global key)
  because the overlay can't reach the router the normal way during a cold start.

> 📌 Honest limitation (from the code comments + project memory): in a pure
> local-relay demo, a killed app can't be woken without a real push server. This
> project DOES have the VoIP push working on iOS (paid Stream + APNs), but it
> requires the exact dashboard config from Lesson 2. Without it, a killed phone
> simply shows the call as "missed".

---

## 4.6 — All three paths, one picture

```
                          ┌─────────────────────────┐
   FOREGROUND  ──────────►│  Stream WebSocket event  │
                          │  onStreamIncomingCall    │──┐
                          └─────────────────────────┘  │
                          ┌─────────────────────────┐  │
   BACKGROUND  ──VoIP────►│  CallKit native ring     │  │  all build the same
                          │  callkit_event_handler   │──┤  call.invite payload
                          └─────────────────────────┘  │
                          ┌─────────────────────────┐  │
   KILLED      ──VoIP────►│  isolate → CallKit ring  │  │
                          │  + notifyBackendAccept   │──┘
                          └─────────────────────────┘  │
                                                        ▼
                                       handleIncomingFromPush(payload)
                                                        │
                                                        ▼
                                       _active = incomingRinging
                                                        │
                                                        ▼
                                       IncomingCallOverlay shows Accept/Reject
```

---

## ✅ Check yourself

1. What delivers the ring when B's app is OPEN? *(Stream WebSocket →
   `onStreamIncomingCall`.)*
2. What delivers it when B is MINIMIZED or KILLED? *(A VoIP push → CallKit.)*
3. Why do all three paths call the same `handleIncomingFromPush`? *(One place
   for the logic = fewer bugs; consistent behavior.)*
4. What does "prepare during the ring" mean and why? *(Do the slow Stream
   `getOrCreate` while ringing so Accept is fast.)*

Next: **[Lesson 5 — Connect & End](05-connect-and-end.md)** — B accepts, audio
flows, someone hangs up, cleanup.
