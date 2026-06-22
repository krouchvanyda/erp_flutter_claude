# 📹 Video Call — Learning Folder

This folder collects the **video-call** parts (sound **+ picture**), start to
end, in simple words for someone **new to calls**.

| File | What you learn |
|------|----------------|
| [video-call-step-by-step.md](video-call-step-by-step.md) | The full video call: button → ring → accept → see each other → end. With diagrams. |

> 📁 Voice calls are in the sibling **[`../VOICE_CALL`](../VOICE_CALL)** folder.
> 🧩 The deep shared course (5 layers, 4 phone-state diagrams, lessons 00–08) is
> the parent **[`../`](../README.md)** folder.

---

## 👉 Read the voice folder first

A video call **= a voice call + the camera**. ~90% is identical. So:

1. Read **[`../VOICE_CALL/voice-call-step-by-step.md`](../VOICE_CALL/voice-call-step-by-step.md)** first (the base).
2. Then read this folder for **only the extra things the camera adds**.

---

## Video call in one sentence

> You press the 📹 button → the app opens **`VideoCallPage`** → asks for the
> **microphone AND camera** → the backend tells **Stream** to **ring** the other
> person → they **Accept** → **Stream** carries the **sound + video** (your
> camera + their camera) while our signaling keeps both screens in sync → someone
> presses **End**.

---

## The 3 things that make it a VIDEO call (not voice)

1. **Screen:** `VideoCallPage` (`lib/features/chat/views/video_call_page.dart`).
2. **Permissions:** microphone **+ camera** — `ensureCallPermissions(needCamera: true)`.
3. **Call type:** `ChatCallType.video`.

Plus the video-only UI: full-screen remote video, your own small
**picture-in-picture**, **flip camera**, **camera on/off**. See
[video-call-step-by-step.md](video-call-step-by-step.md).
