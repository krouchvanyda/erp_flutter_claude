# 🤖🎙️ Android Voice Call — Learning Folder

This folder collects the **voice-call** parts on **Android** (sound, no video),
in simple words for someone **new to calls**.

| File | What you learn |
|------|----------------|
| [voice-call-step-by-step.md](voice-call-step-by-step.md) | The full Android voice call: button → ring → accept → talk → end. |

> 📁 Video calls are in the sibling **[`../VIDEO_CALL`](../VIDEO_CALL)** folder.
> 🤖 The Android ring layer (FCM + erp_callkit) is in the parent
> **[`../`](../README.md)** folder.
> 🍏 The iOS version of this is [`../../IOS_CALL/VOICE_CALL`](../../IOS_CALL/VOICE_CALL/README.md)
> — the voice-vs-video idea is the **same** on both platforms.

---

## Android voice call in one sentence

> You press the 📞 button → the app opens **`VoiceCallPage`** → asks for the
> **microphone** → the backend tells **Stream** to **ring** the other person →
> they **Accept** → **Stream** carries the voice → someone presses **End**.
> If their phone is *closed*, **FCM** rings it (instead of iOS's APNs VoIP).

---

## The 3 things that make it a VOICE call (not video)

1. **Screen:** `VoiceCallPage` (`lib/features/chat/views/voice_call_page.dart`).
2. **Permission:** microphone only — `ensureCallPermissions()`
   (Android manifest: `RECORD_AUDIO`).
3. **Call type:** `ChatCallType.voice`.

Everything else (brain, transport, Stream engine, the 4 phone states) is the
same as a video call. See [voice-call-step-by-step.md](voice-call-step-by-step.md).
