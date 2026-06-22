# 📚 Learning: Voice & Video Calls (iOS) — Step by Step

Welcome! This folder teaches you **how voice and video calls work** in this
project, from the very first configuration to the moment a call ends.

It is written for someone who is **brand new to calls**. Every word is simple.
Every step has a number. There are many diagrams.

At the end, you will be able to **take this call system and build it again in
another project.**

> 📱 This folder is the **iOS** course. There is a separate `ANDROID_CALL`
> folder next to it for Android. In this project, call code is **iOS-first**
> (the code uses `Platform.isIOS` guards so it never changes Android).

---

## ⭐ Start here (do this first)

1. Read this README (you are here — 2 minutes).
2. Open **[00-START-HERE.md](00-START-HERE.md)** — a quick guided tour that
   follows ONE real call through the real files, with line numbers + URLs.
3. Then read lessons **01 → 08 in order** (table below).

If you prefer **ideas before code**, you can read **[01-big-picture.md](01-big-picture.md)**
first, then come back to 00. Both are fine.

---

## 🧭 How to view the diagrams (important!)

Many lessons have **two kinds** of diagrams:

- **ASCII diagrams** (made of `─ │ ┌ ▼` characters) — these show in **any**
  editor, even plain text. ✅ You can always read these.
- **Mermaid diagrams** (start with ```` ```mermaid ````) — these only become a
  real picture in a **Markdown preview**. In VS Code, open the file and press
  **`Cmd + Shift + V`** to see them drawn. In a plain editor you'll just see the
  code — that's normal, the ASCII version next to it says the same thing.

---

## 📖 The lessons (read in this order)

**Legend:** 🌍 = applies to **both** iOS & Android (shared) · 🍏 = **iOS-specific**.

| # | File | What you learn | Platform | Hard? |
|---|------|----------------|:--------:|-------|
| 0 | [00-START-HERE.md](00-START-HERE.md) | **Guided tour:** one call traced through real files + line numbers + the URL order. | 🌍 | 🟢 easy |
| 1 | [01-big-picture.md](01-big-picture.md) | The 5 "layers" of a call. The mental model. The words (glossary). | 🌍 | 🟢 easy |
| 2 | [02-configuration.md](02-configuration.md) | What you set up FIRST: packages, Stream, tokens, push, permissions. | 🌍+🍏 | 🟡 medium |
| 3 | [03-outgoing-call.md](03-outgoing-call.md) | I press Call → the other phone rings. Step by step. | 🌍 | 🟡 medium |
| 4 | [04-incoming-call.md](04-incoming-call.md) | My phone rings (app open / minimized / killed). | 🌍 | 🟡 medium |
| 5 | [05-connect-and-end.md](05-connect-and-end.md) | Accept → audio flows → hang up → cleanup. | 🌍 | 🟡 medium |
| 6 | [06-flowcharts.md](06-flowcharts.md) | All the diagrams in one place (sequence + state machine). | 🌍 | 🟢 easy |
| 7 | [07-apply-to-another-project.md](07-apply-to-another-project.md) | A copy-me recipe + checklist for your next app. | 🌍 | 🟡 medium |
| 8 | [08-incoming-call-4-cases.md](08-incoming-call-4-cases.md) | **Diagrams for the 4 cases:** in-app, minimized, killed, killed+locked. | 🍏 | 🔴 deep |

> 🤖 **Learning Android?** Read all the 🌍 lessons above (they apply to Android
> too), then go to **[`../ANDROID_CALL/`](../ANDROID_CALL/README.md)** for the
> Android ring layer instead of lesson 08. The Android version of "the 4 cases"
> is [`../ANDROID_CALL/02-incoming-call-4-cases-android.md`](../ANDROID_CALL/02-incoming-call-4-cases-android.md).

> 🕐 **Only have 10 minutes?** Read **00** + **01**. That gives you the whole
> mental model. The rest is detail you can come back to.

> ⬅ Back to the **[learning map](../README.md)**.

---

## 🎙️📹 Want JUST voice, or JUST video?

Lessons 00–08 above teach voice **and** video together (they share ~90% of the
code). If you want the focused, type-specific view, use these two subfolders:

| Folder | For | Start file |
|--------|-----|------------|
| [VOICE_CALL/](VOICE_CALL/README.md) | 🎙️ voice calls only (mic, no camera) | [voice-call-step-by-step.md](VOICE_CALL/voice-call-step-by-step.md) |
| [VIDEO_CALL/](VIDEO_CALL/README.md) | 📹 video calls (mic + camera) | [video-call-step-by-step.md](VIDEO_CALL/video-call-step-by-step.md) |

> 🧠 **Video = voice + the camera.** Read VOICE_CALL first, then VIDEO_CALL adds
> only the camera parts (camera permission, `VideoCallPage`, picture-in-picture,
> flip camera). The brain, transport, Stream engine, URLs, and the 4 phone
> states are identical for both.

---

## The one-sentence summary

> When you press **Call**, the app opens a **call screen**, asks the **backend**
> to create a call, the backend tells **Stream** (the audio/video company) to
> **ring** the other person, the other person **accepts**, and then **Stream**
> carries the real voice/video while our **signaling** code keeps both screens
> in sync until someone presses **End**.

If that sentence makes sense after you finish reading, you have learned it. ✅

---

## 🧠 The 3 ideas you must never forget

1. **Two channels.** Small *commands* ("call / accept / end") go through **our
   backend**. The real *voice + video* goes through **Stream**. Your voice never
   touches our backend.
2. **The server rings, not the caller's app.** That is what lets a closed phone
   ring.
3. **One state, both phones agree.** The call is always in one state
   (`idle → ringing → connected → ended`). The UI just shows that state.

---

## The files in the real code (look at these while you read)

| Job | File |
|-----|------|
| The call screens (UI) | `lib/features/chat/views/voice_call_page.dart`, `video_call_page.dart` |
| The incoming-call popup | `lib/features/chat/widgets/incoming_call_overlay.dart` |
| The "brain" / state machine | `lib/features/chat/repositories/call_signaling_service.dart` |
| Talking to the backend (REST + WebSocket) | `lib/features/chat/repositories/chat_transport.dart` |
| The real audio/video (Stream/WebRTC) | `lib/features/chat/repositories/stream_call_engine.dart` |
| Native ring when app is closed (CallKit) | `lib/features/chat/repositories/callkit_event_handler.dart` |
| App startup wiring | `lib/main.dart` |

Keep this table near you. When a lesson says *"this happens in the signaling
service"*, you know which file to open.

---

## 📇 Quick glossary (full one is in Lesson 1)

| Word | Simple meaning |
|------|----------------|
| **Signaling** | Small control messages ("call", "accept", "end") — NOT the voice. |
| **Media** | The real voice + video. |
| **Stream** | The company/SDK that carries the media + sends the ring push. |
| **WebRTC** | The tech that moves live media between phones. |
| **STOMP / WebSocket** | An always-open pipe; the server pushes events to the app. |
| **CallKit** | iOS's native call screen + ring (works even when the app is closed). |
| **VoIP push** | A special push that can wake a fully-closed app to ring. |

---

> ⚠️ Team rule for THIS project: all call work is **iOS-first and iOS-only**
> (`Platform.isIOS` guards, never touch Android). When you copy this to another
> project you can drop those guards — but in this repo, respect them.

Ready? → **[00-START-HERE.md](00-START-HERE.md)** 🚀
