# Lesson 3 — Outgoing Call (I press Call → your phone rings) 📞

This is the most important lesson. We follow **one tap**, from the button to
the moment the other phone rings, step by step. (iOS path.)

We will call the two people **A** (the caller, you) and **B** (the callee).

---

## 3.1 — The map of this lesson

```
 A taps phone icon
        │
        ▼
 [1] Open VoiceCallPage(conversationId)
        │
        ▼
 [2] initState: no existing call → ask mic permission → startOutgoing()
        │
        ▼
 [3] startOutgoing(): build ActiveCall(outgoingRinging), show "Calling…"
        │
        ├──(parallel)──► warm up Stream client
        │
        ▼
 [4] POST /chats/conversations/{id}/calls   (send the invite)
        │
        ▼
 [5] Backend creates call + tells Stream getOrCreate(ring:true)
        │
        ├──────────────► Stream sends VoIP push to B  ──► B's phone RINGS
        ▼
 [6] Backend replies { id, streamCallCid, participants }
        │
        ▼
 [7] Swap temp id → real numeric id; save streamCallCid
        │
        ▼
 [8] A joins the Stream media leg (shouldRing:false) and waits
        │
        ▼
   A sees "Calling…"  ⏳   (Lesson 5 continues from here when B accepts)
```

Now each step in detail.

---

## Step 1 — The button opens the call screen

In `chat_conversation_page.dart` (and `chat_info_page.dart`) the phone / video
icons just **push a page**. They do NOT start the call themselves:

```dart
// chat_conversation_page.dart (simplified)
IconButton(
  icon: const Icon(Icons.call),        // or Icons.videocam_rounded
  onPressed: () => ConfigRouter.pushPageAnimation(
    context,
    VoiceCallPage(conversationId: widget.conversationId),
    //  or VideoCallPage(conversationId: widget.conversationId)
  ),
)
```

> 🧠 Lesson: **the screen decides what to do, not the button.** The button's
> only job is "open the call screen for this conversation". Simple.

---

## Step 2 — The screen wakes up (`initState`) and decides its role

When `VoiceCallPage` mounts, its `initState` asks one question:

> *"Is there ALREADY an active call for this conversation?"*

```dart
final existing = _signaling.current;
if (existing != null && existing.conversationId == widget.conversationId) {
  // I am the CALLEE — I already accepted an invite. Start CONNECTED.
  _stage = _CallStage.connected;
  _startTicker();
} else {
  // I am the CALLER — there is no call yet. PLACE a new one.
  _placedInvite = true;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _placeOutgoingWithPermission();
  });
}
```

So the **same page** is used by both caller and callee. The difference is only:
"did a call already exist when I opened?"

For the caller, it then asks permission and places the call:

```dart
Future<void> _placeOutgoingWithPermission() async {
  await ensureCallPermissions();         // ask mic (camera too for video)
  if (!mounted) return;
  _signaling.startOutgoing(
    conversationId: widget.conversationId,
    callType: ChatCallType.voice,        // or .video
  );
}
```

---

## Step 3 — `startOutgoing()` sets the "mood" to ringing immediately

Now we are in the brain: `CallSignalingService.startOutgoing()`. The first
thing it does is make the UI feel **instant** — it sets local state to
`outgoingRinging` right away, before any network call finishes.

```dart
// 1) iOS: start connecting the Stream client NOW, in parallel, so we don't
//    wait for it later. (Saves time on tap → audio.)
if (Platform.isIOS) unawaited(streamEngine.warmUp());

// 2) Look up the conversation to know WHO to ring.
final conv = await conversations.findById(conversationId);
final me   = settings.userId;

// 3) Build the list of people to ring (targetIds):
//    - direct chat  → just the one other person
//    - group chat   → everyone except me
final targetIds = conv.participantPreviews
    .where((p) => p.employeeId != me)
    .map((p) => p.employeeId)
    .toList();

// 4) Make a TEMPORARY local call id (we don't have the backend's id yet).
final callId = 'call-$me-${now.microsecondsSinceEpoch}';

// 5) Write a call-log row (so history shows the attempt even if nobody picks up).
final logged = await callLog.logStart(...);

// 6) Build ActiveCall in state = outgoingRinging, and show it on screen.
final active = ActiveCall(
  callId: callId,
  conversationId: conversationId,
  peerId: /* the other person */,
  peerName: /* their name */,
  callType: callType,
  state: CallSignalState.outgoingRinging,   // ◄── the UI now shows "Calling…"
  callerId: me,
  ...
);
_setActive(active);                          // pushes to activeCallListenable

// 7) Subscribe to this conversation's call topic so we HEAR B's accept/reject.
transport.subscribeConversation(conversationId);
```

> 🧠 Lesson — **optimistic UI**: we flip to "Calling…" instantly and do the slow
> network work in the background. The user never stares at a frozen button.

> 🧠 Lesson — **targeted ringing (`targetIds`)**: the WebSocket relay is "dumb"
> and broadcasts to everyone connected. So each device must check "is this
> invite addressed to ME?" If we did not send `targetIds`, calling B would also
> ring C and D. (This was a real bug, fixed in slice 10.2.7.)

---

## Step 4 & 5 — Send the invite; backend rings B through Stream

Still inside `startOutgoing`, but now in a background task (`unawaited(...)`),
we POST the invite:

```dart
final response = await transport.sendCallInvite(
  callId: callId,
  conversationId: conversationId,
  callerId: me, callerName: myName,
  callType: callType,
  targetIds: targetIds,
);
```

`sendCallInvite` does **`POST /chats/conversations/{id}/calls`**. On the server:

