# Enterprise ERP Mobile — Learning Rebuild

> **Branch `feature/rebuild`** (started 2026-11-19 from `feature/call`).
> `lib/` is being rebuilt **from zero, step by step, to learn**. Only what is
> listed in [`docs/learning/REBUILD/README.md`](docs/learning/REBUILD/README.md)
> exists. Everything else is still to be built.
>
> The old, working app (and the old version of this file) lives on branch
> **`feature/call`**. Use it as a reference:
> `git show feature/call:<path>`.

---

## How we work (learning mode)

The user is learning. Every step follows this loop:

```
PLAN → BUILD (small) → EXPLAIN (what + WHY + other ways) → DOC → USER CHECKS → COMMIT
```

- **Build + explain mode:** Claude writes one small step, then explains every
  file. Always say **why** the code is written this way, the **other ways** it
  could be written, and why they weren't picked.
- **One lesson doc per step** in `docs/learning/REBUILD/NN-topic.md`, with
  6 parts: Why · Picture · Code · 🤔 Why like this? · Try it · Check yourself.
- **Diagrams = Mermaid**, in the same style as `~/Documents/flutter-chat/docs`:
  `flowchart LR/TD` (labels `["text<br/>more"]`, edge labels `-->|"…"|`,
  `subgraph … direction LR`), `sequenceDiagram` with `autonumber` / `Note` /
  `alt` for step-by-step flows, `classDiagram` for sealed families,
  `stateDiagram-v2` for state machines. Colours via `classDef`: app
  `fill:#dbe9ff,stroke:#3b6fd8,color:#123` · ok
  `fill:#d9f7e6,stroke:#00a86b,color:#063` · wait/plan
  `fill:#fff4d6,stroke:#d4a017,color:#5a4300` · none
  `fill:#eeeeee,stroke:#999,color:#555` · error
  `fill:#fde2e2,stroke:#d64545,color:#611`. Plain text blocks only for file
  trees, code and screen mockups. In labels write `<` `>` as `#60;` `#62;` (e.g.
  `getIt#60;Dio#62;`); never `&lt;` or a raw `<Dio>`.
- After each step, update the roadmap table in
  `docs/learning/REBUILD/README.md` (⏳ → ✅) and the progress table in
  `README.md`.
- `flutter analyze` must be clean, and the app must **run**, before a step is done.
- **Commit only when the user says "commit".**
- Use simple English (short sentences, easy words). Khmer words are fine.
- Don't copy-paste big files from `feature/call`. Rebuild them smaller and
  explain them. Reuse hard-won fixes (see "Lessons from the old app").

## Role
You are a senior Flutter developer and a patient teacher, working on this
chat + call app (Khmer and English).

## Skills
- Design: clean, elegant and professional layouts that work on phone and tablet
- Flutter: clear widgets, state and project structure (MVVM + BLoC)
- Realtime & backend: REST with dio, STOMP WebSocket (Spring backend)
- Calls & push: Stream Video, CallKit, Firebase Cloud Messaging (FCM) / iOS VoIP
- Animation: smooth, well-timed transitions (`ConfigRouter` page
  transitions, implicit animations)

## Discussion mode

When my message starts with "/discussion" (or "discussion", "discustion", "/discustion"):
- Only discuss. Do NOT change, create or delete any file, and do not run the build.
- Answer in simple English (short sentences, easy words); Khmer words are fine.
- Explain how it works now in the project.
- Give 2–4 options, each with good points and bad points, and say which one you recommend and why.
- Say if an option would affect other parts of the project.
- Draw a small picture or an ASCII mockup when it helps me see the idea.
- End with a short question: which option I want.
- Start coding only after I say so (for example "do it", "do option 2", "ok build it").

---

## Scope: 4 features only

| Feature | What it does |
|---|---|
| **auth** | Login, splash auto-login, token refresh, logout |
| **profile** | View / edit my profile, avatar (camera / gallery) |
| **chat** | Inbox, conversation (text / image / file / voice), groups, real-time over STOMP |
| **call** | Voice / video calls (Stream Video), incoming call UI, CallKit, ringing when the app is killed (FCM / VoIP push) |

