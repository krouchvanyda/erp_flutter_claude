# 🎙️ Voice Call — Step by Step (start to end)

This is the **whole voice call**, from pressing the button to hanging up.
Simple words. Numbered steps. Diagrams you can read in any editor.

Two people: **A** = caller (you), **B** = callee (the other person).

> This is the voice-only view. The full shared course (lessons 00–08) is in the
> parent folder **[`../`](../README.md)**.

---

## 0. The big idea (30 seconds)

```
  Small commands ("call / accept / end")  ──►  go through OUR BACKEND
  The real voice (sound)                   ──►  goes through STREAM (not our backend)
```

Your **voice never touches our backend**. Our backend only carries the
*commands*. Stream carries the *sound*. Remember this and everything is easy.

---

## 1. What you set up first (configuration)

For a voice call you need:

| Need | Why |
|------|-----|
| `stream_video_flutter` | carries the voice (WebRTC + a media server) |
| A Stream token from `GET /chats/calls/stream-token` | proves who you are to Stream |
| **Microphone** permission (`NSMicrophoneUsageDescription`) | a call needs the mic |
| Backend call endpoints | start / accept / reject / end the call |
| VoIP push (APNs) + CallKit | ring the phone when the app is closed |

> 🎙️ A voice call needs the **microphone only**. (Video adds the camera.)

---

## 2. The screen

A voice call uses one screen: **`VoiceCallPage`**
(`lib/features/chat/views/voice_call_page.dart`).

It has 4 looks (called `_CallStage`):

```
  calling    → pulsing avatar + "Calling…"          (A is waiting)
  ringing    → "Ringing…"                            (the other phone is ringing)
  connected  → avatar + live timer 00:12 + waveform  (talking)
  ended      → "Call ended"                          (then the screen closes)
```

Controls while connected: **Mute**, **Speaker** (on by default), **End**.
There is **no camera, no video** — just sound.

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
  [3] startOutgoing(type: voice)  → state = outgoingRinging  → UI "Calling…"
     │
     ▼
  [4] POST /api/v1/chats/conversations/{id}/calls     ← create the call
     │           (backend ALSO tells Stream to RING B)
     ▼
  [5] B's phone RINGS  (see section 5 for the 4 phone states)
     │
     ▼
  [6] B taps Accept  → POST /api/v1/chats/calls/{id}/accept
     │
     ▼
  [7] Both become CONNECTED  → 🎙 Stream carries the voice → timers tick
     │
     ▼
  [8] Someone taps End  → POST /api/v1/chats/calls/{id}/end  → both screens close
```

### The URL order (memorize this)
```
1. GET  /api/v1/chats/calls/stream-token        (build Stream client)
2. POST /api/v1/chats/conversations/{id}/calls  (start the call + ring B)
3. POST /api/v1/chats/calls/{callId}/accept     (B picks up)   · or /reject
4. POST /api/v1/chats/calls/{callId}/end        (hang up)
```

---

## 4. Who does what (the layers)

```
  VoiceCallPage  ── the screen you see (Calling… / timer / End)
       │
  CallSignalingService  ── the BRAIN: ringing? connected? ended?
       │            (startOutgoing · acceptIncoming · hangup)
       ├───────────────┐
  ChatTransport     StreamCallEngine
  (REST + WebSocket   (carries the VOICE
   to our backend)     via Stream/WebRTC)
```

- **Brain** file: `call_signaling_service.dart`
- **Transport** file: `chat_transport.dart` (→ `chats_remote_data_source.dart` for URLs)
- **Voice media** file: `stream_call_engine.dart`

---

## 5. The 4 phone states (how B's phone rings)

A voice call rings differently depending on B's app:

```
  1. App OPEN (foreground)   → in-app popup  (IncomingCallOverlay)
  2. App MINIMIZED           → native CallKit ring (VoIP push)
  3. App KILLED              → native CallKit ring (push wakes the app)
  4. App KILLED + LOCKED     → native CallKit ring over the lock screen
```

All four end the same way: **Accept → connected → 🎙 voice flows**.

> 📘 The full diagrams for these 4 states are in
> [`../08-incoming-call-4-cases.md`](../08-incoming-call-4-cases.md).
> They apply to voice calls exactly as drawn (voice = mic only).

---

## 6. Connect & end (the details that matter)

- **A learns B accepted** two ways (so A is never stuck on "Calling…"):
  1. the backend pushes `call.accept` over WebSocket, OR
  2. Stream tells A "a person joined the audio" (backup).
- **iOS sound:** when B accepts from the lock screen, CallKit owns the audio.
  The engine re-asserts the route + bounces the mic so **both sides actually
  hear** each other.
- **End:** `hangup()` → `POST /end` + Stream `leave()`. The peer learns via
  `call.hangup` (WebSocket) or Stream "remote left". Both screens write a call
  log + an inbox summary like `📞 Voice call · 5:23`, then close.

---

## 7. Voice vs Video — what is the SAME, what is DIFFERENT

| | 🎙️ Voice call | 📹 Video call |
|--|---------------|---------------|
| Screen | `VoiceCallPage` | `VideoCallPage` |
| Permission | **microphone** | **microphone + camera** |
| Call type | `ChatCallType.voice` | `ChatCallType.video` |
| Extra UI | waveform + speaker | camera preview, flip camera, picture-in-picture |
| Brain / transport / Stream engine | **same** | **same** |
| 4 phone states | **same** | **same** |
| URL order | **same** | **same** |

> 🧠 **Big lesson:** video is just voice **plus the camera**. If you understand
> the voice call, you already understand 90% of the video call. The video
> extras are in the [`../VIDEO_CALL`](../VIDEO_CALL) folder.

---

## ✅ Check yourself

1. Which permission does a voice call need? *(Microphone only.)*
2. Which screen class is it? *(`VoiceCallPage`.)*
3. Does your voice go through our backend? *(No — through Stream.)*
4. Name the 4 URLs in order. *(stream-token → calls → accept → end.)*

Next: open the **[`../VIDEO_CALL`](../VIDEO_CALL)** folder to see what the camera
adds. 📹
