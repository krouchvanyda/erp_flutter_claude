# 📚 Learning: Voice & Video Calls — START HERE

Welcome! This is the **map** for learning how voice & video calls work in this
project. It is written for someone **new to calls**. Simple words. Many diagrams.

👉 **New here? Read this whole page first (3 minutes), then pick your path below.**

---

## 🧠 The 3 ideas you must never forget

1. **Two channels.** Small *commands* ("call / accept / end") go through **our
   backend**. The real *voice + video* goes through **Stream**. Your voice never
   touches our backend.
2. **The server rings, not the caller's app.** That is what lets a *closed* phone
   ring.
3. **One state, both phones agree.** A call is always in one state
   (`idle → ringing → connected → ended`). Every screen just shows that state.

If these make sense at the end, you have learned calls. ✅

---

## 🗺️ The folder map

```
learning/
├── README.md          ← you are here (the map)
│
├── IOS_CALL/          ← 🍏 the FULL course (iOS) + the SHARED concepts
│   │                     (this project is iOS-first, so the deep course lives here)
│   ├── 00-START-HERE  … 08-incoming-call-4-cases   (9 lessons)
│   ├── VOICE_CALL/    ← 🎙️ voice-only view
│   └── VIDEO_CALL/    ← 📹 video-only view
│
└── ANDROID_CALL/      ← 🤖 the Android DELTA (only what differs from iOS)
    ├── 00-START-HERE
    ├── 01-configuration-android
    ├── 02-incoming-call-4-cases-android
    ├── VOICE_CALL/    ← 🎙️ Android voice-only view
    └── VIDEO_CALL/    ← 📹 Android video-only view
```

> 🪞 **iOS and Android mirror each other.** Both have the same lesson shape and
> both have `VOICE_CALL/` + `VIDEO_CALL/` subfolders. iOS holds the deep shared
> course; Android holds the ring-layer delta.

> 💡 Why is the shared content inside `IOS_CALL`? Because ~90% of call code is
> **identical** on both platforms, and this project is **iOS-first**. So the
> deep lessons live in `IOS_CALL/` and apply to **both** platforms. `ANDROID_CALL/`
> only adds the parts that are different (how a *closed* phone rings).

---

## 🚦 Pick your path

### Path A — "I want to learn iOS calls" 🍏
Read **[`IOS_CALL/`](IOS_CALL/README.md)** from `00` to `08`, in order.
That's the complete course.

### Path B — "I want to learn Android calls" 🤖
1. First read the **shared** lessons in `IOS_CALL/` (they apply to Android too):
   `01 big-picture` → `03 outgoing` → `05 connect-and-end` → `06 flowcharts`.
2. Then read **[`ANDROID_CALL/`](ANDROID_CALL/README.md)** (`00 → 01 → 02`) for
   the Android ring layer (FCM + erp_callkit).

### Path C — "I just want voice, or just video" 🎙️📹
Pick your platform, then voice or video. (Video = voice + the camera. Read voice
first.)

| | 🎙️ Voice | 📹 Video |
|--|----------|----------|
| 🍏 iOS | [IOS_CALL/VOICE_CALL/](IOS_CALL/VOICE_CALL/README.md) | [IOS_CALL/VIDEO_CALL/](IOS_CALL/VIDEO_CALL/README.md) |
| 🤖 Android | [ANDROID_CALL/VOICE_CALL/](ANDROID_CALL/VOICE_CALL/README.md) | [ANDROID_CALL/VIDEO_CALL/](ANDROID_CALL/VIDEO_CALL/README.md) |

### Path D — "Only have 10 minutes" 🕐
Read this page + **[`IOS_CALL/01-big-picture.md`](IOS_CALL/01-big-picture.md)**.
That's the whole mental model.

---

## 🌍 What is SHARED vs PLATFORM-specific

This is the key to understanding both platforms without learning twice:

| Part of a call | iOS | Android | Same? |
|----------------|-----|---------|:----:|
| The call screens (`VoiceCallPage` / `VideoCallPage`) | ✅ | ✅ | 🌍 same |
| The brain / state machine (`CallSignalingService`) | ✅ | ✅ | 🌍 same |
| Backend commands + URLs (REST + STOMP) | ✅ | ✅ | 🌍 same |
| The voice/video media (Stream / WebRTC) | ✅ | ✅ | 🌍 same |
| Voice vs Video difference | ✅ | ✅ | 🌍 same |
| **Ringing a CLOSED phone** | APNs **VoIP** + CallKit | **FCM** + erp_callkit | 🔴 **different** |
| Lock-screen handling | CallKit (automatic) | `MainActivity.kt` | 🔴 **different** |
| Audio session on accept | CallKit owns it (re-assert) | Android manages it | 🔴 **different** |