**Not in scope** (deleted, don't bring back): dashboard, settings admin pages,
notifications center, global search, the separate `employees` feature (the
member picker lives inside `chat`), and the old Modules 3–8.

## Roadmap

```
0 clean ─► 1 setup (1.1 flavor · 1.2 theme · 1.3 DI · 1.4 router) ─► 2 network
  ─► 3 auth ─► 4 profile ─► 5 chat ─► 6 call (in app)
  ─► 7 call when app is killed (FCM / CallKit) ─► 8 i18n + tests + polish
```

Live status: [`docs/learning/REBUILD/README.md`](docs/learning/REBUILD/README.md).

---

## Tech stack (target)

| Layer | Choice | Notes |
|---|---|---|
| UI | Flutter (Dart `^3.9.2`) | iOS-first, Android too |
| State | `flutter_bloc` | The **only** state framework |
| Architecture | MVVM + BLoC, flat | View ↔ BLoC ↔ Repository ↔ DataSource |
| DI | In-house service locator (`core/di/`) | Hand-written, `getIt<T>()` style API, no package |
| Networking | `dio` | Interceptors: auth, refresh, errors, logging |
| Realtime | `stomp_dart_client` | Chat, presence, call signalling |
| Local cache | `shared_preferences` | Cached user, settings |
| Secrets | `flutter_secure_storage` | Tokens only |
| Navigation | `ConfigRouter` (`Navigator` + `page_transition`) + `AuthGate` | No go_router. `AuthGate` swaps Splash / Login / Home from `AuthSession` |
| Models | Hand-written immutable + Dart 3 `sealed class` | `json_serializable` for JSON models only |
| Calls | `stream_video_flutter` (+ a native CallKit plugin, rebuilt in Step 7; old one: `git show feature/call:packages/erp_callkit`) | |
| Push | `firebase_messaging` (+ VoIP on iOS) | Step 7 |
| Translations | GetX `.tr` **only** | Step 8 |
| Tests | `flutter_test`, `bloc_test`, `mocktail` | |

`pubspec.yaml` still lists the old packages. Unused ones are removed in Step 8.

### Do not reintroduce

| Removed | Why |
|---|---|
| `drift` / SQLite, the offline sync engine | Online-first; writes go straight to the backend |
| `get_it` + `injectable` | The background isolate (killed-app calls) needs a global locator; no codegen wanted |
| `freezed`, `equatable` | Fewer build-time deps; hand-written `==` / `copyWith` instead |

---

## Architecture — MVVM + BLoC (flat)

```
View (Widget)
   │  context.read<Bloc>().add(event)  /  BlocBuilder(buildWhen: …)
   ▼
BLoC  (events → sealed states; the ViewModel)
   │
   ▼
Repository  (one concrete class — business rules live here)
   │
   ▼
DataSource  Remote: dio / STOMP   ·   Local: shared_preferences / secure storage
```

### Folder layout (target)

```
lib/
├── main.dart, main_<flavor>.dart   bootstrap(flavor) — the one start-up function
├── app/                            top layer: App (MaterialApp) + AuthGate (→ Splash / Login / Inbox)
│                                   + app_di.dart (core + feature DI). MAY import features/
├── core/                           shared infrastructure, never imports features/
│   ├── config/    flavor + environments           (Step 1.1)
│   ├── theme/     design tokens + ThemeData       (Step 1.2)
│   ├── di/        service locator                 (Step 1.3)
│   ├── router/    ConfigRouter, AppNavigator,     (Step 1.4)
│   │              AuthSession
│   ├── network/   AppService + Dio + interceptors (Step 2)
│   ├── storage/   UserCache (logged-in user JSON) (Step 4.1)
│   ├── realtime/  RealtimeService (STOMP), lifecycle (Step 5.3)
│   └── push/      FCM / VoIP                      (Step 7)
├── shared/widgets/                 reusable UI, no feature logic
├── localization/                   english.dart / khmer.dart  (Step 8)
└── features/
    └── <feature>/                  (MVVM-template folder names)
        ├── model/         immutable data classes (fromJson / fromData)
        ├── repository/    concrete repository (uses AppService)
        ├── viewmodel/<x>/ ONE FOLDER PER BLOC: <x>_view_model_bloc.dart
        │                  + part <x>_view_model_event.dart / _state.dart
        │                  (e.g. viewmodel/login/, viewmodel/inbox/)
        ├── view/          pages
        ├── widgets/       feature-only widgets, ONE widget per file
        └── <feature>_di.dart   registerXModule(getIt), called from app/app_di.dart
```

**Rule:** `app/` may import everything. `features/` may import `core/` and
`shared/`. `core/` never imports `features/` (that's why `AuthGate` lives in
`app/`). Features don't import each other's internals (talk through
`core/` or a small public API).

---

## Key rules per area

### Auth & session (Step 3)

```
Login response
  ├── accessToken + refreshToken (+ expiresAt) ──► flutter_secure_storage
  └── user { id, email, fullName, phone, avatarUrl } ──► shared_preferences
      (`UserCache`, core/storage: the RAW JSON map, no toJson)
```

- The backend contract is [`API_LIST_BACKEND.md`](./API_LIST_BACKEND.md)
  (its Postman collection lives in the backend repo's `postman/`). Models follow it **exactly**; don't
  guess extra field names.
- `UserModel` = the 5 fields above, the same for the login `user` and
  `GET /api/v1/users/me`. They have **no** `roles` / `permissions` (only the
  admin user endpoints do, and this app doesn't use them), so don't build
  permission checks in the app. `id` is a number on the wire → `String` in
  the app. `avatarUrl` is a server path (`/uploads/...`) or null.

- **Auto-login (Step 3.2):** `SplashViewModelBloc` runs
  `AuthRepository.restoreSession()` and a min duration together
  (`(a, b).wait`). `restoreSession()` reads the tokens (no network), clears
  them if the refresh token is expired, and otherwise calls
  `AuthSession.markAuthenticated()` **before** the splash calls `onFinished`,
  so `AuthGate` shows Home with no flash of Login.
- The splash does **not** validate the access token. An expired one is fine:
  the first API call refreshes it in the interceptor.
- **Logout (Step 3.2):** `AuthRepository.logout()` = `POST /auth/logout`
  with the refresh token (best effort, 5 s timeout, result ignored) **then**,
  in `finally`, `TokenStorage.clear()` + `markLoggedOut()`. Server first: the
  interceptor needs the stored access token to authorize the call. Ask
  "Log out?" before calling it.
- Token refresh = ONE shared `TokenRefresher` (single flight: a second
  caller waits for the running one). REST (`AuthInterceptor`) and the socket
  both use it; never call `/auth/refresh` anywhere else (the refresh token
  is rotated → two refreshes = the second is rejected = logout).
- Logout and any failed refresh **must** call `TokenStorage.clear()`.
  Skipping it re-enables auto-login, which is a security bug. Clear
  `UserCache` in the same places (logout `finally`, expired refresh token on
  the splash, `AuthInterceptor`'s `onSessionExpired` in `core/di`).
- The "should I auto-login?" decision lives in the splash (its BLoC) only.
- Pages never navigate after login/logout: they call
  `AuthSession.markAuthenticated()` / `markLoggedOut()`, and `AuthGate` swaps
  the screen (on logout it also `popUntil(isFirst)` so no private page stays
  on the stack).
- Every other page move uses `ConfigRouter` (`pushPageAnimation` for normal
  pages). Code without a context navigates via `AppNavigator.rootKey`.

### Profile (Step 4)

- **4.1 view:** `ProfileRepository.loadProfile()` = the user from
  `UserCache` (saved at login) + `GET /employees/me` → **1 request**. The
  backend auto-creates the employee on register / create user / login
  (`ensureProfileForUser`). No cache (old session) → `/users/me` +
  `/employees/me` together and cache the user. Employee 404 → fresh
  `/users/me`, `employee: null`. Other employee errors → `Left`. "Which
  name / phone / avatar wins" (employee first; email = login email) lives in
  `ProfileModel` getters, never in widgets.
- **4.2 avatar:** `POST /employees/me/avatar` (multipart field `file`,
  `contentType` from the extension) / `DELETE` the same path, then reload the
  profile (don't guess the response). Photos are picked with
  `image_picker` at max 1024 px, JPEG 85. Picking (system screens, needs a
  context) lives in the widget; the upload goes BLoC → repository. No
  employee record → no 📷 badge. The employee avatar wins over the user's.
- **4.3 edit name / phone is BLOCKED:** the only edit endpoint
  `PATCH /users/{id}` needs `user:write` (admin) → 403. Waiting for the
  backend's `PATCH /api/v1/users/me`. Don't call `/users/{id}`.
- Logout lives on the profile page, as a red ⎋ icon at the top right of the
  AppBar (always visible, works even if the load failed). `ProfilePage(onLogout:)` gets
  `AuthRepository.logout` from `app/`; profile never imports the auth
  repository (a feature's **model** may be shared, its repository not).
- Server file paths (`/uploads/...`) → `ApiEndPoint.fileUrl(path)` before
  showing them. People → `AppAvatar(name:, imageUrl:)` (cached photo or
  initials). A page whose first load failed → `AppErrorView.fromError(error, onRetry:)` (icon per error type; red tint for server errors); a
  failed refresh keeps the data and shows `AppSnackBar` (profile) or an
  `AppErrorBanner(error:, onRetry:)` strip above the data (lists like the
  inbox; it stays until a load works, `onRetry` returns a Future).

### Network (Step 2) — MVVM-template style

- Every request goes through `AppService.send(httpMethods:, endPoint:,
  parse:, data:, queryParameters:, formData:)` (`core/network/app_service.dart`).
  `AppService` wraps the ONE shared `Dio` from DI; repositories never create
  `Dio` (the template's `Dio()`-per-call is NOT used).
- The backend wraps every response in `{ success, message, data, errorCode,
  traceId }`. `AppService` unwraps it; `parse` only gets `data`. Any 2xx is
  success.
- `send` never throws: it returns `Either<NetworkErrorModel, T>` (dartz,
  imported with `show Either, Left, Right`). `NetworkErrorModel` keeps the
  template fields (`title`, `description`, `statusCode`) and is sealed:
  `NoInternetError`, `ServerError` (+ errorCode, fieldErrors, traceId),
  `UnauthorizedError`, `UnknownError`. Texts/codes live in `core/utils/constants.dart`.
- Paths live in `ApiEndPoint`; methods in `HttpMethods` (lowerCamelCase + `patch`).
  The base URL is the server ROOT; `/api/v1` is part of each endpoint.
- No `getToken()` from SharedPreferences: tokens (`AuthTokens`, one JSON key)
  live in `TokenStorage` (`flutter_secure_storage`, iOS `first_unlock` so the
  background isolate can read them). `AuthInterceptor` (a `QueuedInterceptor`)
  attaches `Bearer` to every non-public request; on 401 it refreshes ONCE via a
  separate refresh Dio (no auth interceptor → no loop), saves the rotated pair
  and retries. Refresh REJECTED (400/401/403) → `TokenStorage.clear()` +
  `AuthSession.markLoggedOut()`. Refresh FAILED (offline/timeout/5xx) → keep
  tokens. Public endpoints (`ApiEndPoint.publicEndpoints`: health, login,
  register, refresh) never get a token or a refresh — a wrong password on
  login is also 401.
- In `AppService`, a 401 on a **public** endpoint becomes a `ServerError`
  with the server's `message` (e.g. "Invalid email or password"). Only a 401
  on a **private** endpoint is `UnauthorizedError` ("Session expired"). Always
  show the server's message when the envelope has one; don't replace it with
  a guess.
- **File uploads:** send `FormData` via `AppService.send(formData:)`. A
  `FormData` can be sent only ONCE, so `AuthInterceptor`'s retry sends
  `formData.clone()` (otherwise: "FormData has already been finalized").
  Always shrink images before upload.
- Never log the `Authorization` header or request bodies outside dev/uat.

### Chat (Step 5)

- **Models = the backend's Java records** (backend repo
  `~/Documents/call_erp/erp_java_backend_claude`, `features/chats/dto/`):
  `ConversationDto`, `MessageDto`, `MemberDto`, `ReactionDto`, and
  `core/response/PageResponse` → `PageModel<T>`. Read them before adding a
  field; don't guess. Ids → `String`, `Instant` → `DateTime.tryParse()?.toLocal()`,
  unknown enum values → a safe default.
- **My user id** = the access token's `sub` (`AuthTokens.userId`,
  `ChatRepository.myUserId()`). Read-only, for the UI; no request.
- A DIRECT conversation has no name: `ConversationModel.title(myId)` /
  `avatarUrlFor(myId)` show the other member. Members already carry
  `fullName` + `avatarUrl`, so never call `/users/{id}` to draw a chat.
- Paged lists: `page` / `hasMore` in the state, load more ~300 px before the
  end, the BLoC ignores repeats, and appending drops ids already shown.
- Pull-to-refresh: the event carries a `Completer<void>? done`, which the BLoC
  completes in `finally`; `onRefresh` returns `done.future`. Never wait on
  `bloc.stream.firstWhere(...)`: Bloc skips a state `==` the current one, so
  an unchanged list emits nothing and the spinner turns forever.
- The inbox is the home after login. `InboxPage(onOpenProfile:)` gets the
  profile route from `app/` (chat never imports profile).
- **Conversation (5.2):** `ConversationPage(conversation, myId)` gets the
  whole `ConversationModel` from the inbox (no extra request). The bloc is
  built in the page (`ConversationViewModelBloc(getIt<ChatRepository>(),
  conversationId:)`): the locator has no factory parameters. Messages are
  newest first in a `ListView(reverse: true)`; older pages load near the
  top. Back → the inbox reloads.
- **Send = optimistic.** Server data (`MessageModel`) and my unconfirmed
  texts (`OutgoingMessage`, `local-N` ids, `failed` flag) are separate
  lists. Success → swap for the server message (drop duplicate ids). Failure →
  mark only that bubble (⚠ "Not sent · Tap to retry"), never a page error,
  never lose the text. After every `await` in a handler, read `state.data`
  again (handlers run at the same time).
- `markRead(newestId)` only for a NEWER id than the last one sent, not
  awaited, result ignored. The server wants a number (`lastReadMessageId`).
- **Realtime (5.3):** ONE `RealtimeService` (`core/realtime`, STOMP on the
  flavor's `realtimeUrl` = backend `/ws`) knows STOMP, not chat. Started /
  stopped by `RealtimeLifecycle` (session, app resume, network back →
  `reconnectNow`). Own reconnect loop (backoff 1→30 s, a FRESH token each
  try via `TokenRefresher.validTokens()`); the package's `reconnectDelay` is
  0. Subscriptions are replayed after a reconnect, and `reconnected` → the
  inbox and the open chat reload page 1 (events during a drop are lost).
- Frames `{event, payload}` → `ChatUpdate` (sealed, in `ChatRepository`).
  BLoCs listen in their constructor, turn each update into an
  `On…LiveUpdateEvent`, and cancel in `close()`. Inbox: keep OUR
  `unreadCount` on `conversation.update` (the server sends the actor's).
  Conversation: my own `message.send` echo replaces the oldest 🕓 bubble
  with the same text; `message.read` → ✓✓ (compare ids as numbers).
- Destinations live in `ApiEndPoint` (`inboxQueue`, `conversationTopic(id)`).
- **New chat + groups (5.4):** one `MemberPickerPage(mode: newChat /
  newGroup / addMembers)` + `MemberPickerViewModelBloc`. `GET /users`
  ignores `search` → load every page (100 each) and filter on the phone
  (`ContactModel.matches`); hide me, disabled accounts and `excludeIds`.
  Pages return results with `pop(conversation)`; the inbox opens it. When
  two pages share a bloc (`BlocProvider.value`), listeners act only if
  `ModalRoute.of(context)?.isCurrent`.
- `ConversationPage` owns a `ConversationInfoViewModelBloc` (the CURRENT
  conversation: title, member names, info page). It listens to the topic
  (`conversation.update`) AND the inbox queue (`conversation.remove`).
  Left / deleted / removed → `ConversationInfoGoneState` → the chat page
  `popUntil(isFirst)` + snackbar. Admin buttons are hidden by
  `isAdmin`, but the server is the real check (403 → snackbar).
- DIRECT create returns the existing chat with that person (no duplicates).
  Leave = `DELETE …/members/{myId}`. Ids go to the server as numbers.
- **Attachments (5.5):** 2 requests: `uploadAttachment` (multipart `file`,
  `POST /chats/attachments`, progress via `AppService.send(onSendProgress:)`)
  → `sendAttachment` `{type, attachmentUrl, attachmentContentType,
  attachmentSizeBytes, durationSeconds?}`. Server rules live in
  `AttachmentRules` (25 MB; images, audio, **PDF only**) and are checked on
  the phone BEFORE uploading. Photos: image_picker 1600 px / quality 80.
  Voice: `record` AAC `.m4a` (= `audio/mp4`), `durationSeconds` required.
- The outgoing bubble shows the LOCAL file at once with progress; it keeps
  `uploadedUrl` so a retry only re-sends the message. My echo of a file is
  matched by `attachmentUrl`. Picking / recording live in widgets (system
  UI); uploading in the bloc.
- One `AppAudioPlayer` (`core/audio`, just_audio): one sound at a time;
  the chat page stops it on leave. PDFs open outside the app
  (`url_launcher`, Android `<queries>` VIEW).
- **Typing (5.6):** the first client → server STOMP SEND. Backend
  `TypingController` (`@MessageMapping("/conversations/{id}/typing")`, in
  `erp_java_backend_claude`) takes WHO from the STOMP principal, checks
  membership, broadcasts `typing {conversationId, userId, typing}` on the
  conversation topic. App: `RealtimeService.send` (dropped when offline),
  `ChatRepository.sendTyping`, one `TypingViewModelBloc` per open chat:
  send `true` ≤ every 3 s, `false` after 4 s idle / clear / send / leave;
  show others with a 6 s expiry; ignore me. Shown under the chat title.
- Never let the phone SEND straight to `/topic/...` or put a user id in a
  body the server trusts: always an `/app/...` handler that uses the
  principal.
- **Message actions (5.6):** long-press → `MessageActionsSheet` (react ·
  copy · edit · seen by · delete). Edit mode = `editing` in
  `ConversationLoadedState` (composer banner, ✓). `canEdit` = mine · TEXT
  · < 15 min (server rule; it still checks). Reactions are optimistic with
  rollback; the server's full list wins. A failed edit / delete / reaction
  = `ConversationActionFailedState` → snackbar (never the load banner).
  Deleted messages are REMOVED (history leaves them out), live too.
  `message.edit` / `message.delete` also reach `/user/queue/inbox` (backend
  fan-out, like `send`): the inbox updates the preview only if it's the
  chat's LAST message (deleted → re-fetch the conversation, keep our
  unread count).
- **Presence (5.6):** one `PresenceStore` (chat, `ValueNotifier`): `watch(ids)`
  batches `GET /chats/presence?ids=`, follows `/topic/presence`, reloads on
  reconnect, clears on logout. Inbox → 🟢 `PresenceDot`; direct chat title →
  `presenceLine` ("online" · "in a call" · `ChatTime.lastSeen`); typing wins.
  `RealtimeLifecycle` sends `POST /chats/presence/background` on paused and
  `/foreground` on resumed (needed for calls to ring by push).
- **Search (5.6):** `MessageSearchViewModelBloc` — 350 ms debounce, drop
  answers for an old query, paged. Match highlighted with `Text.rich`. No
  jump-to-message yet.

### Call (Step 6)

- **6.1 signalling** (no media): our backend does ring / accept / reject /
  end (`POST /chats/conversations/{id}/calls`, `/chats/calls/{id}/ringing ·
  accept · reject[?reason=busy] · end`, `GET /chats/calls/{id}`); STOMP
  `/user/queue/calls` (invites, ringing) + `/topic/conversations/{id}/call`
  (invite · ringing · accept · reject · hangup). Stream Video is ONLY the
  media (`streamCallCid`, Step 6.2).
- ONE app-wide `CallViewModelBloc` (lazy singleton, `BlocProvider.value`
  above `MaterialApp`): sealed states Idle · Outgoing · Incoming · InCall ·
  Ended(`CallEndReason`) → Idle after `CallConfig.endedScreen`. All call
  timings live in `CallConfig`.
- `CallRouteListener` (in `MaterialApp.builder`) pushes ONE `CallPage` with
  `AppNavigator.rootKey` on Idle → Outgoing / Incoming; the page follows
  every phase (Accept never pushes a page) and closes itself on Idle.
- Chat ↔ call never import each other: chat gets a `ChatCallLauncher`
  (`start` + `inCall`) from `app/auth_gate.dart`; the call feature gets
  `loadPeer` (conversation → `CallPeer` name / photo) from `app/app_di.dart`.
- Rules (CALL_SCENARIOS.md): busy → auto `reject(reason: busy)`, no screen;
  subscribe the call topic BEFORE `POST /calls`; hang up before the POST
  answers → `end(id)` when the id arrives; the callee's backstop only CLOSES
  (never `reject`, or the server saves "declined" instead of MISSED); the
  server's 60 s `call.hangup reason=no_answer` decides "No answer";
  `reconnected` → `GET /calls/{id}`. Every end has its own words
  (`CallEndReason.label`).
- **6.2 media:** `CallMedia` (call/repository) is the ONLY Stream SDK user
  (plus `CallVideoView`, which draws `StreamVideoRenderer`). Token from
  `GET /chats/calls/stream-token` (never a Stream secret in the app), one
  `StreamVideo` per user (`reset` on user change / logout), `join` the
  `streamCallCid` after Accept on both sides. Permissions are asked FIRST
  by `CallPermissionGate` (UI): when I tap 📞 / 🎥 (in `app/`'s launcher)
  and when I tap Accept. Mic denied → no call (snackbar; denied for good →
  "Open Settings" dialog). Camera denied → the call goes on, camera off.
  `CallMedia.join` only CHECKS the status. InCall: `connectedAt == null`
  = "Connecting…" until `peerPresent` (the OTHER person in the media) → the
  timer starts. Join fails → `POST /end` + failed. Every `_end` → `leave()`.
  Toggles (mic · camera · speaker · flip) are optimistic with rollback. A
  video call draws in `AppTheme.dark()` set ABOVE the Scaffold.
- **6.3a sounds:** `CallViewModelBloc.soundFor(prev, next)` (pure rule
  table) runs in `onChange` → `CallSounds.play` (own just_audio player with
  `handleAudioSessionActivation / handleInterruptions /
  androidApplyAudioAttributes: false`: never touch WebRTC's audio session).
  Silent "Calling…" · ringback on "Ringing…" · ringtone on incoming ·
  silence on Accept / "Connecting…" · connected beep at 00:00 · ended beep
  after any live phase. `null` = leave the player alone (Mute, name loaded).
- **6.3b reconnecting:** `CallMedia.link` (`MediaLink` connected ·
  reconnecting · lost, from Stream's `CallStatus` via `linkOf`; Stream's
  `reconnectTimeout` = `CallConfig.reconnectTimeout` 30 s). InCall
  `reconnecting` → "Reconnecting…" + a 30 s give-up timer → `POST /end` +
  `connectionLost`. `peerAway` (they left the media after 00:00) → "Jane is
  reconnecting…"; never hang up for them (their phone / the server does).
- **6.3c groups:** `app/call_peer_of.dart` builds `CallPeer` (+ `members`
  userId → `CallMember` name / photo) for outgoing AND incoming calls.
  `CallMedia.peers` = the OTHER user ids in the media (sorted, distinct);
  InCall `others`; the FIRST one starts the timer; "away" only when nobody
  is left ("Waiting for others…" in a group). Incoming group: "Dara is
  calling…". Voice: `CallParticipantsRow` (max 4 + "+N"); video:
  `CallVideoView` 1 full · 2 rows · 2×2 (max 4) of `CallVideoTile`. Stream
  also exports `CallMember` → `hide CallMember` where both are imported.
- **6.3d call line:** the BACKEND writes it: `ChatCallService.endCallInternal`
  (every end) → `CallMessageRecorder` saves a `MessageType.CALL` message
  (sender = caller, `durationSeconds`, body JSON `{callId, callType, status,
  endReason, answered}`) + `message.send` to topic + inboxes. Clients can't
  send CALL (400); search skips it. App: `ChatCallInfo.of(message)` (chat's
  own model) → outcome → words per viewer (`mine` = I called; missed for the
  others = red); `ChatCallContent` in the bubble (no ✓✓), tap = call back via
  `ChatCallLauncher`; inbox preview "📞 Missed voice call" (no "You:").
- Stuck calls: the backend hangs up for a user whose socket is gone 30 s
  during an ANSWERED call (`answered-disconnect-grace-seconds`, backend
  `CallDisconnectHandler`). The raw "Caller is already in an active call"
  is shown as `CallEndReason.stillInCall`.

### Chat & call (Steps 5–7): lessons from the old app

These bugs cost many rounds of fixes on `feature/call`. Build them in from the
start:

- ~~Send `targetIds`~~ / ~~direct conversation ids differ per device~~: these
  came from the old offline (SQLite) design and **don't apply** to this
  backend. The server picks the receivers, and conversations have server ids.
- **Inbox preview:** store the raw body, and add the "You: " prefix in **one**
  place (the tile).
- **Accept from the incoming overlay:** push the call page with the
  **root `GlobalKey<NavigatorState>`** (`AppNavigator.rootKey`). The overlay sits beside the
  navigator, not under it, so `Navigator.of(context)` finds nothing.
- **Push the call page first, then accept.** Accepting changes state and
  unmounts the overlay, and its `context` dies with it.
- **Group calls:** only the caller moves to `connected` on accept. Other
  callees keep ringing. A callee's hangup only removes them. The caller's
  hangup ends the call for everyone. When the last callee leaves, the caller
  hangs up automatically.
- **Busy:** if already in a call, auto-reject the new invite with
  `reason: busy`. Clear stale ringing after about 30s.
- **Killed app:** only push (FCM / iOS VoIP) can wake it. `main()` does not
  run in the background isolate, so services must be reachable from the global
  locator, and `Flavor.current` falls back to `appFlavor`.

Deep call docs: `docs/learning/IOS_CALL/`, `docs/learning/ANDROID_CALL/`,
`CALL_SCENARIOS.md`.

---

## Development guardrails

### Do
- BLoC events and states are **immutable**. Unions are Dart 3 `sealed class`
  with `factory` redirects.
- Give every value type **explicit** (hand-written, visible in the file)
  `==` / `hashCode` / `copyWith`, plus a safe `toString`. Use
  `package:collection` equality for list and map fields.
  - Why: Dart's implicit default `==` compares the **memory box**, not the
    data. Leaving it out breaks quietly later (profile Save button never
    turns off, duplicate members in a chat `Set`, useless rebuilds), even
    though tests pass today.
  - `==` and `hashCode` always go together and use the **same fields**.
    Adding a field → update constructor, `fromJson`, `==`, `hashCode`
    (and `copyWith`).
  - `toString` prints only ids / non-private fields (e.g.
    `UserModel($id, $email)`), never phone numbers or tokens.
  - Explained line by line in
    [`07-login.md`](docs/learning/REBUILD/07-login.md#-hashcode-tostring-line-by-line).
- Business rules go in the Repository (or the BLoC when they are stateful),
  never in widgets.
- Register cross-cutting services in `core/di/`, and feature services in
  `<feature>_di.dart`.
- Add `buildWhen` on every `BlocBuilder`.
- Use design tokens (`AppSpacing`, `AppRadius`, `AppFontSize`) and theme
  colors (`Theme.of(context).colorScheme`). Text: the `AppLabel` widget
  (built on `AppTextStyle.build`, so Inter + Khmer fallback load). Leave its
  `color` null unless you need a special color, so it inherits from the parent.
  Never hard-code colors, sizes or text styles.

  ```dart
  // ❌ raw Text + TextStyle: no Inter, no Khmer fallback, breaks dark mode
  Text('Welcome back', style: TextStyle(fontSize: 24, color: Color(0xFF1A1D23)))

  // ✅ AppLabel + tokens — normal text: no color, const
  const AppLabel(
    text: 'Welcome back',
    fontSize: AppFontSize.value24,
    fontWeight: FontWeight.w700,
  ),
  // ✅ secondary text: color from the THEME (colors = Theme.of(context).colorScheme)
  AppLabel(
    text: flavor.apiBaseUrl,
    fontSize: AppFontSize.value14,
    color: colors.onSurfaceVariant,
  ),
  ```

  ```
  AppLabel ─► AppFontSize (size) ─► AppTextStyle.build (Inter + Khmer)
           └► color: null                 ─► inherits theme / parent color
              color: colorScheme.xxx      ─► special color, still flips in dark mode
              color: AppColors / Color(…) ─► ❌ never (breaks dark mode)
  ```
  Use `const` when every value is fixed (text, `AppFontSize`, `FontWeight`).
- BLoCs follow the template: `<X>ViewModelBloc` with `part` event/state files,
  `@immutable sealed` bases, events `On…Event`, states `…LoadingState` /
  `…ErrorState(error)` / `…SuccessState` or `…LoadedState`.
- Forms: phone-side field rules via `Form` + `FormValidators`
  (`core/utils/validators/`); the BLoC handles submit, loading, server errors
  (`ServerError.fieldErrors` → `AppInputText(errorText:)`) and success.
- Reusable widgets in `core/widgets/` (`AppInputText` with optional `label`,
  `AppButton` with `isLoading`, `AppSnackBar`, `AppConfirmDialog`) take
  colors from the theme, never hard-coded.
- "Are you sure?" questions (logout, delete, leave group, end call) use
  `AppConfirmDialog.show(...)` → `bool` (`destructive: true` → red confirm).
  Never a raw `AlertDialog`: the theme makes buttons full width, which breaks
  its actions row.
- Status colours (success · warning · error + `onXxx`) come from the theme
  extension `AppStatusColors` → `context.statusColors.xxx`. Light uses deep
  shades + white text, dark uses light shades + dark text. Never hard-code
  them. Every text-on-colour pair must reach 4.5:1 (checked by
  `test/core/theme/app_status_colors_test.dart`).
- Server / network errors (and success / warning messages) are shown with
  `AppSnackBar.error / warning / success / info(context, title:, message:)` (a bar at
  the **top**, drawn in the root `Overlay`; `AppSnackBar.hide()` slides it
  away), never a raw `SnackBar` or an inline error card. Call it from a `BlocConsumer` /
  `BlocListener` **listener** (one-time action), never from a builder. Field
  errors (`fieldErrors`) stay under the fields, so `listenWhen` skips them.
- Keep page files short. `view/<x>_page.dart` = layout + `BlocProvider`
  only. Each piece of the screen (form, header, panel, tile…) goes in its own
  file in `features/<feature>/widgets/`, public and named after the feature
  (`LoginForm`, `LoginBrandPanel`). Pieces any feature can reuse go in
  `core/widgets/` named `App…` (`AppFadeSlideIn`). No private `_Xxx`
  widget classes in page files.
- Every screen is responsive: decide with `LayoutBuilder` on available width
  (wide ≥ 720), cap form/content width (forms ≤ 420), keep it scrollable for
  the keyboard, and check light + dark.
- Write tests for each step's BLoC and repository.

### Don't
- No business logic in widgets. No API calls from a BLoC (always through the
  Repository). No `BuildContext` inside a BLoC.
- No new `UseCase` classes or abstract repository interfaces. Keep it flat.
- Don't share BLoC instances across unrelated features.
- No commercial or paid packages. Check pub.dev for an MIT, BSD or Apache 2.0
  license.
- **GetX only for translations** (`'key'.tr`, `trParams`, `trPluralParams`).
  No GetX state, routing or widgets. UI files import only
  `import 'package:get/get.dart' show Trans;`. Locales are `en_US` and `km_KH`.
  Never hard-code UI text (from Step 8 on; before that, keep strings in one
  place so they are easy to move).
- Data is not UI text: message bodies sent to the server stay untranslated.

---

## Design

The visual and UX spec is in
[`ERP_MOBILE_DESIGN_GUIDE.md`](./ERP_MOBILE_DESIGN_GUIDE.md): tokens, component
patterns, motion rules, and per-screen layouts. Read it before building any
screen. Only the Auth, Profile (Screen 9.9) and Chat & Call (Module 10) specs
apply to this rebuild.

Core tokens:

```
primary #3B4FE8 · surface #F8F9FC · surfaceVariant #EEF0F5 · onSurface #1A1D23
success #16A34A · warning #D97706 · error #DC2626 · info #0284C7
(backgrounds with text: success #15803D · warning #B45309 — see AppStatusColors)
spacing  xs 4 · sm 8 · md 16 · lg 24 · xl 32 · xxl 48
radius   sm 8 · md 12 · lg 16 · xl 24 · full 999
font     Inter
```