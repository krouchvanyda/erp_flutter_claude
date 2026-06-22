# 🤖📹 Android Video Call — Step by Step (start to end)

An Android video call is a **voice call + the camera**. This guide assumes you
read [`../VOICE_CALL/voice-call-step-by-step.md`](../VOICE_CALL/voice-call-step-by-step.md)
already. Here we focus on **what the camera adds**.

Two people: **A** = caller, **B** = callee.

---

## 0. The big idea (same as voice)

```
  Small commands ("call / accept / end")  ──►  OUR BACKEND
  The real sound + VIDEO                   ──►  STREAM (not our backend)
```

The only change from voice: Stream also carries the **camera picture**, both
ways. If B's phone is closed, **FCM** still rings it (same as voice).

---

## 1. Configuration (one thing more than voice)

| Need | Voice | Video |
|------|-------|-------|
| `stream_video_flutter` | ✅ | ✅ |
| Stream token | ✅ | ✅ |
| **`RECORD_AUDIO`** (manifest) | ✅ | ✅ |
| **`CAMERA`** (manifest) | — | ✅ **extra** |
| Backend call endpoints | ✅ | ✅ |
| FCM + erp_callkit ring | ✅ | ✅ |

> 📹 A video call needs **mic AND camera**. In code:
> `ensureCallPermissions(needCamera: true)`. In the manifest, add
> `<uses-permission android:name="android.permission.CAMERA"/>`.

---

## 2. The screen (where video really differs)

A video call uses **`VideoCallPage`** (`lib/features/chat/views/video_call_page.dart`).

```
  ┌───────────────────────────────────────────────┐
  │        REMOTE VIDEO (the other person)        │  ← full screen
  │                              ┌────────────┐   │
  │                              │ YOUR camera│   │  ← picture-in-picture
  │                              │  (PiP)     │   │     (front, mirrored)
  │                              └────────────┘   │
  │   🔇 Mute   📷 Camera   🔄 Flip   📞 End      │  ← auto-hide after 3s
  └───────────────────────────────────────────────┘
```

Video-only state:
- `_cameraOn` → `call.setCameraEnabled(...)`
- `_frontCamera` → `call.flipCamera()`
- `_remoteVideoOn` → if the other camera is off, show their avatar.

---

## 3. The full flow (A video-calls B)

Same 8 steps as voice, with camera added at the permission step:

```
  A presses 📹
     ▼
  [1] Open VideoCallPage(conversationId)
     ▼
  [2] Ask MIC + CAMERA  → ensureCallPermissions(needCamera: true)
     ▼
  [3] startOutgoing(type: VIDEO) → outgoingRinging → "Calling…"
     ▼
  [4] POST /api/v1/chats/conversations/{id}/calls   (backend rings B)
     ▼
  [5] B's phone RINGS (app open → overlay · closed → FCM ring)
     ▼
  [6] B taps Accept → POST /api/v1/chats/calls/{id}/accept
     ▼
  [7] CONNECTED → 🎙 sound + 📹 video → you SEE each other
     ▼
  [8] End → POST /api/v1/chats/calls/{id}/end → both screens close
```

### The URL order — same as voice (and same as iOS)
```
1. GET  /api/v1/chats/calls/stream-token
2. POST /api/v1/chats/conversations/{id}/calls
3. POST /api/v1/chats/calls/{callId}/accept   · or /reject
4. POST /api/v1/chats/calls/{callId}/end
```

> ✅ The URLs do NOT change between voice and video. The **call type** is in the
> call data; the backend remembers it. When B accepts, the app reads
> `GET /chats/calls/{id}` → `type: VIDEO` and opens `VideoCallPage`.

---

## 4. The video controls

| Button | Code | What happens |
|--------|------|--------------|
| 📷 Camera on/off | `_toggleCamera()` → `call.setCameraEnabled(...)` | stop/start your video |
| 🔄 Flip | `_flipCamera()` → `call.flipCamera()` | front ↔ back camera |
| 🔇 Mute | `setMicrophoneEnabled(false)` | stop your sound |
| 📞 End | `hangup()` | end the call for you |

If the user **denies the camera**, the call still connects — you just send no
video (PiP shows "camera off").

---

## 5. The 4 phone states — same as voice

How B's phone rings (open / minimized / killed / killed+locked) is **identical**
to a voice call on Android. The only difference is that after Accept, the app
opens `VideoCallPage` instead of `VoiceCallPage`.

> 📘 Full Android diagrams:
> [`../02-incoming-call-4-cases-android.md`](../02-incoming-call-4-cases-android.md).

---

## 6. Video vs Voice — the difference table

| | 📹 Video | 🎙️ Voice |
|--|----------|----------|
| Screen | `VideoCallPage` | `VoiceCallPage` |
| Permission (manifest) | `RECORD_AUDIO` + `CAMERA` | `RECORD_AUDIO` |
| Call type | `ChatCallType.video` | `ChatCallType.voice` |
| What you see | two live camera feeds + PiP | avatar + waveform |
| Extra buttons | Camera on/off, Flip | — |
| Brain / transport / Stream / FCM ring | **same** | **same** |
| URL order | **same** | **same** |

---

## ✅ Check yourself

1. What is the ONE config difference from voice? *(`CAMERA` permission /
   `ensureCallPermissions(needCamera: true)`.)*
2. Which screen opens for video? *(`VideoCallPage`.)*
3. Do the URLs change between voice and video? *(No — same 4 URLs.)*
4. How does the app know an accepted call is video? *(It reads
   `GET /chats/calls/{id}` → `type: VIDEO`.)*

You now understand Android voice **and** video calls. 🎉

⬅ Back to the [Android index](../README.md).
