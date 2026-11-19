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
| Calls | `stream_video_flutter` + `packages/erp_callkit` | |
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
├── app/                            top layer: App (MaterialApp) + AuthGate
│                                   + app_di.dart (core + feature DI). MAY import features/
├── core/                           shared infrastructure, never imports features/
│   ├── config/    flavor + environments           (Step 1.1)
│   ├── theme/     design tokens + ThemeData       (Step 1.2)
│   ├── di/        service locator                 (Step 1.3)
│   ├── router/    ConfigRouter, AppNavigator,     (Step 1.4)
│   │              AuthSession
│   ├── network/   AppService + Dio + interceptors (Step 2)
│   ├── realtime/  STOMP client                    (Step 5)
│   └── push/      FCM / VoIP                      (Step 7)
├── shared/widgets/                 reusable UI, no feature logic
├── localization/                   english.dart / khmer.dart  (Step 8)
└── features/
    └── <feature>/                  (MVVM-template folder names)
        ├── model/         immutable data classes (fromJson / fromData)
        ├── repository/    concrete repository (uses AppService)
        ├── viewmodel/     <x>_view_model_bloc.dart + part _event / _state
        ├── view/          pages
        ├── widgets/       feature-only widgets
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
  ├── access_token + refresh_token ──► flutter_secure_storage
  └── user profile                 ──► shared_preferences (cache)
```

- **Auto-login:** the splash reads tokens from secure storage. If tokens exist,
  call `AuthSession.markAuthenticated()` **before** going to the home route,
  otherwise the router redirect sends the user back to `/login`.
- The splash does **not** validate the access token. An expired one is fine:
  the first API call refreshes it in the interceptor.
- Logout and any failed refresh **must** call `TokenStorage.clear()`.
  Skipping it re-enables auto-login, which is a security bug.
- The "should I auto-login?" decision lives in the splash only.
- Pages never navigate after login/logout: they call
  `AuthSession.markAuthenticated()` / `markLoggedOut()`, and `AuthGate` swaps
  the screen (on logout it also `popUntil(isFirst)` so no private page stays
  on the stack).
- Every other page move uses `ConfigRouter` (`pushPageAnimation` for normal
  pages). Code without a context navigates via `AppNavigator.rootKey`.

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
- Never log the `Authorization` header or request bodies outside dev/uat.

### Chat & call (Steps 5–7): lessons from the old app

These bugs cost many rounds of fixes on `feature/call`. Build them in from the
start:

- **Address every message:** send `targetIds`. Receivers drop anything not
  addressed to them.
- **Direct conversation ids differ per device.** Look up the local
  conversation by the other person's id, not by the sender's conversation id.
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
- Give every value type explicit `==` / `hashCode` / `copyWith`. Use
  `package:collection` equality for list and map fields.
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
  `AppButton` with `isLoading`) take colors from the theme, never hard-coded.
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
spacing  xs 4 · sm 8 · md 16 · lg 24 · xl 32 · xxl 48
radius   sm 8 · md 12 · lg 16 · xl 24 · full 999
font     Inter
```