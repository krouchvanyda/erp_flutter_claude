# Lesson 2 — Configuration (set this up FIRST) ⚙️

A call cannot work until the "plumbing" is ready. This lesson is everything you
must prepare **before** you write call screens. Do these in order.

---

## 2.1 — The packages (pubspec.yaml)

These are the call-related packages this project uses:

```yaml
dependencies:
  # Real media (voice + video) — the SFU/WebRTC engine
  stream_video_flutter:              # main media SDK
  stream_video_push_notification:    # wires Stream's ring → native CallKit
  # (stream_webrtc_flutter comes in transitively; we touch it for iOS audio)

  # Signaling transport
  dio:                               # REST calls to our backend
  stomp_dart_client:                 # STOMP over WebSocket (server → app push)

  # Native incoming-call screen + permissions
  flutter_callkit_incoming:          # the green iOS ring UI / Android full-screen
  erp_callkit:                       # this project's own small CallKit helper package
  permission_handler:                # ask for mic + camera

  # Wake a closed app
  firebase_messaging:                # FCM (Android) + APNs routing on iOS
```

> 💡 You do not need to memorize versions. You need to know **why each one
> exists** (the comment after each line). That "why" is what you reuse in your
> next project.

---

## 2.2 — The Stream account (one-time, on the website)

Stream is an outside service. Someone must set it up once in the **Stream
Dashboard** (console.getstream.io):

1. Create an app → you get an **API key** and a **secret**.
2. Go to **Push Notifications**. Add TWO providers:
   - An **APNs** provider for iOS. **Name it exactly `apn`.**
   - A **Firebase** provider for Android. **Name it exactly `firebase`.**
3. Upload the certificates:
   - For iOS: your Apple **VoIP push certificate / key** (from Apple Developer).
   - For Android: your **Firebase service-account JSON**.

Why the exact names matter — in `stream_call_engine.dart` the code says:

```dart
pushNotificationManagerProvider: StreamVideoPushNotificationManager.create(
  iosPushProvider:     const StreamVideoPushProvider.apn(name: 'apn'),
  androidPushProvider: const StreamVideoPushProvider.firebase(name: 'firebase'),
),
```

The `name:` here **must match the provider name in the Stream Dashboard**, or
the ring push silently goes nowhere.

> 📌 From this project's memory: **iOS ringing needs a paid Stream account +
> the Apple VoIP entitlement + an APNs provider that matches your build's
> environment (sandbox vs production).** This is the #1 reason "the iOS phone
> never rings" — the configuration, not the code.

---

## 2.3 — The token: how the app proves who it is to Stream

The app must **never** hold the Stream secret. Instead:

```
  App ──GET /chats/calls/stream-token──► OUR backend
  OUR backend signs a token with the Stream secret
  App ◄── { apiKey, token, userId } ─────┘
```

So our backend has one endpoint:

- **`GET /chats/calls/stream-token`** → returns `{ apiKey, token, userId }`.

In the code, `StreamCallEngine._ensureClientImpl()` calls this, then builds the
client:

```dart
final tokenJson = await remote.getStreamToken();      // GET /chats/calls/stream-token
final apiKey = tokenJson['apiKey'];
final token  = tokenJson['token'];
final userId = tokenJson['userId'];

_client = StreamVideo(
  apiKey,
  user: User.regular(userId: userId, name: displayName, image: avatarUrl),
  userToken: token,
  pushNotificationManagerProvider: /* apn + firebase, see above */,
);
```

This `StreamVideo` object is **the client**. One per app process. We build it
lazily (only when first needed) and cache it by `userId`.

> 🧠 Why `name` and `image` here? So the *other* person's ring screen shows
> "Mr A is calling…" with a photo, instead of "10 is calling…". Stream copies
> these into the ring push.

---

## 2.4 — The backend endpoints (URLs) the call uses

This is your "API contract". Memorize the shape; the exact base path here is
`/api/v1/chats/*`.

### REST (HTTP — actions the app starts)

| Method + URL | When | What it does |
|---|---|---|
| `GET  /chats/calls/stream-token` | client build | Get `{apiKey, token, userId}` for Stream. |
| `POST /chats/conversations/{id}/calls` | I press Call | Create the call. Backend ALSO tells Stream to ring the callee. Returns `{ id, streamCallCid, participants }`. |
| `GET  /chats/calls/{id}` | reconcile | Read the true state of a call (voice or video? still ringing?). |
| `POST /chats/calls/{id}/accept` | I accept | Tell backend I picked up. |
| `POST /chats/calls/{id}/reject` | I decline | Tell backend I said no. |
| `POST /chats/calls/{id}/end`    | I hang up | Tell backend the call is over. |
| `GET  /chats/calls?page=&pageSize=` | history / cleanup | List recent calls. |