> 🧠 **Everything is the same EXCEPT how a closed phone rings.** Learn the shared
> system once (in `IOS_CALL/`), then learn each platform's ring layer
> (`IOS_CALL/08` for iOS, `ANDROID_CALL/02` for Android).

---

## 📡 All call URLs (complete reference)

Base path for every REST URL below is `<apiBaseUrl>/api/v1`. These are the
**same on iOS and Android**.

### REST endpoints (HTTP — actions the app starts)

| # | Method + URL | When it fires | Returns |
|---|--------------|---------------|---------|
| 1 | `GET  /api/v1/chats/calls/stream-token` | building the Stream client | `{ apiKey, token, userId }` |
| 2 | `POST /api/v1/chats/conversations/{id}/calls` | I press Call (start + ring) | `{ id, streamCallCid, participants }` |
| 3 | `POST /api/v1/chats/calls/{callId}/accept` | I accept an incoming call | call DTO |
| 4 | `POST /api/v1/chats/calls/{callId}/reject` | I decline an incoming call | call DTO |
| 5 | `POST /api/v1/chats/calls/{callId}/end` | I hang up | call DTO |
| 6 | `GET  /api/v1/chats/calls/{callId}` | reconcile / "is it voice or video?" | call DTO |
| 7 | `GET  /api/v1/chats/calls?page=&pageSize=` | global call history + stale-call cleanup | list of calls |
| 8 | `GET  /api/v1/chats/conversations/{id}/calls` | per-conversation call history | list of calls |

> 🔢 The **happy-path order** is: **1 → 2 → 3 → 5** (token → start → accept →
> end). `reject` (4) replaces `accept` when declined; `GET` ones (6–8) are
> reconcile/history/fallback.

### WebSocket — STOMP (server → app pushes)

Socket URL: `<apiBaseUrl>/ws`. After connecting, the app subscribes to:

| Destination | Carries |
|-------------|---------|
| `/user/queue/calls` | call events meant just for me |
| `/user/queue/inbox` | new chat messages for me |
| `/topic/conversations/{id}/call` | this call's `call.invite` / `call.accept` / `call.reject` / `call.hangup` |
| `/topic/conversations/{id}` | chat messages for one conversation |
| `/topic/presence` | who is online / offline |

> 🤖 **Android note:** when the app is **closed**, there is no live WebSocket, so
> the ring arrives by **FCM** instead (payload keys `call_cid`, `caller_id`,
> `caller_name`). The REST URLs above are still used once the app is awake. See
> [`ANDROID_CALL/`](ANDROID_CALL/README.md).

---

## 📇 Tiny glossary (full one in `IOS_CALL/01-big-picture.md`)

| Word | Simple meaning |
|------|----------------|
| **Signaling** | Small control messages ("call/accept/end") — NOT the voice. |
| **Media** | The real voice + video. |
| **Stream** | The SDK that carries the media + sends the ring push. |
| **WebRTC** | The tech that moves live media between phones. |
| **STOMP / WebSocket** | Always-open pipe; the server pushes events to the app. |
| **CallKit** (iOS) | Apple's native call screen + ring (works when app is closed). |
| **FCM** (Android) | Firebase push; how Android wakes a closed app to ring. |
| **VoIP push** | A special push that can wake a fully-closed app to ring. |

---

## 📂 The real code (look while you read — same files on both platforms)

| Job | File |
|-----|------|
| Call screens (UI) | `lib/features/chat/views/voice_call_page.dart`, `video_call_page.dart` |
| Incoming-call popup | `lib/features/chat/widgets/incoming_call_overlay.dart` |
| The brain / state machine | `lib/features/chat/repositories/call_signaling_service.dart` |
| Backend (REST + WebSocket) | `lib/features/chat/repositories/chat_transport.dart` |
| Real audio/video (Stream) | `lib/features/chat/repositories/stream_call_engine.dart` |
| Native ring (iOS CallKit) | `lib/features/chat/repositories/callkit_event_handler.dart` |
| Native ring (Android FCM) | `lib/shared/firebase_services/firebase_notification_provider.dart` |

---

Ready? → **iOS:** [`IOS_CALL/`](IOS_CALL/README.md) · **Android:** [`ANDROID_CALL/`](ANDROID_CALL/README.md) 🚀
