# Lesson 1 — The Big Picture 🗺️

Before any code, you must understand **the idea**. A call looks like one thing
to the user, but inside it is **5 layers** working together.

---

## 1.1 — Why is a call hard?

A chat message is easy: you send text, the server saves it, the other phone
reads it later. No hurry.

A call is hard because:

- It must happen **right now** (real time). No "read it later".
- It needs **two-way live sound** (and video). That is heavy data.
- The other phone might be **open, minimized, or fully closed**.
- Both screens must always **agree** ("we are both in the call", "the call
  ended"). If they disagree, one person is stuck on a dead screen.

So we split the work into layers. Each layer has ONE job.

---

## 1.2 — The 5 layers (the core mental model)

```
        ┌─────────────────────────────────────────────────────────┐
        │  LAYER 1 — UI (the screens you see)                       │
        │  VoiceCallPage · VideoCallPage · IncomingCallOverlay      │
        │  "Show Calling… / Ringing… / 00:12 / End button"          │
        └───────────────┬─────────────────────────────────────────┘
                        │ tells / listens
        ┌───────────────▼─────────────────────────────────────────┐
        │  LAYER 2 — SIGNALING ("the brain")                        │
        │  CallSignalingService + ActiveCall + CallSignalState      │
        │  Decides: are we ringing? connected? ended? who is busy?  │
        └─────────┬───────────────────────────────┬───────────────┘
                  │ uses                           │ uses
   ┌──────────────▼────────────┐      ┌────────────▼────────────────┐
   │ LAYER 3 — TRANSPORT        │      │ LAYER 4 — MEDIA              │
   │ ChatTransport             │      │ StreamCallEngine             │
   │ • REST (dio)  → backend   │      │ wraps stream_video_flutter   │
   │ • WebSocket (STOMP)       │      │ (WebRTC). Carries the REAL   │
   │ "invite / accept / end"   │      │ voice + video.               │
   │ small text messages       │      │                              │
   └──────────────┬────────────┘      └────────────┬────────────────┘
                  │                                 │
        ┌─────────▼─────────────────────────────────▼───────────────┐
        │  LAYER 5 — NATIVE / PUSH (wakes a closed phone)            │
        │  CallKit (iOS ring screen) · APNs/FCM push                │
        │  callkit_event_handler.dart                               │
        └───────────────────────────────────────────────────────────┘
```

**Read it top to bottom:** You tap a button (Layer 1). The brain (Layer 2)
decides what to do. It sends small text commands through Transport (Layer 3)
and brings up real audio through Media (Layer 4). If the other phone is asleep,
Push (Layer 5) wakes it up.

---

## 1.3 — Two kinds of "messages" travel during a call

This is the **most important idea** in the whole system. Do not skip it.

There are **two completely separate channels**:

### A) Signaling messages — tiny text, "control" only
Examples: *"I am calling you"*, *"I accept"*, *"I hung up"*, *"I am busy"*.

These are small. They go through **Layer 3 (Transport)** = our backend, using:
- **REST** (normal HTTP) for actions we start: POST a new call, POST accept.
- **STOMP over WebSocket** for things the server *pushes* to us: "the other
  person accepted", "the other person hung up".

### B) Media — the actual sound and picture
This is heavy. It does **NOT** go through our backend. It goes through
**Layer 4 (Stream / WebRTC)**, a specialist company built only for live media.

```
   Signaling (small text)              Media (heavy audio/video)
   YOU ──► our backend ──► PEER        YOU ◄════ Stream SFU ════► PEER
       "invite / accept / end"             real voice + video
```

> 🧠 **Remember:** Our backend never carries your voice. It only carries
> *commands about* the call. The voice rides on Stream. This separation is how
> almost every real calling app (WhatsApp, Telegram, FaceTime) is built.

---

## 1.4 — Who is "Stream"?

`Stream` (the company, package `stream_video_flutter`) gives us:
- A ready-made **WebRTC** media system (so we don't build audio plumbing).
- An **SFU** = a smart server in the middle that receives each person's audio
  and sends it to the others. (You don't connect phone-to-phone directly; you
  both connect to the SFU.)
- A **ring push**: Stream can send a special wake-up push to the other phone so
  iOS shows the native green "incoming call" screen, even if the app is closed.

We talk to Stream using a short-lived **token** that our backend gives us
(see Lesson 2).

---

## 1.5 — The state machine (the brain's "mood")

The brain (`CallSignalingService`) always keeps the call in exactly **one
state**. In the code this is the enum `CallSignalState`:

```
   idle ──► outgoingRinging ──► connected ──► ended ──► (back to idle)
     │                            ▲
     └────► incomingRinging ──────┘
```

| State | Meaning (plain words) |
|-------|-----------------------|
| `idle` | No call. Nothing happening. |
| `outgoingRinging` | I pressed Call. I am waiting for you to pick up. |
| `incomingRinging` | You are calling me. My phone is ringing. |
| `connected` | We are both in. Audio/video is flowing. Timer is running. |
| `ended` | Someone hung up / rejected / timed out. Clean up now. |

The whole rest of this guide is just: **how do we move from one box to the
next box, and keep BOTH phones moving together?**

The data for the current call lives in one object called `ActiveCall` (callId,
who is the peer, voice or video, the state, when it started, etc.). The UI
watches `activeCallListenable` — a `ValueNotifier<ActiveCall?>` — so the screen
updates the instant the state changes.

---

## 1.6 — Glossary (keep this open)

| Word | Simple meaning |
|------|----------------|
| **Signaling** | Sending small control messages ("call", "accept", "hang up"). NOT the voice. |
| **Media** | The real voice + video data. |
| **WebRTC** | The technology that moves live media between devices. |
| **Stream** | The company/SDK that gives us WebRTC + an SFU + ring push. |
| **SFU** | A media server in the middle. Everyone connects to it, it mixes/routes. |
| **STOMP** | A simple messaging format that runs on top of a WebSocket. We use it for server→app pushes. |
| **WebSocket** | An always-open 2-way pipe between app and server (unlike normal HTTP which opens, asks, closes). |
| **REST** | Normal HTTP requests (GET/POST). We use it for actions the app starts. |
| **CallKit** | Apple's system for showing a native call screen + ring, even when the app is closed. |
| **APNs** | Apple Push Notification service. iOS's way to wake an app. |
| **FCM** | Firebase Cloud Messaging. Android's way to wake an app (and a router for some pushes). |
| **VoIP push** | A special high-priority push made only for calls. It can wake a fully-closed app. |
| **Token** | A short signed string that proves who you are to Stream. |
| **CID** | "Call ID" in Stream's format, like `default:erp-call-42`. |
| **Foreground / Background / Killed** | App open & on screen / app minimized / app fully closed. |

---

## ✅ Check yourself

Before Lesson 2, you should be able to answer:

1. Does your **voice** travel through our backend? *(No — through Stream.)*
2. What travels through our backend then? *(Small signaling commands.)*
3. Name the 5 states of a call. *(idle, outgoingRinging, incomingRinging,
   connected, ended.)*
4. Which layer wakes a closed phone? *(Layer 5 — Native/Push, via VoIP push.)*

If yes — go to **[Lesson 2: Configuration](02-configuration.md)**.