> Note: `accept` / `reject` / `end` use the **backend's numeric id** (e.g. `42`),
> NOT Stream's CID. The code is careful to swap the temporary local id for this
> numeric id as soon as the POST returns (more in Lesson 3).

### STOMP (WebSocket — things the server PUSHES to us)

The socket URL is `<apiBaseUrl>/ws`. After connecting, the app **subscribes**
to destinations:

| Destination | Meaning |
|---|---|
| `/user/queue/calls` | Personal call events meant just for me. |
| `/user/queue/inbox` | New chat messages for me. |
| `/topic/conversations/{id}/call` | Call events for one conversation (invite/accept/reject/hangup). |
| `/topic/conversations/{id}` | Chat messages for one conversation. |
| `/topic/presence` | Who is online/offline. |

So when the **other** person accepts, the backend pushes a `call.accept`
envelope down `/topic/conversations/{id}/call`, and our app reacts.

---

## 2.5 — Permissions (iOS Info.plist + runtime)

A call needs the microphone (and camera for video). Two parts:

1. **Info.plist** must declare why you need them (Apple rejects the app
   otherwise):
   - `NSMicrophoneUsageDescription` — "We need the mic for calls."
   - `NSCameraUsageDescription` — "We need the camera for video calls."
   - Background mode **Voice over IP** (so a closed app can be woken to ring).

2. **Runtime** — ask the user with `permission_handler` *before* media starts.
   In this project the call page does this for you:

```dart
// voice_call_page.dart → before placing the call
await ensureCallPermissions();   // asks mic (and camera for video)
_signaling.startOutgoing(...);   // then place the call
```

> 🧠 Important detail from the code: even if the user **denies** the mic, we
> still place the call. The ring to the other phone does not need our mic — we
> simply send no audio. Old behavior closed the page on denial, so the callee
> never rang. Don't repeat that bug.

---

## 2.6 — App startup wiring (main.dart)

When the app launches, a few things must happen in order. The key lines:

```dart
// 1. iOS-only: prime a WebRTC audio channel FIRST (prevents a crash on accept).
StreamCallEngine.primeWebRtcAudioEventSinkEarly();

// 2. Firebase must init before any firebase_* call.
await Firebase.initializeApp(...);

// 3. Start the chat transport (connect STOMP, subscribe to call topics).
unawaited(bootChatTransport(getIt));

// 4. Warm up the Stream client whenever the user signs in, so the FIRST
//    call doesn't pay the cold-start cost.
_wireStreamWarmUpToAuth(getIt<AuthSession>(), getIt<StreamCallEngine>());
```

And the `IncomingCallOverlay` is mounted high up (via `MaterialApp.builder` in
`app.dart`) so an incoming call can paint **over any screen**.

> 📌 That `primeWebRtcAudioEventSinkEarly()` line looks strange but it fixes a
> real iOS crash (`EXC_BAD_ACCESS`) the instant a callee grants the mic. It is
> documented in the project memory ("Stream WebRTC interruption crash"). Keep
> it as the very first thing in `main()`.

---

## 2.7 — Dependency injection (so any layer can find the services)

All these services (`ChatTransport`, `StreamCallEngine`, `CallSignalingService`,
repositories) are registered once in the in-house service locator (`getIt`) and
in `chat_di.dart`. The call screens then read them with
`context.read<CallSignalingService>()`.

Why a global locator and not just widget providers? Because the **background
isolate** (when the app is killed and woken by a push) has **no widget tree** —
it still needs to reach the signaling service. A global `getIt` works there;
`BuildContext` does not.

---

## ✅ Configuration checklist

- [ ] Packages added (media, transport, callkit, permissions, firebase).
- [ ] Stream app created; APNs provider named `apn`, Firebase provider `firebase`.
- [ ] Apple VoIP push key uploaded to Stream; VoIP background mode enabled.
- [ ] Backend endpoint `GET /chats/calls/stream-token` returns `{apiKey, token, userId}`.
- [ ] Backend call endpoints exist (`/calls`, `/{id}/accept|reject|end`, `GET /{id}`).
- [ ] STOMP socket `<base>/ws` reachable; topics subscribed on boot.
- [ ] Info.plist has mic/camera reasons + VoIP background mode.
- [ ] `main.dart`: prime WebRTC early, init Firebase, boot transport, warm up Stream.
- [ ] `IncomingCallOverlay` mounted via `MaterialApp.builder`.

When all boxes are ticked, you are ready for **[Lesson 3: Outgoing
call](03-outgoing-call.md)**.
