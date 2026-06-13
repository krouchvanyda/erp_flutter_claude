# Call Test Plan — A ↔ B (two physical devices)

Manual verification checklist for the Chat call flows (Module 10).
Run each row on **real** devices (call push + the native incoming-call screen
do **not** work on a simulator/emulator).

Mark each sub-case: ✅ pass · ❌ fail · ⬜ not run yet.
For any ❌, save the log from **both** A and B around that moment.

This plan is split by platform — the **flows are the same**, but the push
transport and the confirming log lines differ:

| | iOS | Android |
|---|---|---|
| Call push | VoIP / PushKit → APNs (`apn`) | FCM high-priority data message |
| Incoming UI | native CallKit screen | `flutter_callkit_incoming` full-screen call notification |
| Killed/locked accept path | native CXCallObserver bridge (`AppDelegate`) | plugin `onEvent` (`Event.actionCall*`) |
| Capture killed/locked logs | **Console.app** (filter by app process) | **`adb logcat`** (filter the app) |
| `detached` on swipe-kill | unreliable (often skipped) | reliable task-removal → bridge hangs up active call |

> Keep each case a **separate single call**. Do not chain a 2nd call onto a
> just-declined B — that 2nd-call-to-killed-B path is a known backend
> presence-staleness issue tracked separately, not part of these flows.

---

# Part A — iOS

## Case 1 — A calls B · both **in-app (foreground)**

| Step | Expected (PASS) | Confirm — B | Confirm — A | Result |
|---|---|---|---|---|
| A calls B | B shows the **in-app** overlay (not native CallKit) | overlay "… is calling" | "Calling…" screen | ⬜ |
| B accepts | both land on the call page, timer runs both sides | `status=Connected` | `status=Connected` | ⬜ |
| A ends **or** B ends | **both** call pages close | call page pops | call page pops | ⬜ |

---

## Case 2 — A calls B · B **minimized**

| Step | Expected (PASS) | Confirm | Result |
|---|---|---|---|
| A calls B | B gets the **native CallKit** ring | CallKit screen shows | ⬜ |
| B accepts | both connect, timer runs | `status=Connected` both sides | ⬜ |
| After accept, **B ends** | A ends too | A: `call.hangup` → page pops | ⬜ |
| (Re-test) A or B **rejects** | call ends both sides | reject → `POST /reject OK`, A stops ringing | ⬜ |

---

## Case 3 — A calls B · B **killed**

| Step | Expected (PASS) | Confirm | Result |
|---|---|---|---|
| A calls B | B gets native CallKit ring (app cold-starts) | CallKit screen | ⬜ |
| B accepts | both connect | B: `notifyIncomingCallAnswered` → `POST /accept`; both `status=Connected` | ⬜ |
| After accept, **B ends** | A ends too | A: page pops | ⬜ |
| (Re-test) **reject** | A stops ringing | B: `native End … direct reject POST … /reject OK` | ⬜ |

---

## Case 4 — A calls B · B **killed + screen locked**

| Step | Expected (PASS) | Confirm | Result |
|---|---|---|---|
| A calls B | native CallKit ring on the lock screen | ring on locked screen | ⬜ |
| B accepts | both connect (native screen; no in-app UI on lock) | `status=Connected` both sides | ⬜ |
| After accept, **B ends** | A ends too | A: page pops | ⬜ |
| (Re-test) **reject** | A stops ringing | B: `direct reject POST … /reject OK` | ⬜ |

---

## Case 5 — A calls B · B **doesn't answer → timeout**

Nobody taps End. Both sides auto-close **together at ~60 s**, server-driven.

| Step | Expected (PASS) | Confirm | Result |
|---|---|---|---|
| A calls, B ignores | at ~60 s **both** A and B close at the same time; logged as missed | A: "Calling…" closes; B: ring clears; call status `MISSED` / `NO_ANSWER` both sides | ⬜ |

**How the 60 s works (for reference):**
- Stream server ring settings = 60 s (`autoCancelTimeout` / `autoRejectTimeout`
  / `missedCallTimeout`) in `stream_call_engine.dart` → at 60 s Stream
  broadcasts `call.ended` to **both** devices simultaneously.
