# 📹 Video Call — Step by Step (start to end)

A video call is a **voice call + the camera**. This guide assumes you read
[`../VOICE_CALL/voice-call-step-by-step.md`](../VOICE_CALL/voice-call-step-by-step.md)
already. Here we focus on **what the camera adds**.

Two people: **A** = caller, **B** = callee.

> The full shared course (lessons 00–08) is in the parent folder
> **[`../`](../README.md)**.

---

## 0. The big idea (same as voice)

```
  Small commands ("call / accept / end")  ──►  OUR BACKEND
  The real sound + VIDEO                   ──►  STREAM (not our backend)
```

The only change from voice: Stream now also carries the **camera picture**, both
ways. Everything else is identical.

---

## 1. Configuration (one thing more than voice)

| Need | Voice | Video |
|------|-------|-------|
| `stream_video_flutter` | ✅ | ✅ |
| Stream token | ✅ | ✅ |
| **Microphone** permission | ✅ | ✅ |
| **Camera** permission (`NSCameraUsageDescription`) | — | ✅ **extra** |
| Backend call endpoints | ✅ | ✅ |
| VoIP push + CallKit | ✅ | ✅ |

> 📹 A video call needs **mic AND camera**. That is the one configuration
> difference. In code: `ensureCallPermissions(needCamera: true)`.

---

## 2. The screen (this is where video really differs)

A video call uses **`VideoCallPage`** (`lib/features/chat/views/video_call_page.dart`).

```
  ┌───────────────────────────────────────────────┐
  │                                               │
  │        REMOTE VIDEO (the other person)        │  ← full screen
  │        fills the whole screen                 │
  │                                               │
  │                              ┌────────────┐   │
  │                              │ YOUR camera│   │  ← small picture-in-picture
  │                              │  (PiP)     │   │     (front camera, mirrored)
  │                              └────────────┘   │
  │                                               │
  │   🔇 Mute   📷 Camera   🔄 Flip   📞 End      │  ← controls (auto-hide after 3s)
  └───────────────────────────────────────────────┘
```

Video-only state in the code:
- `_cameraOn` — turn your camera on/off (`call.setCameraEnabled(...)`).
- `_frontCamera` — front vs back camera (`call.flipCamera()`).
- `_remoteVideoOn` — is the other person's camera on? If off → show their avatar.

Two video renderers from Stream:
- **Remote** video = the other person, full screen.
- **Local** video = your own camera, in the small PiP box, mirrored (like a
  mirror, because it's the front camera).

> 🧠 Voice showed an avatar + waveform. Video replaces that with **two live
> camera feeds**. That is the visible difference.

---

## 3. The full flow (A video-calls B)

It is the **same 8 steps as voice**, with camera added at the permission step:

```
  A presses 📹
     │
     ▼
  [1] Open VideoCallPage(conversationId)
     │
     ▼
  [2] Ask MIC + CAMERA permission  → ensureCallPermissions(needCamera: true)
     │
     ▼
  [3] startOutgoing(type: VIDEO)  → state = outgoingRinging  → "Calling…"
     │
     ▼
  [4] POST /api/v1/chats/conversations/{id}/calls   (backend rings B)
     │
     ▼
  [5] B's phone RINGS (same 4 phone states as voice)
     │
     ▼
  [6] B taps Accept  → POST /api/v1/chats/calls/{id}/accept
     │
     ▼
  [7] CONNECTED → 🎙 sound + 📹 video flow → you SEE each other
     │
     ▼
  [8] End  → POST /api/v1/chats/calls/{id}/end  → both screens close
```

### The URL order — **exactly the same as voice**
```
1. GET  /api/v1/chats/calls/stream-token
2. POST /api/v1/chats/conversations/{id}/calls
3. POST /api/v1/chats/calls/{callId}/accept     · or /reject
4. POST /api/v1/chats/calls/{callId}/end
```

> ✅ Notice: the URLs do NOT change between voice and video. The **call type**
> (`voice` / `video`) is sent inside the call data, and the backend remembers it.
> When B accepts, the app reads `GET /chats/calls/{id}` to know it is a VIDEO
> call and opens `VideoCallPage` (not `VoiceCallPage`).

---

## 4. The video controls (what each button does)

| Button | Code | What happens |
|--------|------|--------------|
| 📷 Camera on/off | `_toggleCamera()` → `call.setCameraEnabled(...)` | stop/start sending your video |
| 🔄 Flip | `_flipCamera()` → `call.flipCamera()` | switch front ↔ back camera |
| 🔇 Mute | `setMicrophoneEnabled(false)` | stop sending your sound |
| 📞 End | `hangup()` | end the call for you |

If the user **denies the camera**, the call still connects — you just send no
video (your PiP shows "camera off"). Same idea as voice denying the mic: the
call rings either way.

---

## 5. The 4 phone states — same as voice

How B's phone rings (open / minimized / killed / killed+locked) is **identical**
to a voice call. The only difference is that after Accept, the app opens
`VideoCallPage` instead of `VoiceCallPage`.

> 📘 Full diagrams of the 4 states:
> [`../08-incoming-call-4-cases.md`](../08-incoming-call-4-cases.md).
> One thing to know: the call type is read from the **backend**
> (`GET /chats/calls/{id}` → `type: VIDEO`) — not from Stream — so a video call
> accepted from the lock screen correctly opens the video screen.

---

## 6. Video vs Voice — the difference table

| | 📹 Video call | 🎙️ Voice call |
|--|---------------|----------------|
| Screen | `VideoCallPage` | `VoiceCallPage` |
| Permission | mic **+ camera** | mic only |
| Call type | `ChatCallType.video` | `ChatCallType.voice` |
| What you see | two live camera feeds + PiP | avatar + waveform |
| Extra buttons | Camera on/off, Flip camera | — |
| Brain / transport / Stream engine | **same** | **same** |
| 4 phone states | **same** | **same** |
| URL order | **same** | **same** |

---

## ✅ Check yourself

1. What is the ONE configuration difference from a voice call? *(Camera
   permission — `ensureCallPermissions(needCamera: true)`.)*
2. Which screen opens for video? *(`VideoCallPage`.)*
3. Do the URLs change between voice and video? *(No — same 4 URLs; the type is
   in the call data.)*
4. How does the app know an accepted call is video, not voice? *(It reads
   `GET /chats/calls/{id}` → `type: VIDEO` from the backend.)*

You now understand both voice and video calls. 🎉
For the deepest detail (5 layers, 4-case diagrams), see the parent
[`../README.md`](../README.md).