1. The backend **creates a call row** (status RINGING).
2. The backend calls **Stream** `getOrCreate(ring: true, members: [B])`.
3. **Stream sends a VoIP push to B.** This is what makes B's phone show the
   native iOS green ring screen — even if B's app is closed.

```
   A's app ──POST /calls──► Backend ──Stream getOrCreate(ring:true)──► Stream
                                                                         │
                                                          VoIP push      ▼
                                                       ┌───────── B's iPhone rings
```

> 🧠 Lesson — **the SERVER rings, not the caller's app.** Why? A server-side
> ring is reliable: it works even when A's app loses the network right after
> pressing Call, and it can wake a fully-killed B. (Earlier versions rang from
> the client and it caused the "connect cancelled / no audio" bug — see Lesson 5.)

### What if B is busy or there's a stale call?
The backend may reply with an error like *"already in an active call"*. The
code catches this, runs `_endStaleActiveCalls()` (lists recent calls, ends any
stuck RINGING/ANSWERED rows), and retries the invite once. If it still fails,
A's screen flips to `ended` with a reason, and a snackbar explains why.

---

## Step 6 & 7 — Get the real id back, and swap it in

The POST returns something like:

```json
{ "id": 42,
  "streamCallCid": "default:erp-call-42",
  "participants": [ { "userId": 10 } ] }
```

We then **swap** our temporary id for the real one, and remember the Stream CID:

```dart
final backendCallId = response['id'].toString();        // "42"
final streamCallCid = response['streamCallCid'];         // "default:erp-call-42"

_setActive(cur.copyWith(
  callId: backendCallId,        // ◄── now Accept/Reject/End can POST to /chats/calls/42/...
  streamCallCid: streamCallCid, // ◄── now we can join Stream's media
));
```

> 🧠 Lesson — **two id worlds.** Stream uses the CID (`default:erp-call-42`).
> Our backend uses the numeric id (`42`). The code keeps both and uses the
> right one for each system. Mixing them up = 404s and silent no-ops.

---

## Step 8 — A joins the Stream media leg (but does NOT ring again)

Now A connects to Stream's media so that the **moment B accepts, audio is
already flowing**:

```dart
unawaited(streamEngine.join(
  streamCallCid: streamCallCid,
  isVideo: callType == ChatCallType.video,
  calleeUserIds: streamMemberIds,
  shouldRing: false,   // ◄── IMPORTANT: do NOT ring from the client
  isOutgoing: true,    // ◄── attach the "peer joined" fallback listener
));
```

Why `shouldRing: false`? Because the **backend already rang B** in Step 5. If
the client also rang, iOS would put A's `call.join()` into a "ringing flow" that
**cancels itself** when B accepts (`VideoError{connect cancelled}`) → A never
enters the call → silence. So: **server rings, client only joins.**

`isOutgoing: true` attaches a listener (`_attachPeerJoinedListener`) that fires
the first time a remote participant appears in the Stream call. That is A's
**backup signal** that B accepted, in case the STOMP `call.accept` message gets
lost (see Lesson 5).

A now sits in `outgoingRinging`, screen shows **"Calling…"**, waiting.

---

## 3.2 — What A's screen shows while waiting

The `VoiceCallPage` listens to `activeCallListenable` and maps state → UI:

| Brain state | Screen (`_CallStage`) | What A sees |
|---|---|---|
| `outgoingRinging` | `calling` | Avatar with a pulsing glow ring + "Calling…" |
| `connected` | `connected` | Static avatar + live timer `00:04` + waveform |
| `ended` | `ended` | "Call ended" (+ reason if busy/declined) then the page pops |

---

## 3.3 — The whole outgoing flow as a sequence diagram

```
 A (caller)        VoiceCallPage      CallSignaling      ChatTransport     Backend        Stream         B (callee)
   │ tap call          │                  │                  │              │              │               │
   ├──────────────────►│                  │                  │              │              │               │
   │                   │ initState        │                  │              │              │               │
   │                   ├─ ask mic ───────►│                  │              │              │               │
   │                   │ startOutgoing()  │                  │              │              │               │
   │                   ├─────────────────►│ set outgoingRinging             │              │               │
   │  "Calling…" ◄─────┤◄─ notify ────────┤                  │              │              │               │
   │                   │                  │ warmUp() ────────┼──────────────┼─────────────►│ (connect)     │
   │                   │                  │ sendCallInvite() │              │              │               │
   │                   │                  ├─────────────────►│ POST /calls  │              │               │
   │                   │                  │                  ├─────────────►│ create call  │               │
   │                   │                  │                  │              ├─ ring:true ─►│               │
   │                   │                  │                  │              │              ├─ VoIP push ──►│ ☎ RING
   │                   │                  │                  │◄─{id,cid} ───┤              │               │
   │                   │                  │◄─ response ──────┤              │              │               │
   │                   │                  │ swap id, save cid│              │              │               │
   │                   │                  │ join(shouldRing:false) ─────────┼─────────────►│ A in media    │
   │                   │                  │                  │              │              │  (waiting)    │
```

(Lesson 5 picks up when B taps Accept.)

---

## ✅ Check yourself

1. Who actually sends the ring to B — A's app or the backend? *(The backend,
   via Stream `getOrCreate(ring:true)`.)*
2. Why does A join with `shouldRing: false`? *(Backend already rang; client
   ringing would cancel A's join → no audio.)*
3. What are the two id "worlds" and who uses each? *(Stream CID for media;
   backend numeric id for accept/reject/end.)*
4. What is `targetIds` for? *(So the broadcast relay only rings the intended
   people, not everyone connected.)*

Next: **[Lesson 4 — Incoming call](04-incoming-call.md)** (how B's phone rings
in all three app states).
