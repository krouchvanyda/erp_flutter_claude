# Lesson 7 — Apply This To Another Project 🚀

You now understand the call. This lesson is the **recipe** to rebuild it
somewhere else. Follow the order. Each step says *what* and *why*.

---

## 7.1 — Decide your media provider first

This project uses **Stream** (`stream_video_flutter`). You could also use
Agora, Twilio, LiveKit, or raw `flutter_webrtc` + your own signaling server.
The **shape** of the system stays the same; only Layer 4 (Media) changes.

Pick based on:

| If you want… | Use |
|---|---|
| Fastest setup, ring push included, managed SFU | **Stream** (what you learned). Paid for iOS VoIP. |
| Open-source, self-hosted SFU | **LiveKit** |
| Full control, no SFU, small scale (1:1) | **flutter_webrtc** + your own STUN/TURN + signaling |

> 🧠 Everything in Lessons 1–6 except the inside of `StreamCallEngine` is
> provider-agnostic. Keep the wrapper boundary: the rest of the app should only
> call `engine.join()`, `engine.leave()`, `engine.accept()` — never the SDK
> directly.

---

## 7.2 — The minimum backend contract

Your server must provide these (names can differ; the roles cannot):

```
GET  /calls/stream-token          → { apiKey, token, userId }   (media auth)
POST /conversations/{id}/calls    → create call + RING the callee; return { id, mediaCid }
POST /calls/{id}/accept
POST /calls/{id}/reject
POST /calls/{id}/end
GET  /calls/{id}                  → current truth (type, status)  ← reconcile/fallback

WebSocket (STOMP or socket.io or raw):
  push to callee:  call.invite
  push to caller:  call.accept, call.reject
  push to both:    call.hangup
```

