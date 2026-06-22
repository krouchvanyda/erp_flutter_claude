# 🤖📹 Android Video Call — Learning Folder

This folder collects the **video-call** parts on **Android** (sound **+
picture**), in simple words for someone **new to calls**.

| File | What you learn |
|------|----------------|
| [video-call-step-by-step.md](video-call-step-by-step.md) | The full Android video call: button → ring → accept → see each other → end. |

> 📁 Voice calls are in the sibling **[`../VOICE_CALL`](../VOICE_CALL)** folder.
> 🤖 The Android ring layer (FCM + erp_callkit) is the parent
> **[`../`](../README.md)** folder.
> 🍏 The iOS version is [`../../IOS_CALL/VIDEO_CALL`](../../IOS_CALL/VIDEO_CALL/README.md)
> — the voice-vs-video idea is the **same** on both platforms.

---

## 👉 Read the voice folder first

A video call **= a voice call + the camera**. ~90% is identical. So read
**[`../VOICE_CALL/voice-call-step-by-step.md`](../VOICE_CALL/voice-call-step-by-step.md)**
first, then this folder for **only the camera extras**.

---

## Android video call in one sentence

> You press the 📹 button → the app opens **`VideoCallPage`** → asks for the
> **microphone AND camera** → the backend tells **Stream** to **ring** → they
> **Accept** → **Stream** carries **sound + video** → someone presses **End**.
> If their phone is *closed*, **FCM** rings it.

---

## The 3 things that make it a VIDEO call (not voice)

1. **Screen:** `VideoCallPage` (`lib/features/chat/views/video_call_page.dart`).
2. **Permissions:** microphone **+ camera** — `ensureCallPermissions(needCamera: true)`
   (Android manifest: `RECORD_AUDIO` **+ `CAMERA`**).
3. **Call type:** `ChatCallType.video`.

Plus the video-only UI: full-screen remote video, your own **picture-in-picture**,
**flip camera**, **camera on/off**. See
[video-call-step-by-step.md](video-call-step-by-step.md).
