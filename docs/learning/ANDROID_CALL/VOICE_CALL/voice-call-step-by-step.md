# 🤖🎙️ Android Voice Call — Step by Step (start to end)

The **whole voice call on Android**, from pressing the button to hanging up.
Simple words. Numbered steps. Diagrams you can read in any editor.

Two people: **A** = caller (you), **B** = callee.

> Android and iOS voice calls are the **same** until the phone is *closed* —
> then Android rings with **FCM** (see the parent [`../`](../README.md) folder).

---

## 0. The big idea (same on every platform)

```
  Small commands ("call / accept / end")  ──►  OUR BACKEND
  The real voice (sound)                   ──►  STREAM (not our backend)
```

Your **voice never touches our backend**. Stream carries the sound.

---

## 1. What you set up first (Android voice)

| Need | Why |
|------|-----|
| `stream_video_flutter` | carries the voice |
| Stream token (`GET /chats/calls/stream-token`) | proves who you are to Stream |
| **`RECORD_AUDIO`** permission (AndroidManifest) | a voice call needs the mic |
| Backend call endpoints | start / accept / reject / end |
| **FCM** + `erp_callkit` | ring the phone when the app is closed |

> 🍏 iOS uses `NSMicrophoneUsageDescription` in Info.plist. 🤖 Android uses
> `<uses-permission android:name="android.permission.RECORD_AUDIO"/>` in the
> manifest. Same idea, different place.

---

## 2. The screen

A voice call uses **`VoiceCallPage`** (`lib/features/chat/views/voice_call_page.dart`).

```
  calling    → pulsing avatar + "Calling…"
  ringing    → "Ringing…"
  connected  → avatar + live timer 00:12 + waveform
  ended      → "Call ended" → screen closes
```

Controls: **Mute**, **Speaker** (on by default), **End**. No camera, no video.

---

## 3. The full flow (A calls B)

```
  A presses 📞
     │
     ▼
  [1] Open VoiceCallPage(conversationId)
     │
     ▼
  [2] Ask MICROPHONE permission  → ensureCallPermissions()
     │
     ▼
  [3] startOutgoing(type: voice) → state = outgoingRinging → "Calling…"
     │
     ▼
  [4] POST /api/v1/chats/conversations/{id}/calls   (backend rings B via Stream)
     │
     ▼
  [5] B's phone RINGS  (app open → overlay · app closed → FCM ring)
     │
     ▼
  [6] B taps Accept → POST /api/v1/chats/calls/{id}/accept
     │
     ▼
  [7] CONNECTED → 🎙 Stream carries the voice → timers tick
     │
     ▼
  [8] End → POST /api/v1/chats/calls/{id}/end → both screens close
```

### The URL order (same on iOS and Android)
```
1. GET  /api/v1/chats/calls/stream-token
2. POST /api/v1/chats/conversations/{id}/calls
3. POST /api/v1/chats/calls/{callId}/accept     · or /reject
4. POST /api/v1/chats/calls/{callId}/end
```

---

## 4. The 4 phone states (how B's phone rings on Android)

```
  1. App OPEN        → in-app popup (IncomingCallOverlay)
  2. App MINIMIZED   → FCM → erp_callkit full-screen ring
  3. App KILLED      → FCM cold-starts an isolate → ring
  4. App KILLED+LOCK → FCM ring + MainActivity shows over the lock screen
```

> 📘 Full Android diagrams for these 4 states:
> [`../02-incoming-call-4-cases-android.md`](../02-incoming-call-4-cases-android.md).
> They apply to a voice call exactly as drawn (voice = mic only).

---

## 5. Voice vs Video on Android — same vs different

| | 🎙️ Voice | 📹 Video |
|--|----------|----------|
| Screen | `VoiceCallPage` | `VideoCallPage` |
| Permission (manifest) | `RECORD_AUDIO` | `RECORD_AUDIO` **+ `CAMERA`** |
| Call type | `ChatCallType.voice` | `ChatCallType.video` |
| Extra UI | waveform + speaker | camera preview, flip, picture-in-picture |
| Brain / transport / Stream / FCM ring | **same** | **same** |
| URL order | **same** | **same** |

> 🧠 Video is just voice **+ the camera**. The video extras are in the
> [`../VIDEO_CALL`](../VIDEO_CALL) folder.

---

## ✅ Check yourself

1. Which manifest permission does an Android voice call need? *(`RECORD_AUDIO`.)*
2. Which screen class? *(`VoiceCallPage`.)*
3. What rings a *closed* Android phone? *(An FCM data message → erp_callkit.)*
4. Name the 4 URLs in order. *(stream-token → calls → accept → end.)*

Next: open **[`../VIDEO_CALL`](../VIDEO_CALL)** to see what the camera adds. 📹

⬅ Back to the [Android index](../README.md).
