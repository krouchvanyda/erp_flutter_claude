# 🤖 Learning: Voice & Video Calls (Android) — Step by Step

This folder teaches calls on **Android**, in simple words for someone **new to
calls**.

> ⬅ Coming from the **[learning map](../README.md)**? Good. This folder is the
> Android **delta** — read the 🌍 shared lessons in `../IOS_CALL/` first.

> 💡 **Big news that saves you time:** Android and iOS share **~90% of the same
> code** — the same brain, transport, Stream engine, call screens, voice/video
> split, the outgoing flow, and connect/end. **Only ONE layer is different: how
> a closed phone rings** (Android = **FCM**; iOS = APNs VoIP). So you do NOT
> learn calls twice — you learn the shared system once, then learn the Android
> ring layer.

---

## ⭐ How to learn Android calls (the path)

**Step 1 — Learn the shared system** (these iOS lessons are platform-identical;
read them as-is, they apply to Android too):

| Read | From | Why it's the same on Android |
|------|------|------------------------------|
| Big picture (5 layers) | [`../IOS_CALL/01-big-picture.md`](../IOS_CALL/01-big-picture.md) | same layers, same state machine |
| Outgoing call | [`../IOS_CALL/03-outgoing-call.md`](../IOS_CALL/03-outgoing-call.md) | same `startOutgoing`, same URLs |
| Connect & end | [`../IOS_CALL/05-connect-and-end.md`](../IOS_CALL/05-connect-and-end.md) | same accept/hangup logic |
| Flowcharts | [`../IOS_CALL/06-flowcharts.md`](../IOS_CALL/06-flowcharts.md) | same sequences |
| Voice vs Video | [`../IOS_CALL/VOICE_CALL/`](../IOS_CALL/VOICE_CALL/README.md) · [`../IOS_CALL/VIDEO_CALL/`](../IOS_CALL/VIDEO_CALL/README.md) | same screens + permissions |

**Step 2 — Learn the Android-specific parts** (these lessons, in this folder):

| # | File | What you learn |
|---|------|----------------|
| 0 | [00-START-HERE.md](00-START-HERE.md) | Guided tour: the same call files + the Android push/ring files. |
| 1 | [01-configuration-android.md](01-configuration-android.md) | FCM setup, the manifest permissions, Stream `firebase` provider, `erp_callkit`. |
| 2 | [02-incoming-call-4-cases-android.md](02-incoming-call-4-cases-android.md) | **The 4 cases on Android** (foreground / minimized / killed / locked) with diagrams. |

**Want JUST voice, or JUST video on Android?** (like the iOS folder has)

| Folder | For | Start file |
|--------|-----|------------|
| [VOICE_CALL/](VOICE_CALL/README.md) | 🎙️ Android voice (mic only) | [voice-call-step-by-step.md](VOICE_CALL/voice-call-step-by-step.md) |
| [VIDEO_CALL/](VIDEO_CALL/README.md) | 📹 Android video (mic + camera) | [video-call-step-by-step.md](VIDEO_CALL/video-call-step-by-step.md) |

---

## The one big difference: iOS vs Android (memorize this table)

| | 🍏 iOS | 🤖 Android |
|--|--------|-----------|
| Push that rings a closed app | **APNs VoIP** (PushKit) | **FCM** high-priority data message |
| Who shows the ring screen | Stream's native PushKit → **CallKit** | **our app's FCM background handler** → `flutter_callkit_incoming` (via `erp_callkit`) |
| Ring payload keys | `callCid` (camelCase) | `call_cid`, `caller_id`, `caller_name` (snake_case) |
| Lock screen | CallKit shows over lock screen natively | `MainActivity.kt` `setShowWhenLocked` + `USE_FULL_SCREEN_INTENT` |
| Audio session | CallKit owns it → must re-assert | Android manages it → **simpler, no re-assert** |
| Decline when killed | CallKit native decline | `erp_callkit` `CallActionReceiver` → `BackendCallClient` (JWT passed from Dart) |
| Number of safety nets | many (cold-start audio, etc.) | **fewer** — the Android path is simpler |

> 🧠 Everything ABOVE the ring layer (button → screen → brain → backend → Stream
> media) is the same. Only this table changes between the two platforms.

---

## The Android-specific files in the real code

| Job | File |
|-----|------|
| FCM background handler (shows the ring when app is closed) | `lib/shared/firebase_services/firebase_notification_provider.dart` |
| FCM registration | `lib/main.dart` (`FirebaseMessaging.onBackgroundMessage(...)`) |
| Native lock-screen behavior | `android/app/src/main/kotlin/.../MainActivity.kt` |
| Native ring + Accept/Reject + backend POST | `packages/erp_callkit/android/.../` (`IncomingCallNotifier`, `CallActionReceiver`, `BackendCallClient`) |

Plus the **shared** files (same as iOS): `call_signaling_service.dart`,
`chat_transport.dart`, `stream_call_engine.dart`, the call pages.

---

Ready? → **[00-START-HERE.md](00-START-HERE.md)** 🚀
