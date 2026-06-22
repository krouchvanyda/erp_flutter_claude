# Lesson 5 — Connect & End (accept → audio → hang up) ✅📴

We left off: A is on "Calling…", B's phone is ringing. Now B taps **Accept**,
audio flows, and finally someone presses **End**.

---

## 5.1 — B taps Accept

Whatever path B used (in-app overlay, or native CallKit), the result is one
call into the brain:

```dart
await signaling.acceptIncoming();
```

But notice the **order** matters here (this fixed a real bug). The overlay does
this:

```dart
// incoming_call_overlay.dart — _handleAccept (simplified)
final nav = AppRouter.rootNavigatorKey.currentState;  // 1) grab the root navigator FIRST
nav.push(callPage);                                    // 2) push the call PAGE first
signaling.acceptIncoming();                            // 3) THEN fire accept (fire-and-forget)
```

Why push the page **before** accepting? Because `acceptIncoming()` flips the
state to `connected`, which instantly removes the overlay. If we waited for
accept to finish first, the overlay would already be gone and the
`context.mounted` check would swallow the navigation — the call page would never
open (bug fixed in slice 10.2.8 / 10.2.9).

> 🧠 Lesson — **open the destination before you change the state that unmounts
> the source.** The call page subscribes to the signaling service in its own
> `initState`, so it picks up the `connected` transition whether it lands during
> or after the push.

### What `acceptIncoming()` does
1. POST `/chats/calls/{id}/accept` (tell the backend B picked up).
2. Bring up B's Stream media leg — either by reusing the call prepared during
   the ring (`prepareIncoming`, Lesson 4) or by accepting + joining now.
3. Flip B's state to `connected` and start B's timer.

---

## 5.2 — How A learns that B accepted (two signals, belt + suspenders)

A is still on "Calling…". A needs to know B accepted, to flip to `connected`.
There are **two** ways A finds out — the code uses both so A is never stuck:

```
   Signal 1 (primary):  Backend broadcasts STOMP `call.accept`
                        on /topic/conversations/{id}/call
                        → A's ChatTransport → CallAcceptEvent → brain flips A to connected

   Signal 2 (backup):   Stream tells A "a remote participant joined your media"
                        → onStreamPeerJoined → _handleStreamPeerJoined()
                        → brain flips A to connected
```

Why two? Because Signal 1 can be **lost**: the backend's own 30s ring timer
might fire and close the row, or the broadcast might race a cold-start. If A
relied only on Signal 1, A would be stuck on "Calling…" forever even though B is
already talking. Signal 2 (the media layer actually seeing B arrive) is the
reliable fallback.

```dart
// call_signaling_service.dart
void _handleStreamPeerJoined() {
  final active = _active;
  if (active == null || active.state != CallSignalState.outgoingRinging) return;
  _setActive(active.copyWith(
    state: CallSignalState.connected,        // ◄── A flips to connected
    connectedAt: DateTime.now(),
  ));
}
```

