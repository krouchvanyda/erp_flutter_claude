# Android — Configuration (set this up first) ⚙️

Android calls need the **same** backend + Stream setup as iOS, **plus** the FCM
ring layer. This lesson is only the Android-different config. For the shared
config (Stream token, backend endpoints, permissions concept), read
[`../IOS_CALL/02-configuration.md`](../IOS_CALL/02-configuration.md).

---

## 1. Packages (the Android-relevant ones)

```yaml
dependencies:
  stream_video_flutter:              # carries voice/video (same as iOS)
  firebase_messaging:                # ◄── Android ring uses FCM
  flutter_callkit_incoming:          # full-screen ring UI
  erp_callkit:                       # this project's native Android ring + accept/reject
  permission_handler:                # mic + camera
```

---

## 2. Firebase (FCM) — the Android ring channel

On Android, a closed app is woken by **FCM** (Firebase Cloud Messaging), not by
APNs VoIP. Set up:

1. A Firebase project + `google-services.json` in `android/app/`.
2. `Firebase.initializeApp(...)` in `main.dart` **before** any firebase call.
3. Register the background handler **before** `runApp` so a killed app can
   receive it:

```dart
// main.dart
FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
```

> 🧠 The handler must be a **top-level function** annotated with
> `@pragma('vm:entry-point')` — that's how Flutter can run it in a fresh
> background isolate when the app is killed. See
> `firebase_notification_provider.dart`.

---

## 3. Stream Dashboard — the `firebase` provider

In the Stream Console → **Push Notifications**, add a **Firebase** provider and
**name it exactly `firebase`** — it must match the code:

```dart
// stream_call_engine.dart
androidPushProvider: const StreamVideoPushProvider.firebase(name: 'firebase'),
```

Upload your **Firebase service-account JSON** to that provider. This is what lets
Stream send the `call.ring` FCM data message to the callee.

> ⚠️ Note: Stream's `stream_video_push_notification` package does NOT register an
> Android push handler in this project. So Stream's `call.ring` FCM message lands
> in **our own** `firebaseMessagingBackgroundHandler`, which then calls
> `_showStreamCallkitRinger` → `FlutterCallkitIncoming.showCallkitIncoming(...)`.
> (This is the key Android wiring decision — read the comment in
> `firebase_notification_provider.dart` around `sender == 'stream.video'`.)

---

## 4. AndroidManifest permissions

The ring-when-closed behavior needs these (in `android/app/src/main/AndroidManifest.xml`):

```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>       <!-- Android 13+ -->
<uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT"/>   <!-- Android 14+: the ring screen -->
<uses-permission android:name="android.permission.RECORD_AUDIO"/>             <!-- voice -->
<uses-permission android:name="android.permission.CAMERA"/>                   <!-- video -->
```

`USE_FULL_SCREEN_INTENT` is what lets the call notification become a **full-screen
ring** (instead of a small heads-up) on a locked/closed phone.

---

## 5. Lock-screen native code (`MainActivity.kt`)

When the call notification launches the app over a **locked** phone, the native
`MainActivity` shows the call UI over the lock screen:

```kotlin
// MainActivity.kt — maybeShowOverLockscreen(intent)
setShowWhenLocked(true)   // show the call UI on top of the keyguard
setTurnScreenOn(true)     // wake the screen
```

And when the call ends, `returnToLockScreenIfNeeded()` drops the app **back
behind the lock screen** (so you don't end up on the dashboard unlocked). It
talks to Dart over the `erp/lockscreen` MethodChannel.

> 🧠 iOS does this automatically inside CallKit. On Android we do it by hand in
> `MainActivity.kt`. Same result, different place.

---

## 6. One Android bug worth knowing (decline when killed)

There was a real bug: a killed-app **Decline** didn't stop the caller. The native
`SecureTokenReader` threw `AEADBadTagException` trying to read the JWT from
`flutter_secure_storage`, so the reject never POSTed.

**Fix:** pass the JWT **from Dart** via the call bundle to `BackendCallClient`,
instead of reading secure storage natively. (Project memory:
*"Android decline token-read fail"*.)

> 🔎 Debug tip: `flutter logs` HIDES native Android logs. Use full
> `adb logcat` to see `erp_callkit` / `BackendCallClient` output.

---

## ✅ Android config checklist

- [ ] `google-services.json` in `android/app/`, Firebase initialized in `main.dart`.
- [ ] `FirebaseMessaging.onBackgroundMessage(...)` registered before `runApp`.
- [ ] Background handler is top-level + `@pragma('vm:entry-point')`.
- [ ] Stream Dashboard has a **`firebase`** provider with the service-account JSON.
- [ ] Manifest has `POST_NOTIFICATIONS`, `USE_FULL_SCREEN_INTENT`, `RECORD_AUDIO`, `CAMERA`.
- [ ] `MainActivity.kt` shows over lock screen + returns behind it on end.
- [ ] Decline passes the JWT from Dart (no native secure-storage read).

Next: [02-incoming-call-4-cases-android.md](02-incoming-call-4-cases-android.md).

⬅ Back to the [index](README.md).