> 🧠 The single most important backend rule you learned: **the server fires the
> ring** (via the media provider's `getOrCreate(ring:true)` or equivalent), not
> the caller's app. This is what makes ringing reliable and able to wake a
> closed phone.

---

## 7.3 — Build the layers in this order

Do not build the pretty call screen first. Build from the inside out:

```
 1. Transport   — get REST + WebSocket talking to your backend. Log every event.
 2. Media engine wrapper — join/leave a hardcoded call id; confirm you hear audio.
 3. Signaling   — the state machine (idle→ringing→connected→ended) + ActiveCall.
 4. UI          — call page + incoming overlay, driven ONLY by the signaling state.
 5. Push/native — VoIP push + CallKit for background/killed (do this LAST).
```

Why this order? Because each layer can be tested alone. If you build the UI
first you have nothing to drive it. If you build push first you can't even
verify a basic call.

---

## 7.4 — Copy these specific design decisions (they prevent real bugs)

These are the hard-won lessons baked into this codebase. Reuse them:

1. **One state machine, one `ActiveCall` object, exposed via a `ValueNotifier`.**
   Never let the UI hold its own copy of "are we connected?". The UI only reads
   the notifier. (Avoids the two screens disagreeing.)

2. **Optimistic UI**: flip to "Calling…" instantly; do network work in the
   background. Roll back to `ended` on failure.

3. **Two ids**: media-provider CID vs your backend numeric id. Keep both; use
   the right one per system.

4. **Targeted delivery (`targetIds`)**: if your push/relay is broadcast, every
   client must verify "is this addressed to me?" before reacting.

5. **Two signals for every important transition**:
   - Accept: your `call.accept` push **AND** the media layer's "peer joined".
   - End: your `call.hangup` push **AND** the media layer's "remote left".
   Plus a polling fallback (`GET /calls/{id}`) for when both pushes fail.

6. **Funnel all incoming sources into one handler** (`handleIncomingFromPush`).
   Foreground WS, background push, killed isolate — one code path.

7. **Open the next screen before the state change that closes the current one**
   (push call page, then accept).

8. **Distinguish transient vs definitive end reasons.** Settle-guard only the
   flaky "disconnected"; act immediately on "remote left".

9. **Idempotent + dedupe everything.** The same invite can arrive twice (WS +
   push). The same accept POST can fire twice. Make them harmless.

10. **Always write the call log + a final state**, even on missed/failed calls,
    so history and the inbox are never wrong.

11. **Design for the 4 callee states, and escalate safety nets per state.** A
    call *in* behaves differently depending on the callee's app:
    `foreground → minimized → killed → killed+locked`. The harder the state, the
    more nets you add. Plan for all four from day one — don't bolt them on later.
    (Full diagrams: see **[Lesson 8](08-incoming-call-4-cases.md)**.)

    | State | Ring source | Extra net it needs |
    |---|---|---|
    | foreground | in-app overlay (suppress the native ring) | none |
    | minimized | native CallKit (push) | poll backend for caller-cancel |
    | killed | native CallKit (push cold-starts isolate) | accept-early, recover lost accept event, global navigator key |
    | killed + locked | native CallKit over lock screen | re-assert audio on CallKit activation, native "report ended" to dismiss the ring |

12. **Suppress your in-app ring when the native call screen is showing (and vice
    versa).** Foreground = in-app overlay only; background/killed = native
    CallKit only. Never let both ring at once.

13. **A backgrounded/locked callee has no live socket — so POLL.** It can't
    *hear* a "caller cancelled" over WebSocket. A small REST poll
    (`GET /calls/{id}`) lets it dismiss its own ring. (Here:
    `watchBackgroundRingForCancel`.)

14. **On a killed-app cold-start, tell the backend "accepted" EARLY and
    decoupled.** Don't make the caller wait for the callee's full startup. Fire
    `POST /accept` the instant the user taps Accept, separate from the slow
    join/render flow. (Here: `notifyBackendAcceptEarly`.) Cold starts also race
    the accept *event* — have a recovery path if it's lost, and push the call
    screen through a **global navigator key** (the overlay can't reach the router
    mid-cold-start).

---

## 7.5 — The iOS-specific gotchas (Layer 5)

iOS is where most of the pain lives. When you get to push/native:

- **VoIP push entitlement + a paid media plan** are required for a closed app
  to ring. There is no free workaround.
- **APNs provider environment must match your build** (sandbox vs production),
  or the ring silently never arrives.
- **Audio session ownership**: if you accept from your own UI (not CallKit's),
  *you* must set the `AVAudioSession` to `playAndRecord` before media starts,
  and re-assert the route after the media engine comes up. If you accept from
  CallKit's UI, CallKit owns the session and you re-assert when it activates.
- **Prime the WebRTC audio event channel at the very start of `main()`** to
  avoid an `EXC_BAD_ACCESS` crash the instant the mic turns on during cold
  start (project memory: "Stream WebRTC interruption crash").
- **Background mode "Voice over IP"** must be enabled in the iOS project.
- **CallKit owns the audio session on a locked/native accept.** It activates its
  session a beat *after* your `join()`, which resets WebRTC's audio unit → both
  sides go silent. Re-assert the route **and bounce the mic off→on** when CallKit
  signals activation (here: `onCallKitAudioSessionActivated`). Easy to miss
  because it only breaks on the locked-screen path.
- **A normal "end call" cannot dismiss a PushKit incoming-call screen.** To
  remove the native ring (e.g. caller cancelled while the callee is locked) you
  must call the native `reportCall(endedAt:)` — a `CXEndCallAction` won't do it.
- **Don't blanket-guard "call ended" events.** Settle-guard only the *transient*
  disconnect (a brief media-setup blip); act immediately on *definitive* ends
  (remote left). Guarding all of them strands the callee on "Connected" forever
  when they accept from the lock screen and the caller hangs up within ~2s.

> 📌 In THIS repo the rule is: call code is iOS-only and additive (`Platform.isIOS`
> guards, never touch Android). In a fresh project you won't need that
> constraint — but you WILL still write platform-specific audio/push code.

---

## 7.6 — A tiny "hello call" you can build to learn by doing

The smallest thing that proves you understand it:

1. Two test users, A and B, both logged in (so both have a Stream token).
2. A hardcoded conversation id.
3. A "Call" button → `startOutgoing`. B's app open (foreground only — skip push
   at first).
4. B's `IncomingCallOverlay` shows → Accept → both hear audio.
5. End → both screens close.

If you can do that with **no push, no CallKit, foreground only**, you have the
core. Then add background (CallKit + VoIP push) as the final, hardest layer.

**Then test all 4 callee states in order** (see [Lesson 8](08-incoming-call-4-cases.md)):
foreground → minimized → killed → killed+locked. Each one exposes a different
bug class (suppress double-ring → cancel poll → cold-start accept race → locked
audio + ring dismiss). If all four work, your call system is production-grade.

---

## 7.7 — Final mental model (say it out loud)

> "The UI shows whatever the **signaling state** says. The signaling state
> changes from **two sources**: my own actions (start/accept/hangup) and
> **events from the peer** (over the backend WebSocket, or observed in the media
> layer). My backend carries **commands**; **Stream** carries the **voice**. To
> ring a closed phone, the **server** sends a **VoIP push** that **CallKit**
> turns into a native ring."

If you can say that without looking — you've got it. 🎉

---

## Where to go next in the real code

Open these in order and match them to the lessons:

1. `lib/features/chat/views/voice_call_page.dart` — Lesson 3 & 5 (UI + stages).
2. `lib/features/chat/repositories/call_signaling_service.dart` — the brain.
   Read `startOutgoing`, `handleIncomingFromPush`, `hangup`,
   `_handleStreamPeerJoined`, `_handleStreamCallEnded`.
3. `lib/features/chat/repositories/stream_call_engine.dart` — Layer 4.
   Read `_ensureClientImpl` (token + client build) and `join`.
4. `lib/features/chat/repositories/chat_transport.dart` — Layer 3.
   Read the STOMP subscribe code and the `sendCall*` methods.
5. `lib/features/chat/widgets/incoming_call_overlay.dart` — Lesson 4 & 5 (Accept).
6. `lib/features/chat/repositories/callkit_event_handler.dart` — Layer 5.

Take it slow. Read one method, find which lesson it matches, then read the next.
You already have the map — now you're just filling in the streets. 🗺️
