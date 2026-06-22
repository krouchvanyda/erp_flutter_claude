# 🎙️ Voice Call — Learning Folder

This folder collects the **voice-call** parts (sound, no video), start to end,
in simple words for someone **new to calls**.

| File | What you learn |
|------|----------------|
| [voice-call-step-by-step.md](voice-call-step-by-step.md) | The full voice call: button → ring → accept → talk → end. With diagrams. |

> 📁 Video calls are in the sibling **[`../VIDEO_CALL`](../VIDEO_CALL)** folder.
> 🧩 The deep shared course (5 layers, 4 phone-state diagrams, lessons 00–08) is
> the parent **[`../`](../README.md)** folder. Read this for the voice-specific
> view; go to the parent lessons for the deepest detail.

---

## Voice call in one sentence

> You press the 📞 button → the app opens **`VoiceCallPage`** → asks for the
> **microphone** → the backend tells **Stream** to **ring** the other person →
> they **Accept** → **Stream** carries the voice while our **signaling** keeps
> both screens in sync → someone presses **End**.

---

## The 3 things that make it a VOICE call (not video)

1. **Screen:** `VoiceCallPage` (`lib/features/chat/views/voice_call_page.dart`).
2. **Permission:** microphone only — `ensureCallPermissions()` (no camera).
3. **Call type:** `ChatCallType.voice`.

Everything else (the brain, the transport, the Stream engine, the 4 phone
states) is **identical** to a video call. See
[voice-call-step-by-step.md](voice-call-step-by-step.md).