There is also a third safety net on iOS — a **ringing heartbeat** that polls
`GET /chats/calls/{id}` while A is ringing, and flips A to connected if the
backend says `ANSWERED`. (From project memory: "iOS caller stuck Calling… after
accept".)

> 🧠 Lesson — **never trust a single 'success' message in a distributed
> system.** Have a primary signal AND an independent fallback that observes
> reality (here: "is the other person actually in the media call?").

---

## 5.3 — Now both are `connected` — audio flows

Once both phones are `connected`:

- Each `VoiceCallPage` shows a **live timer** (`_startTicker`) counting up.
- Stream's SFU carries the real microphone audio between A and B.
- The page applies the audio route (speaker on by default for voice).

On iOS there is careful audio handling so both sides actually **hear** each
other. These are the trickiest bugs in calling. The key ones, in plain words:

| iOS audio fix | Why it exists |
|---|---|
| `configureIosCallAudio()` sets the session to `playAndRecord` | Accepting from the in-app overlay (not CallKit's UI) means CallKit never sets up the audio session, so we must. Otherwise the mic unit fails the instant it starts. |
| `_reassertIosAudioRoute()` after join | WebRTC's audio module starts a beat late and resets the route; we re-apply it so output isn't silent. |
| `onCallKitAudioSessionActivated()` re-asserts + bounces the mic | When CallKit activates ITS session a moment after join, it resets WebRTC's unit → silence. We restart the mic (off→on) on the now-live session. |
| `_ensureMicPublishing()` forces the mic track on | Sometimes the SFU shows `publishesAudio=false`; we force-publish so the peer hears us. |

> 🧠 Lesson — you do not need to memorize these. The lesson is: **iOS call audio
> has many edge cases, and each fix targets one specific "no sound" situation.**
> When you build your own, expect to handle: who owns the audio session
> (CallKit vs you), and re-applying the route after the media engine starts.

> 🧠 Lesson — also note this project's media is driven by Stream end-to-end now;
> earlier slices (10.2.3) describe a "signalling-only stub" with no real audio.
> The comments in the code still mention that history — don't be confused, the
> live path uses real Stream media.

---

## 5.4 — Someone presses End

The `hangup()` method is the **canonical "this call is over"**. Both sides call
it when they tap End. Simplified:

```dart
Future<void> hangup({ ChatCallStatus finalStatus = ChatCallStatus.answered }) async {
  final active = _active;
  if (active == null) return;

  // iOS: if WE abandon a still-RINGING outgoing call, cancel Stream's ring
  // for everyone so B's CallKit screen actually disappears (a plain leave()
  // only drops our own leg; a minimized B would keep ringing for ~30s).
  if (Platform.isIOS && active.state == CallSignalState.outgoingRinging) {
    unawaited(streamEngine.cancelOutgoingRing());
  }

  // 1) Tell the peer over the wire. We stamp WHO hung up (hangerUpperId)
  //    so group calls know whether to end for everyone or just one person.
  transport.sendCallHangup(active.callId, hangerUpperId: settings.userId);
  //    → this does POST /chats/calls/{id}/end on the backend

  // 2) Update the call-log row with the final duration + status.
  await callLog.logEnded(id: logId, durationSeconds: duration, finalStatus: ...);

  // 3) Write a summary into the inbox tile ("📞 Voice call · 5:23").
  unawaited(_writeCallSummary(active, ...));

  // 4) Clear any native ring / Stream "ongoing call" notification.
  _clearNativeIncoming(active.callId);
  _clearAllCallNotifications();

  // 5) Flip to ended (UI shows "Call ended"), then drop _active after ~600ms
  //    so the page can animate the ended state before it pops itself.
  _setActive(active.copyWith(state: CallSignalState.ended));
  Future.delayed(const Duration(milliseconds: 600), () { _setActive(null); });
}
```

And the Stream side leaves the media call (`streamEngine.endActiveCall()` /
`leave()`), which frees the mic/camera and removes the "ongoing call"
notification.

---

## 5.5 — How the OTHER side learns the call ended

Same idea as accept — two signals:

```
   Signal 1: STOMP `call.hangup` → CallHangupEvent → brain flips peer to ended
   Signal 2: Stream `onStreamCallEnded` (remoteLeft) → _handleStreamCallEnded → ended
```

`_handleStreamCallEnded` has a subtle but important rule:

```dart
// Only the POSSIBLY-transient "disconnected" reason is settle-guarded
// (ignored if the call is < 2 seconds old — Stream sometimes blips during
// media setup). DEFINITIVE reasons (remoteLeft / reconnectFailed /
// incomingCleared) ALWAYS tear the call down, even within those 2 seconds.
```

Why? A real bug: B accepts from the lock screen, A hangs up immediately, Stream
fires a definitive `remoteLeft` inside the 2-second window. An earlier version
guarded ALL reasons and swallowed it → **B was stuck on "Connected" forever**.
The fix: only guard the flaky `disconnected` reason, never the definitive ones.

> 🧠 Lesson — **distinguish "maybe a glitch" from "definitely over."** Guard the
> glitchy signal; act immediately on the definite one.

### Group calls — who can end it for everyone?
- In a **direct (1:1)** call, either side ending ends the call. Simple.
- In a **group** call, one person tapping End should only make **them** leave —
  the others keep talking. So `CallHangupEvent` carries `hangerUpperId`, and a
  callee ignores a hangup that isn't from the original caller or themselves.
- The **caller** ending ends it for everyone (their bow-out is canonical).
- And if every callee leaves, the caller auto-ends (so they aren't left alone
  with a running timer) — tracked by the `_activeCallees` set.

---

## 5.6 — Full connect → end sequence

```
 A                  Backend/Stream                 B
 │ (outgoingRinging) │                              │ (incomingRinging, phone ringing)
 │                   │                              │ taps Accept
 │                   │◄── POST /accept ─────────────┤  acceptIncoming()
 │                   │── STOMP call.accept ────────►│  (B joins Stream media)
 │◄── call.accept ───┤                              │
 │  OR Stream peer-joined fallback                  │
 │ flip → connected  │                              │ flip → connected
 │ ⏱ timer starts    │      🎙 audio via SFU 🎙       │ ⏱ timer starts
 │ ...talking...     │                              │ ...talking...
 │ taps End          │                              │
 │── hangup() ──────►│ POST /end                    │
 │                   │── STOMP call.hangup ────────►│ flip → ended
 │ flip → ended      │   OR Stream remoteLeft       │ page pops
 │ page pops         │                              │
 │ log + inbox summary written on both sides        │
```

---

## ✅ Check yourself

1. Why does the overlay push the call page **before** calling
   `acceptIncoming()`? *(Accept flips to connected, which unmounts the overlay
   and would swallow the navigation.)*
2. Name A's two ways of learning B accepted. *(STOMP `call.accept`; Stream
   peer-joined fallback. Plus iOS ringing heartbeat.)*
3. Why is only the `disconnected` Stream reason settle-guarded? *(It can be a
   transient blip; the others are definitive ends that must never be swallowed.)*
4. In a group call, whose End ends it for everyone? *(The original caller's.
   A callee only leaves themselves.)*

Next: **[Lesson 6 — Flowcharts](06-flowcharts.md)** (all diagrams together) and
**[Lesson 7 — Apply to another project](07-apply-to-another-project.md)**.