- Local backup timers (only fire if the server event is lost):
  B (callee) 60 s, A (caller) 65 s — A is intentionally 5 s longer so the
  server's 60 s event wins on the normal path.

---

# Part B — Android

> Android delivers the call via an **FCM high-priority data message**;
> `flutter_callkit_incoming` renders the full-screen incoming-call
> notification. Accept / Decline / End come through the plugin's `onEvent`
> (`Event.actionCallAccept` / `actionCallDecline` / `actionCallEnded`) →
> `_handleAccept` / `_handleDecline` / `_handleHangup`. There is **no** iOS
> CXCallObserver / `direct reject` native bridge on Android.
> Capture killed/locked logs with **`adb logcat`** (filter the app).

## Case 1 — A calls B · both **in-app (foreground)**

| Step | Expected (PASS) | Confirm — B | Confirm — A | Result |
|---|---|---|---|---|
| A calls B | B shows the **in-app** overlay | overlay "… is calling" | "Calling…" screen | ⬜ |
| B accepts | both land on the call page, timer runs | `status=Connected` | `status=Connected` | ⬜ |
| A ends **or** B ends | **both** call pages close | call page pops | call page pops | ⬜ |

## Case 2 — A calls B · B **minimized**

| Step | Expected (PASS) | Confirm | Result |
|---|---|---|---|
| A calls B | B gets the full-screen **call notification** | notification ring shows | ⬜ |
| B accepts | both connect, timer runs | B: `event=Event.actionCallAccept` → `_handleAccept`; both `status=Connected` | ⬜ |
| After accept, **B ends** | A ends too | B: `event=Event.actionCallEnded`; A: `call.hangup` → page pops | ⬜ |
| (Re-test) A or B **rejects** | call ends both sides | B: `event=Event.actionCallDecline` → `POST /reject OK`; A stops ringing | ⬜ |

## Case 3 — A calls B · B **killed**

| Step | Expected (PASS) | Confirm | Result |
|---|---|---|---|
| A calls B | FCM wakes app → full-screen call notification | notification ring (app cold-starts) | ⬜ |
| B accepts | both connect | B: `_handleAccept` → `POST /accept`; both `status=Connected` | ⬜ |
| After accept, **B ends** | A ends too | A: page pops | ⬜ |
| (Re-test) **reject** | A stops ringing | B: `_handleDecline` → `POST /reject OK` | ⬜ |

## Case 4 — A calls B · B **killed + screen locked**

| Step | Expected (PASS) | Confirm | Result |
|---|---|---|---|
| A calls B | full-screen call notification over the lock screen | ring on locked screen | ⬜ |
| B accepts | both connect | B: `_handleAccept`; both `status=Connected` | ⬜ |
| After accept, **B ends** | A ends too | A: page pops | ⬜ |
| (Re-test) **reject** | A stops ringing | B: `_handleDecline` → `POST /reject OK` | ⬜ |

## Case 5 — A calls B · B **doesn't answer → timeout**

Nobody taps End. Both sides auto-close **together at ~60 s**, server-driven
(same Stream ring settings as iOS — see the iOS Case 5 reference above).

| Step | Expected (PASS) | Confirm | Result |
|---|---|---|---|
| A calls, B ignores | at ~60 s **both** A and B close at the same time; logged as missed | A: "Calling…" closes; B: ring clears; call status `MISSED` / `NO_ANSWER` both sides | ⬜ |

---

## Notes / capture tips
- iOS killed / locked B logs → **Console.app**, filter by app process.
- Android killed / locked B logs → **`adb logcat`**, filter the app.
- For ❌ rows, paste **both** A and B logs around the failing moment.
- The call **timeout (Case 5)** is server-driven for both platforms — 60 s
  Stream ring settings end A and B together.
- Known separate issue (NOT in this plan): a 2nd call to a **killed B**
  right after B declined call 1 — backend presence staleness; B is still
  treated ONLINE so call 2 routes as an in-app STOMP invite instead of an
  apn/FCM ring. Fix is server-side.
