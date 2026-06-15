# Enterprise ERP Mobile — Project Plan

## Core Technology Stack (as-built)

| Layer | Technology | Notes |
|---|---|---|
| UI Framework | Flutter (Dart) | Cross-platform iOS/Android |
| State Management | flutter_bloc (open source) | BLoC pattern — the **only** state/architecture framework |
| Architecture | **MVVM + BLoC** | View ↔ BLoC ↔ Repository ↔ DataSource (flat) |
| DI | **In-house service locator** (`core/di/service_locator.dart`) | Hand-written, no package; registrations in `core/di/register_module.dart` + each feature's `*_di.dart` |
| Networking | dio | HTTP client + interceptors |
| Realtime | STOMP over WebSocket (`stomp_dart_client`) | Chat / presence / calls |
| Local persistence | **shared_preferences** (key-value) | Cached user, RBAC permissions, biometric flag, notification inbox, chat settings |
| Secure Storage | flutter_secure_storage | Tokens/credentials only |
| Navigation | go_router | Declarative routing |
| Models / state | **Hand-written immutable classes + Dart 3 `sealed class`** | Manual `==`/`hashCode`/`copyWith`; `json_serializable` still used for data-layer JSON models |
| Calls / media | Stream Video (`stream_video_flutter`) + `erp_callkit` | Module 10 |
| Localization | flutter_localizations (built-in) | i18n |
| Testing | bloc_test, mocktail, flutter_test | Unit + widget tests |

### Removed from the original plan (do not reintroduce without discussion)

The app was trimmed to a lean BLoC-centric stack. These were **deliberately removed**:

| Removed | Replaced by | Why |
|---|---|---|
| `drift` + `sqlite3_flutter_libs` (local SQLite DB) | `shared_preferences` | Online-first; no local relational DB needed |
| Custom offline **sync engine** (`core/sync/`) | — (online-only) | Writes go straight to the backend over REST |
| `get_it` + `injectable` (DI framework + codegen) | In-house `service_locator.dart` (same `getIt` API) | Background isolate (killed-app calls) needs a global locator; no codegen wanted |
| `freezed` + `freezed_annotation` | Hand-written immutable + Dart 3 sealed classes | Fewer build-time deps; no codegen |
| `equatable` | `freezed` previously, now manual `==` / `collection` equality | Was unused |
| **Modules 3–8** (Finance, Procurement, Inventory, Sales, HR, Projects) | — | Out of scope; deleted (`lib/features/{finance,hr,inventory,procurement,projects,sales}` gone) |
| `tools/chat_relay` (LAN WebSocket demo relay) + its in-app config UI | Real STOMP backend | Superseded by the production backend |

**Live modules:** 0 (Core), 1 (Auth), 2 (Dashboard), 9 (Settings), 10 (Chat & Voice/Video) — plus `employees`, `notifications`, `search` support features. Module specs for 3–8 below are retained as historical plan only; **the code no longer exists.**

---

## Design Spec

Per-screen layout intent, design tokens, component patterns, motion rules,
and the prompt template for generating new screens live in a separate file:

> **[`ERP_MOBILE_DESIGN_GUIDE.md`](./ERP_MOBILE_DESIGN_GUIDE.md)** — single
> source of truth for all screen designs. Read this before creating or
> redesigning any UI.

CLAUDE.md (this file) owns the *project plan* — modules, phases, slices,
and architectural guardrails. The design guide owns the *visual + UX spec* —
colors, typography, spacing, component patterns, per-screen layouts, BLoC
contracts.

The design guide is **aspirational** in places (e.g. it describes a Chat
& Voice module that doesn't exist yet, and a 6-tab bottom nav vs the
current 3-tab shell). Treat it as the target, not the as-built state.

---

## Project Architecture — MVVM + BLoC

```
lib/
├── core/                          # Shared infrastructure
│   ├── network/                   # Dio client, interceptors, error handler
│   ├── services/                  # Cross-cutting services (logging, analytics, …)
│   └── utils/                     # Helpers, extensions, constants
│
├── shared/                        # Reusable UI building blocks
│   └── widgets/                   # App-wide widgets (no feature logic)
│       ├── app_button.dart        # Primary/secondary button styles
│       ├── app_text_field.dart    # Filled input field (design tokens)
│       ├── loading_indicator.dart # Shimmer / spinner states
│       ├── error_view.dart        # Standard error display
│       └── app_dialog.dart        # Confirm / alert dialog shell
│
├── features/                      # One folder per feature (vertical slice)
│   └── auth/                      # Example feature: Authentication
│       ├── models/                # Immutable data classes (hand-written)
│       │   └── user.dart
│       │
│       ├── repositories/          # Concrete repo — business rules + data sources
│       │   └── auth_repository.dart
│       │
│       ├── bloc/                  # View-model layer (events → states)
│       │   ├── auth_bloc.dart
│       │   ├── auth_event.dart
│       │   └── auth_state.dart
│       │
│       ├── views/                 # Screens (Flutter pages)
│       │   └── login_page.dart
│       │
│       └── widgets/               # Feature-scoped widgets
│           ├── login_form.dart
│           └── social_login_button.dart
│
└── main.dart                      # App entry point + DI bootstrap
```

> **No more `core/database/` or `core/sync/`** — the SQLite/drift layer and
> the offline sync engine were removed. Structural caches now live in
> `shared_preferences` (auth in `features/auth/data/datasources/*_dao.dart`,
> notifications in `features/notifications/data/datasources/notifications_dao.dart`).

> **DI is hand-written.** There is no `get_it`/`injectable` package. The
> `GetIt` class in `core/di/service_locator.dart` is an in-house drop-in
> (same `getIt<T>()` / `registerLazySingleton` API). Register new core deps
> in `registerCoreDependencies`; per-feature deps in each `*_di.dart`
> (`registerAuthModule`, `registerChatModule`, etc.) — exactly the manual
> style the chat module already uses.

> **Models & states are hand-written.** No `freezed`. Data classes get
> explicit `==`/`hashCode`/`copyWith`; unions (BLoC events/states, `Failure`,
> `RealtimeMessage`, `OtpVerificationResult`, …) are Dart 3 `sealed class`
> hierarchies with `factory` redirects so `X.variant(...)` construction and
> `switch`/`on<Subtype>` matching both work. Use `package:collection`
> (`ListEquality`/`MapEquality`/`DeepCollectionEquality`) for collection
> equality inside `==`. `json_serializable` is still used for data-layer
> JSON models.

> **Legacy note** — the surviving modules (Auth, Dashboard, Settings) still
> ship a `domain/usecases/` + `domain/repositories/` (abstract) folder from
> the original Clean-Architecture convention. **Don't refactor them.** New
> code uses the flat layout above: one concrete repository, no abstract
> interface, no use-case classes.

### MVVM + BLoC Data Flow

```
View (Flutter Widget)
   │  context.read<Bloc>().add(event)  /  BlocBuilder
   ▼
BLoC (processes events → emits sealed states)
   │  calls
   ▼
Repository (concrete — business rules live here)
   │  calls
   ▼
DataSource  (Remote: dio REST / STOMP)  +  (Local: shared_preferences DAO)
```

> BLoCs are provided to the widget tree via `BlocProvider`; cross-cutting
> services (repositories, transport, call engine) are resolved from the
> in-house `getIt` — including the FCM **background isolate**, where there
> is no `BuildContext` so `RepositoryProvider` can't reach.

---

## Modules, Phases & Slices

---

### MODULE 0 — Core Foundation

#### Phase 0.1 — Project Scaffold
- Slice 0.1.1: Monorepo structure, folder conventions, lint rules (`flutter_lints`)
- Slice 0.1.2: ~~`get_it` + `injectable` DI wiring~~ → **in-house service locator** (`core/di/service_locator.dart`), hand-written registrations (no DI package/codegen)
- Slice 0.1.3: `go_router` setup with route guards (auth-aware)
- Slice 0.1.4: Global theme system (colors, typography, spacing tokens)

#### Phase 0.2 — Networking Layer
- Slice 0.2.1: `dio` base client with base URL, timeouts
- Slice 0.2.2: JWT auth interceptor (attach + refresh token)
- Slice 0.2.3: Error interceptor → maps HTTP errors to domain `Failure` types
- Slice 0.2.4: Network connectivity checker (`connectivity_plus`)

#### Phase 0.3 — Local Database

> ⚠️ **REMOVED.** The SQLite/drift database (`drift` + `sqlite3_flutter_libs`)
> and `core/database/` are gone. Structural caches now live in
> `shared_preferences` via plain DAOs (`CachedUserDao`,
> `BiometricSettingsDao`, `NotificationsDao` — same public APIs, prefs-backed).
> The original SQLite plan below is historical.

- Slice 0.3.1: `SQLite` database setup, migration strategy — register `CachedUser` + `UserPermissions` + `SyncQueue` tables
- Slice 0.3.2: Generic DAO base class
- Slice 0.3.3: Cache invalidation policy (TTL-based)
- Slice 0.3.4: `AuthDao` — upsertUser, getUser, deleteUser, upsertPermissions, getPermissions, deletePermissions

**SQLite tables for auth:**
```
TABLE: cached_user
  id             TEXT PRIMARY KEY
  name           TEXT
  email          TEXT
  avatar_url     TEXT
  biometric_on   BOOLEAN
  last_login_at  DATETIME
  cached_at      DATETIME   ← TTL invalidation

TABLE: user_permissions
  user_id        TEXT
  module         TEXT       ← e.g. "finance", "inventory"
  scope          TEXT       ← e.g. "read", "write", "approve"
  cached_at      DATETIME
```

#### Phase 0.4 — Offline-First Sync Engine

> ⚠️ **REMOVED.** `core/sync/` (sync queue, conflict policy, sync engine,
> `SyncBloc`) is gone — the app is online-first: writes go directly to the
> backend over REST/STOMP. The plan below is historical.

- Slice 0.4.1: Sync queue (pending operations stored in SQLite)
- Slice 0.4.2: Conflict resolution strategy (last-write-wins or server-wins, configurable)
- Slice 0.4.3: Background sync trigger on connectivity restore
- Slice 0.4.4: Sync status BLoC (UI-visible sync state)

#### Phase 0.5 — Cross-Cutting Concerns
- Slice 0.5.1: Logging service (structured logs, `logger` package)
- Slice 0.5.2: Analytics abstraction interface (swap implementations freely)
- Slice 0.5.3: Error boundary widget + crash reporting hook
- Slice 0.5.4: Localization setup (ARB files, `intl`)

---

### MODULE 1 — Authentication & Identity

#### Phase 1.1 — Auth Core
- Slice 1.1.1: Login page (MVVM + BLoC)
- Slice 1.1.2: JWT token storage (`flutter_secure_storage`) — tokens only, never in SQLite
- Slice 1.1.2b: Cache user profile + permissions → SQLite (`cached_user` + `user_permissions` tables) ← **NEW**
- Slice 1.1.3: Token refresh logic in interceptor — reads `user_id` from SQLite to re-attach context
- Slice 1.1.4: Logout + token revocation + SQLite wipe (`deleteUser` + `deletePermissions`)
- Slice 1.1.5: **Auto-login on app start** — splash probes `TokenStorage.read()`,
  calls `AuthSession.markAuthenticated()` when tokens exist, then routes:
  tokens present → `/dashboard`, no tokens → `/login`. The user only sees the
  login screen again after an explicit logout, a refresh failure (interceptor
  routes back to `/login`), or a manual secure-storage wipe (uninstall/reset). ← **NEW**

**Storage boundary for Phase 1.1:**
```
Login API response
   ├── access_token  + refresh_token ──→ flutter_secure_storage  (secrets)
   ├── user profile                  ──→ SQLite: cached_user       (structural)
   └── permissions                   ──→ SQLite: user_permissions  (structural)
```

**Session persistence rules (Slice 1.1.5):**
- Tokens persist across app kills because `SecureTokenStorage` writes to
  `flutter_secure_storage` (iOS Keychain / Android Keystore). Do NOT add a
  process-lifetime cache that shadows it — the splash must always read the
  authoritative storage on cold start.
- `AuthSession.isAuthenticated` boots to `false` on every cold start (the
  bool is in-process state, not persisted). The splash MUST flip it via
  `AuthSession.markAuthenticated()` before navigating to `/dashboard` —
  otherwise the router's `redirect` (which reads `session.isAuthenticated`)
  bounces the request back to `/login` even when tokens are present. Stored
  tokens alone do not equal "router thinks I'm signed in."
- The splash does NOT validate the access token before redirecting. An expired
  access token is fine here — the first authenticated call hits the
  `AuthInterceptor`, which transparently refreshes via the refresh token. The
  user only bounces back to `/login` if BOTH access AND refresh have expired
  (or been revoked) — exactly the "session truly ended" case.
- Logout (and any failed refresh) MUST call `TokenStorage.clear()`. Skipping it
  re-grants auto-login on the next app start, which would be a security bug.
- The splash redirect target is the only place the "should I auto-login?"
  decision lives. Route guards and interceptors handle the after-the-fact
  cases (401 → refresh → maybe-logout). Don't duplicate the decision in
  individual pages or BLoCs.

#### Phase 1.2 — Multi-Factor & SSO
- Slice 1.2.1: TOTP/OTP input screen — ephemeral, memory only, no SQLite
- Slice 1.2.2: OAuth2 PKCE flow (`oauth2` package) — PKCE verifier/challenge in memory only, resulting tokens → `flutter_secure_storage`
- Slice 1.2.3: Biometric unlock (`local_auth`) — reads `biometric_on` flag from SQLite, biometric keys stay in OS keychain

**Storage boundary for Phase 1.2:**
```
OTP code          → memory only (ephemeral)
PKCE verifier     → memory only (ephemeral)
OAuth2 tokens     → flutter_secure_storage
biometric_on flag → SQLite: cached_user
```

#### Phase 1.3 — Role-Based Access Control (RBAC)
- Slice 1.3.1: Permission model (roles, scopes) from API — cached to SQLite `user_permissions`
- Slice 1.3.2: Permission-aware route guard — reads from SQLite so it works offline
- Slice 1.3.3: Widget-level permission gating (`PermissionGuard` widget)

**Full storage map — Module 1:**
```
                flutter_secure_storage    SQLite                  Memory
                ──────────────────────   ──────────────────────  ──────────────
Login           access_token             cached_user             —
                refresh_token            user_permissions
                                         last_login_at

Token refresh   (reads/writes tokens)    reads user_id           —

Biometric       —                        biometric_on (r/w)      —
                                         last_login_at

OTP / PKCE      —                        —                       verifier
                                                                  challenge
                                                                  OTP code

Logout          deleteAll()              deleteUser()            cleared
                                         deletePermissions()
```

---

### MODULE 2 — Dashboard & Home

#### Phase 2.1 — Shell & Navigation
- Slice 2.1.1: Bottom nav / side drawer shell responsive to screen size
- Slice 2.1.2: Module shortcut tiles (permission-filtered)
- Slice 2.1.3: Global search bar (federated search across modules)

#### Phase 2.2 — KPI Widgets
- Slice 2.2.1: KPI card component (value, trend, sparkline)
- Slice 2.2.2: Dashboard layout engine (configurable grid)
- Slice 2.2.3: Charts (`fl_chart`)
- Slice 2.2.4: Real-time refresh via WebSocket (`web_socket_channel`)

#### Phase 2.3 — Notifications
- Slice 2.3.1: Notification inbox BLoC
- Slice 2.3.2: Push notification handler (`firebase_messaging`)
- Slice 2.3.3: In-app notification center UI
- Slice 2.3.4: Deep-link from notification to record

---

### MODULE 9 — Settings & Administration

#### Phase 9.1 — User Preferences
- Slice 9.1.1: Theme toggle (light/dark)
- Slice 9.1.2: Language selector (i18n)
- Slice 9.1.3: Notification preferences
- Slice 9.1.4: My Profile Info — avatar edit (camera/gallery), contact + personal sections, account-security row (change password / change PIN / biometric toggle, all require re-auth) ← **NEW**
- Slice 9.1.5: My Roles & Permissions — read-only transparency view, granted vs not-granted lists with searchable filter, render scope strings as human labels ← **NEW**

#### Phase 9.2 — System Config (Admin)
- Slice 9.2.1: User management (admin only, RBAC-gated)
- Slice 9.2.2: Role & permission editor
- Slice 9.2.3: API endpoint configuration (multi-tenant/environment)

#### Phase 9.3 — Security
- Slice 9.3.1: Session management (active devices list)
- Slice 9.3.2: Audit log viewer
- Slice 9.3.3: App PIN lock / biometric re-auth on resume

---

### MODULE 10 — Chat & Voice / Video ← **NEW MODULE**

> Real-time internal communication. Built on a WebSocket signalling layer
> with SQLite for offline message persistence; voice + video calls use
> WebRTC peer-to-peer via `flutter_webrtc`. New package dependencies:
> `flutter_webrtc`, `record`, `just_audio`, `image_picker`, `file_picker`.

**SQLite tables for Module 10:**
```
TABLE: chat_conversations
  id, name, avatar_url, is_group, is_muted,
  last_message_body, last_message_sender_id, last_message_at,
  unread_count, created_at, updated_at

TABLE: chat_participants
  conversation_id, employee_id, is_admin, joined_at, last_read_at

TABLE: chat_messages
  id, conversation_id, sender_id,
  body, type,                            -- text | voice | image | file | system
  reply_to_id, edited_body, edited_at, is_deleted,
  file_url, file_name, file_size_bytes,
  voice_url, voice_duration_seconds,
  sent_at, delivered_at, read_at,
  reactions                              -- JSON: [{emoji, employee_ids[]}]

TABLE: chat_call_log
  id, conversation_id, caller_id, call_type,   -- voice | video
  started_at, answered_at, ended_at,
  duration_seconds, status                     -- missed | answered | rejected | no_answer
```

#### Phase 10.1 — Chat Core
- Slice 10.1.1: Chat Inbox — conversation list (All / Unread / Groups tabs), online-status dots, unread badges, swipe-to-mute / swipe-to-delete; subscribes to `/ws/inbox` for real-time updates
- Slice 10.1.2: Chat Conversation — paginated message list with date separators, reply quotes, reaction row, typing indicator, optimistic-insert sends; supports text + voice (hold-to-record) + image + file attachments; `/ws/chat/:conversationId` for live message/typing/seen events
- Slice 10.1.3: New Conversation / Group Chat — searchable member picker with Direct vs Group toggle, group name + avatar setup; creates `chat_conversations` + `chat_participants` rows
- Slice 10.1.4: Message Search — SQLite FTS5 full-text search over `chat_messages.body`, tap result → jump to + highlight in conversation
- Slice 10.1.5: Image Viewer + real Gallery send — full-screen viewer (`ImageViewerPage`) opened on tap of an image bubble or a Shared-Media tile. Pinch-to-zoom via `InteractiveViewer`, tap-to-toggle chrome, drag-down-to-dismiss with fading scrim, top-right share / save stubs, bottom caption with filename + sender + timestamp. Sources adapt automatically: `http(s)://` → `Image.network`, local file path → `Image.file` (after `File.exists` check), `demo://` seed stub → friendly placeholder. Companion change: the Conversation page's attachment sheet's Camera + Gallery options now run a real `ImagePicker` (max 1920 × 1920, quality 88) and send the result as a `ChatMessageType.image` message whose `fileUrl` is the local absolute path — so the new viewer has real bytes to display, and the wire transport (Slice 10.1.x) syncs the metadata to peers. ← **NEW**
- Slice 10.1.6: Real-time inbox sync — every inbound `MessageReceivedEvent` now also feeds `ConversationsRepository.updateLastMessage(...)` AND `bumpUnread(...)` from `bootChatTransport`, so the inbox tile of the receiving phone shows the new preview and the unread badge ticks up (1 → 2 → 3) **without** the user having to re-open the chat. A new `ActiveConversationTracker` singleton (entered in `ChatConversationPage.initState`, left in `dispose`) lets the bump skip the conversation the user is currently reading — counters only grow for chats the user is NOT looking at. The conversation page also calls `markRead(...)` on entry so search-result / call-back / deep-link paths clear the badge the same way an inbox tap does. The per-type preview helper renders `📷 Photo` / `📎 filename.pdf` / `🎤 Voice · 0:23` / raw body so the inbox row matches what the user sees in the conversation. ← **NEW**
- Slice 10.1.7: Cross-device group propagation — when User A creates a group `CHAT01` with Users B + C, every invited member's device used to stay empty because `NewConversationPage._create` only touched the local in-memory repo. A new `conversation.create` wire envelope (`ConversationCreatedEvent` in `ChatTransport`) carries `{ conversationId, name, isGroup, creatorId, creatorName, participantIds, createdAt }` over the relay; `participantIds` includes the creator AND every invited member so each callee can verify the envelope is addressed to them (the relay is broadcast-only, no identity awareness). `bootChatTransport` listens for the event, filters on `participantIds.contains(settings.userId)`, short-circuits on duplicate id (idempotent re-broadcast), then hydrates `ConversationsRepository.create(...)` with `participantPreviews` resolved from `ChatSeed.peopleDirectory` (excluding self) and `totalMembers = participantIds.length`. Direct conversations are still created implicitly on the first message exchange — no envelope needed. ← **NEW**
- Slice 10.1.8: Targeted direct messages — fixes three related bugs the user surfaced after 10.1.7. **Bug A** (cross-user leakage): `message.send` was broadcast to every connected socket with no addressing, so when Vibol→Pisey landed on Channary's relay socket, Channary's inbox processed it and her "Pisey Chhan" tile preview updated with Vibol's text. Fix: added `targetIds: List<String>` to the `message.send` envelope (mirrors the Slice 10.2.7 call routing). Sender computes from `conversation.participantPreviews` minus self; `bootChatTransport` drops inbound messages whose targetIds is non-empty and doesn't contain `settings.userId`. Empty list = legacy broadcast for back-compat. **Bug B** (direct-conv id mismatch): the seed reuses ids like `conv-005` ("Pisey Chhan") on every device, so when Vibol sends in HIS conv-005 (his Pisey-direct slot), Pisey's device looks up conv-005 → finds it locally → but it's *her own* self-direct slot, not her chat-with-Vibol. Fix: new `ConversationsRepository.findDirectWith(employeeId)` walks the seed for a non-group conv whose `participantPreviews` contains that id. On receive, if `targetIds == [me]` (direct-to-me), the handler looks up the local conv with the sender as the other party and rewrites `m.conversationId` to that local id before persisting. Vibol→Pisey now lands in Pisey's conv-003 ("Vibol Sok") tile. **Bug C** (double "You:" prefix on the inbox): the conversation page was sending `'You: $body'` to `updateLastMessage`, and the inbox tile's `_previewFor` was ALSO prepending "You: " when `senderId == me` — net effect "You: You: hi" / "You: You: 📷 Photo" / "You: You: 🎤 Voice…". Fix: send the raw body to `updateLastMessage` and let the inbox handle the prefix in one place. ← **NEW**
- Slice 10.1.9: Profile photo + inline call history on the chat page itself — two follow-ups so the conversation page matches the other surfaces. **Bug A** (AppBar avatar ignored `avatarFilePath`): the chat page's AppBar still rendered `GroupAvatarCluster` for groups and the initials gradient for direct convs, even after Slice 10.3.5 (direct contact photo) and Slice 10.3.6 (group avatar sync). Fix: groups with a photo now render `ChatAvatar(avatarFilePath: ...)` and only fall back to the cluster when the path is empty; direct hero passes `avatarFilePath` through. Three surfaces (inbox tile, chat AppBar, call hero) now stay in lockstep. **Bug B** (call history wasn't visible inside the chat). `chat_call_log` was surfaced only on the Calls tab + the Chat Info page, not in the chat itself — Telegram weaves call rows into the message timeline so you see the call context inline. Fix: `ChatConversationPage` now subscribes to `CallLogRepository.watchAll()` alongside the messages stream, builds a `_TimelineEntry` list that merges messages + call logs sorted by time, and renders call entries as a new `_CallEntryBubble` (alignment by `callerId == currentUserId`, direction icon `call_made` / `call_received` / `call_missed`, missed in error red, tap to redial via `ConfigRouter.pushPageAnimation` to the matching voice/video page). Date separators + sender-group breaks still work — a call entry resets `lastSenderId` so the next bubble re-prints its header. ← **NEW**

#### Phase 10.2 — Voice & Video Calls
- Slice 10.2.1: Voice Call — WebRTC via `flutter_webrtc`, signalling over `/ws/voice/:callId`, incoming-call modal sheet (system-overlay), in-call screen with mute / speaker / keypad / end controls; requests `Permission.microphone` first; logs to `chat_call_log`
- Slice 10.2.2: Video Call — same WebRTC stack with both audio + video tracks, full-screen remote `RTCVideoRenderer` + draggable local PiP (mirrored front camera), auto-hide controls after 3s; requires both mic + camera permissions, handles partial grant; logs to `chat_call_log`
- Slice 10.2.3: Cross-device call ceremony (signalling-only stub) — gives the existing voice + video pages real two-device behaviour over the WebSocket relay **without** adding WebRTC. Extends the wire protocol with four envelope types (`call.invite` / `call.accept` / `call.reject` / `call.hangup`) and a new `CallSignalingService` that turns them into a typed `ActiveCall` state machine (`outgoingRinging → connected → ended`, plus an `incomingRinging` branch for the callee). A root-level `IncomingCallOverlay` (mounted via `MaterialApp.builder`) listens to the service and paints a full-screen Accept/Reject sheet over any route the callee happens to be on. Pressing **Accept** transitions both sides to `connected` and pushes the matching `VoiceCallPage` / `VideoCallPage` (now driven by the service instead of a local `Timer`), so the elapsed-time counter starts on both phones simultaneously. **No audio or video actually flows** — replacing the connected branch with real WebRTC offer/answer + ICE (which would ride the same transport) is Slice 10.2.4. The `chat_call_log` rows are written end-to-end so the call history / inbox previews stay accurate. ← **NEW**
- Slice 10.2.4: Busy signal — when User 1 is mid-call (`outgoingRinging` or `connected`) and User 3 fires a fresh `call.invite`, User 1's `CallSignalingService` auto-rejects with `reason: 'busy'` on the wire. The `CallRejectEvent` carries the reason back to User 3, which the call page surfaces both in the top-bar label (`Busy` instead of `Call ended`) and as a floating snackbar (`"User 1 is on another call."` / `"User 1 declined the call."`). Stale `incomingRinging` states from missed invites are *replaced* by new ones (instead of locking out follow-ups) and an aggressive 30s ring timeout auto-clears them so a phone that never showed the sheet can't get permanently stuck rejecting everything. ← **NEW**
- Slice 10.2.5: Call history (per-conversation + global Recent Calls) — surfaces the `chat_call_log` everywhere the user expects it. Per-conversation: a new section in Chat Info between Shared Media and Settings, showing the last 6 entries with direction icons (`call_made` / `call_received` / `call_missed`), missed-state in error red, duration, and a relative timestamp; tap re-opens the matching voice/video page. Global: a fourth tab **Calls** on the inbox `TabBar` that lists every log entry newest-first with a per-row direction badge sitting on the avatar, plus the same one-tap re-dial. ← **NEW**
- Slice 10.2.6: App lifecycle awareness — `ChatLifecycleBridge` registers a `WidgetsBindingObserver` from `bootChatTransport`; on `AppLifecycleState.resumed` it forces `transport.updateConfig(...)` to re-validate the socket, which kicks the existing 2-second reconnect chain when the OS killed the WebSocket while we were backgrounded. **Honest limitations** — the relay is a local-LAN demo, so two states cannot be made to work without a real backend: (1) **out-of-app for >30s** — the ring timeout fires before the user returns, so the call shows as missed; fixing this needs `flutter_local_notifications` with a heads-up notification + Accept/Reject actions; (2) **app killed entirely** — the WebSocket dies with the process, no relay event can wake it, and `chat_call_log` stays in `noAnswer`. Production path: FCM (Android) / APNs (iOS) high-priority push from a server-side relay, which the OS delivers to a background isolate that then shows the incoming-call sheet. Neither is wired here. ← **NEW**
- Slice 10.2.7: Targeted call routing — `call.invite` now carries `targetIds: List<String>` (callee user ids). The relay still fan-outs to every connected socket (no identity awareness on the server), but each callee's `CallSignalingService` filters: if the envelope's `targetIds` is non-empty and doesn't contain `settings.userId`, the invite is dropped silently. Direct conversations compute `[other_person]`; group conversations compute `[every participant except self]`. Empty list = pre-10.2.7 broadcast (kept for backwards compatibility with old clients on the wire). Companion seed change: direct conversations now carry a single-element `participantPreviews` so the caller actually knows the other person's `employeeId` — before this, a Demo-Approver → Channary call rang every connected client (including Vibol Sok on a third phone). ← **NEW**
- Slice 10.2.8: Accept actually opens the call page (+ independent group accepts) — fixes two bugs the user surfaced after 10.2.7. **Bug A** (individual + group): tapping **Accept** on the incoming sheet flipped `CallSignalingService` to `connected`, which immediately unmounted `IncomingCallOverlay` so the `if (!context.mounted) return;` guard right after the `await signaling.acceptIncoming()` swallowed the `Navigator.push` and the in-call page never opened — the sheet just disappeared and the call log row stayed in `answered` with no `endedAt`. Fix: capture the rootNavigator BEFORE doing anything, push the call page first, then fire-and-forget `acceptIncoming()` — the page subscribes to `activeCallListenable` in its initState so the connected-state transition is picked up either way (it reads `_signaling.current` if the transition lands during the build microtask, or via the listener if it lands later). **Bug B** (group only): the caller AND every other callee share the same `callId`, so when one callee accepted, all other callees' `_onEvent` saw `CallAcceptEvent` and ran `_setActive(copyWith(state: connected))` — which yanked them out of `incomingRinging` and closed their sheet without them ever choosing. Fix: in the `CallAcceptEvent` branch, return early if `active.state != outgoingRinging` so only the original caller transitions; every other callee stays ringing and gets to accept independently. ← **NEW**
- Slice 10.2.9: Accept-call via root navigator key + group call header — fixes two more bugs reported after 10.2.8. **Bug A** (accept STILL doesn't open the call page): the prior fix used `Navigator.of(context, rootNavigator: true)` from inside `IncomingCallOverlay`, but the overlay is mounted via `MaterialApp.builder` — i.e. the go_router Navigator is a SIBLING in the Stack, not an ancestor. `Navigator.of(context)` walked up the tree, found no Navigator, and silently dropped the push (the exception was caught and produced no visible error). Fix: added `AppRouter.rootNavigatorKey` (a `GlobalKey<NavigatorState>`) and attached it to `GoRouter(navigatorKey: ...)`. The accept handler now pushes via `AppRouter.rootNavigatorKey.currentState!.push(...)`, which goes through the actual root navigator regardless of where the overlay's context sits in the widget tree. **Bug B** (group call shows caller name): the incoming sheet on Pisey / Channary's phone showed `call.peerName` ("Vibol") for a group call to TEST01 — recipients had no way to tell whether the invite was a 1:1 or a group call. Fix: added `conversationName` + `isGroup` to `ActiveCall`, populated from `conversations.findById(...)` in both `startOutgoing` and the inbound `CallInviteEvent` handler. The sheet now renders the GROUP name as the title ("TEST01"), a `Icons.groups_rounded` cluster instead of caller initials, an "Incoming group voice/video call" top label, and "Vibol is calling…" as a subtitle so the recipient still knows WHO triggered it. Direct calls keep the pre-10.2.9 look. ← **NEW**
- Slice 10.2.10: Group multi-party hangup + group call photo + Telegram-style call history on inbox tiles — three bugs reported after 10.2.9. **Bug A** (one End kills everyone in a group call): `CallHangupEvent` was processed by every peer regardless of who pressed End, so when Pisey tapped End in a group with Demo + Vibol + Pisey, all three call pages closed. Fix: added `hangerUpperId` to `CallHangupEvent` (caller stamps it from `settings.userId`) and `callerId` to `ActiveCall` (populated in both `startOutgoing` and the inbound `CallInviteEvent` handler). On receive, when `active.isGroup` and `hangerUpperId` is neither the original `callerId` nor ourselves, drop the event — the rest of the group stays connected and the timer keeps ticking. The original caller's End still ends the call for everyone (their bow-out is canonical). Direct 1:1 calls keep the pre-10.2.10 "either side ends it" behaviour because there's nobody else to stay connected with. Pre-10.2.10 clients without `hangerUpperId` fall back to "everyone ends" for back-compat. **Bug B** (group call shows initials, not the uploaded group photo): both `VoiceCallPage._PulsingAvatar` and `VideoCallPage` placeholder cards rendered `GroupAvatarCluster(previews:)` for groups regardless of whether a `avatarFilePath` was set. Fix: render `ChatAvatar(avatarFilePath: conversation.avatarFilePath)` whenever a photo exists; fall back to the cluster only when null. Direct calls already had the field but weren't passing it through — also fixed. **Bug C** (call history hidden on the Calls tab — Telegram surfaces it inline). New `CallSignalingService._writeCallSummary(...)` hooks into all four end paths (local `hangup`, local `rejectIncoming`, peer `CallRejectEvent`, peer `CallHangupEvent`) and writes a per-type summary into `conversations.updateLastMessage(...)` — `📞 Voice call · 5:23` for answered, `📞 Missed voice call` for missed, `📞 Declined video call` for rejected (video uses `📹`). `senderId = active.callerId` so the inbox `_previewFor` adds "You: " for the caller and bare text for the callee. Net effect: the inbox tile mirrors what Telegram's "Recent" list shows for every conversation. ← **NEW**
- Slice 10.2.11: Last-callee-out auto-ends the group call + group photo on incoming sheet + direct-call summary lands in the right tile — three follow-ups after 10.2.10. **Bug A** (caller stranded after every callee leaves a group call): Slice 10.2.10 stopped a single callee's End from killing everyone, but the caller was then left alone with a running timer when every callee bowed out — there was nobody else in the call. Fix: added `accepterId` to `CallAcceptEvent` (callee stamps it from `settings.userId`) and a caller-only `Set<String> _activeCallees` tracked in `CallSignalingService`. The caller adds an id when a peer accepts (state stays `connected` for any accepts beyond the first so additional joiners get tracked) and removes one on each non-caller `CallHangupEvent`. When the set drains to empty, the caller fires its own `hangup(...)` so the timer stops and the call page pops — Telegram's last-person-out behaviour. **Bug B** (group photo missing on the incoming sheet itself): the in-call hero rendered the photo (Slice 10.2.10) but the modal sheet shown by `IncomingCallOverlay` only had a group icon. Fix: added `conversationAvatarFilePath` to `ActiveCall`, populated from `conv?.avatarFilePath` in both `startOutgoing` and the inbound invite handler; the overlay now wraps the hero in a new `_IncomingAvatar` widget that paints the file via `DecorationImage(FileImage(...))` when one exists, falling back to the group icon (groups) or caller initials (direct). **Bug C** (call summary on a direct call landed in the wrong inbox tile on the callee): `_writeCallSummary` wrote to `active.conversationId`, which on the receiver was the caller's local conv id — different from the callee's local conv-with-caller because the seed reuses ids per device (same bug Slice 10.1.8 fixed for messages). Fix: for non-group calls, look up `conversations.findDirectWith(otherId)` and redirect the summary there. Group calls use the shared conv id verbatim (Slice 10.1.7 broadcast). ← **NEW**

#### Phase 10.3 — Chat Admin
- Slice 10.3.1: Conversation Info / Chat Settings — different layouts for direct vs group conversations, shared-media grid, mute toggle, pinned-message row; group view adds member list with admin badges and admin-only options (add/remove members, promote, rename, edit avatar, leave group); shared "Clear Chat History" (device-local only)
- Slice 10.3.2: Add Members — admin-gated modal sheet that lists every directory employee NOT already in the group, with a search bar and multi-select checkboxes. Confirm pushes the picks through `ConversationsRepository.addMembers(...)` which de-dups against current `participantPreviews` and bumps `totalMembers` + `onlineCount`. Reachable from the Quick Actions row + the future "Add" trailing button on the Members section header. ← **NEW**
- Slice 10.3.3: Change Group Profile — admin-gated edits to the group's identity in the Chat Info hero. Tapping the **group avatar** opens a camera/gallery/remove sheet powered by `image_picker`; the picked file path persists on the new `ChatConversation.avatarFilePath` field and is rendered by `ChatAvatar` via `FileImage`, falling back to the participant cluster when null. Tapping the **group name** (or the pencil affordance beside it) opens a rename sheet whose Save button is disabled until the name actually changed. Both flows route through `ConversationsRepository` (`setAvatarPath` / `rename`) so the inbox tile + AppBar update reactively. ← **NEW**
- Slice 10.3.4: Profile + group rename sync — extends 10.3.3 / 9.1.4 so identity changes propagate across devices. Two new wire envelopes: **`conversation.update`** (`ConversationUpdatedEvent`) carries `{ conversationId, name, participantIds }`. `_showRenameSheet` in `chat_info_page.dart` broadcasts it after `ConversationsRepository.rename(...)`; `bootChatTransport` filters by participantIds, looks up the conv, and applies `rename(...)` locally — so when Channary renames `CHAT01` → `TEST01`, Vibol and Pisey's inboxes + AppBars rename live without re-opening the chat. **`profile.update`** (`ProfileUpdatedEvent`) carries `{ userId, newName }`. `ChatSettings.setIdentity` fires it when the same user keeps their id but changes their display name; on the peer side, `bootChatTransport` calls `ConversationsRepository.findDirectWith(userId)` and renames the matching local direct conv — so when Vibol renames himself, Pisey's "Vibol Sok" tile + AppBar pick up the new name. **Avatar is NOT broadcast** because the demo's avatars are local `image_picker` file paths that don't exist on peer devices; production would route through an upload endpoint and broadcast the resulting URL. ← **NEW**
- Slice 10.3.5: Set photo for direct chats (Telegram "Set contact photo") — until now `avatarFilePath` was group-only; direct convs rendered initials with no way to override. The Chat Info hero is now tap-to-change for BOTH direct and group conversations, the camera-pencil badge is always shown, and the sheet header text adapts ("Change contact photo" / "Change group photo") via a new `_photoSheetTitle(...)` helper. `ChatAvatar(avatarFilePath:)` was already wired through; the direct-conv hero just wasn't passing the field. Inbox tiles match — `chat_inbox_page.dart` now prefers the user-set photo over both the group cluster (groups) and initials (direct), keeping all three surfaces (Hero, AppBar, inbox tile) in lockstep. Per-device only — broadcasting the file path is meaningless, and adding an upload endpoint is out of scope for the demo. ← **NEW**
- Slice 10.3.6: Group avatar sync — when Channary picks a photo for group TEST01, every member's inbox tile + AppBar + call hero now picks it up too. The 10.3.4 sync covered name only; avatars stayed per-device because the path is local. Fix: new `conversation.avatar.update` envelope (`ConversationAvatarUpdatedEvent`) carries `{ conversationId, participantIds, avatarBase64, fileExtension }`. The sender (`_pickGroupPhoto` in `chat_info_page.dart`) reads the picked file (already sized to 1024×1024 / quality 85 by image_picker, typically 50–200 KB), base64-encodes, and broadcasts. The receiver (`_applyInboundAvatarUpdate` in `chat_di.dart`) filters by participantIds, decodes the bytes, writes them to `getApplicationCacheDirectory()` under `chat_avatar_<conversationId>.<ext>` (deterministic name = next sync overwrites the same file, no leak), then calls `ConversationsRepository.setAvatarPath(...)` with the new local path. A null `avatarBase64` means "admin removed the photo" — peers clear their own path too. Direct conv photos stay per-device (Slice 10.3.5) — no peer envelope. Limitation: in a hypothetical production stack the bytes would go to an upload endpoint and only the URL would ride this envelope. ← **NEW**

> Note: per the design guide, Module 10 was restructured from 5 → 7 screens (net +2). All 7 are listed above across the 3 phases. Slices 10.3.2 and 10.3.3 extend the existing Conversation Info screen — no new pages.

---

## Development Guardrails

### What TO do
- Keep BLoC events/states **immutable** — hand-written classes; unions are Dart 3 `sealed class` with `factory` redirects (no `freezed`)
- Give every value type explicit `==`/`hashCode`/`copyWith`; use `package:collection` equality for list/map fields so `BlocBuilder` dedupes correctly
- Business rules live in the Repository (or, when stateful, the BLoC) — not in widgets
- Repository is a single concrete class; it owns the `dio`/STOMP/`shared_preferences` calls directly
- Resolve cross-cutting services from the in-house `getIt`; register them in `register_module.dart` or the feature's `*_di.dart`
- All forms use a dedicated `FormBLoC` with field-level validation
- Write unit tests per slice before moving to the next

### What NOT to do
- **Do not reintroduce** `drift`/`sqlite`, `get_it`/`injectable`, `freezed`, `equatable`, or the offline sync engine — see the "Removed" table at the top
- No business logic in widgets
- No direct API calls from BLoC — always through the Repository
- No `BuildContext` inside BLoC
- No hardcoded strings — always use l10n ARB keys
- No commercial/paid packages — validate every package on pub.dev for open-source license (MIT, BSD, Apache 2.0)
- Don't share BLoC instances across unrelated modules — use scoped BLoC providers
- Don't introduce new `UseCase` classes or abstract repository interfaces — new code stays flat

### Legacy modules
The surviving original modules (Auth, Dashboard, Settings) still contain
`domain/usecases/` + `domain/repositories/` (abstract). Honour that
convention when editing them — don't mix flat and layered styles inside the
same feature. New code uses flat MVVM (above).

---

## Recommended Build Order

As-built (Modules 3–8 removed):

```
Phase 0 (Core) → Module 1 (Auth) → Module 2 (Dashboard)
   → Module 9 (Settings)
   → Module 10 (Chat & Voice/Video)  [STOMP + Stream Video stack]
```

> The original order also chained Modules 3–8 (Finance, Procurement,
> Inventory, Sales, HR, Projects) — all deleted. The detailed specs for
> those modules remain below as historical reference only.

---

> **Note on the appended design guide:** the screen specs for the deleted
> Modules 3–8 (Finance, Procurement, Inventory, Sales, HR, Projects) have
> been removed. What remains specs the **live** modules (0, 1, 2, 9, 10).
> Some passing references (module icon colours, the aspirational 6-tab nav,
> example permission strings) still name those domains — treat them as
> illustrative, not as-built.

# Appended: ERP Mobile Design Guide

> Verbatim copy of [`ERP_MOBILE_DESIGN_GUIDE.md`](./ERP_MOBILE_DESIGN_GUIDE.md), inlined here for single-file reference.
> The standalone file remains the canonical source — edit it there, then re-sync.

# ERP Mobile Flutter — Complete Design & Coding Standards
> Single source of truth for all 72 screens. Use this file when prompting Claude Code.
> Covers: design tokens · component patterns · coding rules · per-screen layout intent · BLoC/SQLite spec · prompt template.

---

## Table of Contents

1. [Design Philosophy](#1-design-philosophy)
2. [Design Tokens (AppTheme singleton)](#2-design-tokens-apptheme-singleton)
3. [Shared Component Patterns](#3-shared-component-patterns)
4. [Navigation Structure](#4-navigation-structure)
5. [Motion & Animation Rules](#5-motion--animation-rules)
6. [Coding Standards & Architecture Rules](#6-coding-standards--architecture-rules)
7. [Screen Specifications (as-built modules)](#7-screen-specifications--as-built-modules)
   - [Module 0 — App Entry](#module-0--app-entry)
   - [Module 1 — Authentication & Identity](#module-1--authentication--identity)
   - [Module 2 — Dashboard & Home](#module-2--dashboard--home)
   - [Module 9 — Settings & Administration](#module-9--settings--administration) *(+2 new screens)*
   - [Module 10 — Chat & Voice](#module-10--chat--voice) *(new module, 5 screens)*
8. [Screen Complexity Summary](#8-screen-complexity-summary)
9. [Claude Code Prompt Template](#9-claude-code-prompt-template)

---

## 1. Design Philosophy

**Clean. Spacious. Data-first.**

This is an enterprise tool used daily by real workers — accountants, warehouse staff, HR managers. The design must feel modern but never trendy. Every pixel must earn its place.

**Three principles:**

- **Clarity over decoration** — users need to find data fast, not admire animations
- **Density with breathing room** — ERP has a lot of data; use cards and sections, never walls of text
- **Calm confidence** — muted colors, consistent spacing, no aggressive CTAs

---

## 2. Design Tokens (AppTheme singleton)

> All values live in a single `AppTheme` singleton.
> **Never hardcode colors, sizes, or fonts anywhere in widget code.**

### 2.1 Colors

```dart
// Primary palette — deep indigo, professional
primary:            Color(0xFF3B4FE8)   // buttons, active states, links
onPrimary:          Color(0xFFFFFFFF)
primaryContainer:   Color(0xFFE8EBFF)  // chip backgrounds, light badges

// Surface
surface:            Color(0xFFF8F9FC)  // page background (light)
surfaceVariant:     Color(0xFFEEF0F5)  // card background, input fill
onSurface:          Color(0xFF1A1D23)  // primary text
onSurfaceVariant:   Color(0xFF6B7280)  // secondary text, placeholders

// Status colors
success:  Color(0xFF16A34A)  // APPROVED, in-stock, on-time
warning:  Color(0xFFD97706)  // PENDING, low-stock, expiring
error:    Color(0xFFDC2626)  // REJECTED, overdue, failed
info:     Color(0xFF0284C7)  // neutral status, info banners

// Status container variants (backgrounds for chips/badges)
successContainer: Color(0xFFDCFCE7)
warningContainer: Color(0xFFFEF3C7)
errorContainer:   Color(0xFFFEE2E2)
infoContainer:    Color(0xFFE0F2FE)

// Dark mode overrides
// surface → Color(0xFF0F1117), cards → Color(0xFF1A1D23)
```

### 2.2 Typography — AppLabel

```dart
// All text uses Inter font family
// Register in AppLabel singleton — never use raw TextStyle in widgets

AppLabel.displayLarge   // 32sp, w700 — splash app name only
AppLabel.headlineLarge  // 24sp, w700 — page titles
AppLabel.headlineMedium // 20sp, w600 — section headers, card titles
AppLabel.titleMedium    // 16sp, w600 — list tile titles, tab labels
AppLabel.bodyLarge      // 16sp, w400 — body text, descriptions
AppLabel.bodyMedium     // 14sp, w400 — secondary info, subtitles
AppLabel.bodySmall      // 12sp, w400 — timestamps, captions, version text
AppLabel.labelLarge     // 14sp, w600 — button labels
AppLabel.labelSmall     // 11sp, w500 — status chips, badges
```

### 2.3 Spacing — AppSpacing

```dart
AppSpacing.xs   =  4.0
AppSpacing.sm   =  8.0
AppSpacing.md   = 16.0
AppSpacing.lg   = 24.0
AppSpacing.xl   = 32.0
AppSpacing.xxl  = 48.0
```

### 2.4 Border Radius — AppRadius

```dart
AppRadius.sm   =  8.0   // chips, small badges
AppRadius.md   = 12.0   // input fields, small cards
AppRadius.lg   = 16.0   // main cards, bottom sheets
AppRadius.xl   = 24.0   // FAB, large modal sheets
AppRadius.full = 999.0  // pill-shaped chips
```

### 2.5 Elevation / Shadows

```dart
AppShadow.card = BoxShadow(
  color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2),
)
AppShadow.modal = BoxShadow(
  color: Color(0x1A000000), blurRadius: 24, offset: Offset(0, 8),
)
```

### 2.6 Module Icon Colors

```
Finance      → indigo (primary)
Inventory    → orange
HR           → purple
Sales        → green
Procurement  → teal
Projects     → blue
```

---

## 3. Shared Component Patterns

### AppCard
Every content block lives in a card. **Never raw containers.**
```
white bg · AppRadius.lg · AppShadow.card · padding AppSpacing.md
```

### StatusChip
```
pill shape · AppRadius.full · labelSmall text · status color map:

  DRAFT            → surfaceVariant bg,    onSurfaceVariant text
  PENDING_APPROVAL → warningContainer bg,  warning text
  APPROVED         → successContainer bg,  success text
  REJECTED         → errorContainer bg,    error text
  ACTIVE           → successContainer bg,  success text
  ON_HOLD          → warningContainer bg,  warning text
  COMPLETED        → infoContainer bg,     info text
```

### SectionHeader
```
headlineMedium text · left-aligned · bottom padding AppSpacing.sm
optional trailing TextButton (labelLarge)
```

### EmptyState
```
centered column · illustration (80×80) · headlineMedium title
· bodyMedium subtitle · optional FilledButton CTA
```

### LoadingShimmer
```
shimmer skeleton matching real layout shape — never blank screen
never CircularProgressIndicator alone on lists
```

### FAB
```
primary color · AppRadius.xl · icon+label (extended) on tablet
icon only on mobile · bottom-right · never covers key content
```

### InputField (all forms)
```
filled style · surfaceVariant fill · no border at rest
primary border 2px on focus · AppRadius.md
prefixIcon where applicable · error text below on invalid
```

### ApprovalTimeline
```
vertical list with connector line between steps
each step: avatar · name · action chip · timestamp
used in: Invoice Detail, PR Detail, Leave Approval
```

### PermissionGuard
```
wraps any widget that requires a specific RBAC scope
PermissionGuard(scope: 'finance.approve') { ... }
renders nothing (or disabled state) if user lacks permission
```

---

## 4. Navigation Structure

```
BottomNavigationBar (mobile):
  Dashboard · Finance · Inventory · HR · Chat · More (→ side sheet)

NavigationRail (tablet, always visible left):
  Same 6 items + expanded text labels

"More" side sheet expands to show:
  Procurement · Sales · Projects · Settings
```

**Chat badge:** unread message count badge on Chat nav item (warningContainer bg, labelSmall)

**Page transitions:**
- Bottom nav: fade-through
- Push routes: slide-from-right
- Back: slide-to-right (default)

---

## 5. Motion & Animation Rules

| Element | Animation | Duration |
|---|---|---|
| Page (bottom nav) | fade-through | system default |
| Page (push) | slide-from-right | system default |
| List items | staggered fade-in, 50ms delay per item | 300ms max total |
| Bottom sheets | slide up | 300ms ease-out |
| Status chips | AnimatedSwitcher crossfade on status change | 200ms |
| Buttons | AnimatedScale 0.97 on press | 100ms |
| Errors | horizontal shake on PIN fail / form submit fail | 300ms |
| Loading | LoadingShimmer skeleton | — |
| Splash logo | fade + scale | 900ms easeOutBack |
| Biometric icon | soft pulse scale 1.0→1.08→1.0 | 1.5s repeat |

**Never:** bounce, spin, or add gratuitous motion — this is a work tool.

---

## 6. Coding Standards & Architecture Rules

### 6.1 Non-negotiable rules

- **Never hardcode** colors, sizes, or fonts — use `AppTheme`, `AppLabel`, `AppSpacing`, `AppRadius` exclusively
- **Never use raw containers** as content blocks — always `AppCard`
- **Never show a blank screen** while loading — always `LoadingShimmer` on lists
- **Never unguard admin actions** — wrap with `PermissionGuard(scope: '...')`
- **Never use raw `TextStyle`** in widget code — always `AppLabel`

### 6.2 Widget architecture

- Split into **small private widget classes** — one per visual section
- Add `buildWhen` on **every `BlocBuilder`** to minimise rebuilds
- Show `EmptyState` widget whenever any list is empty
- Use `StatusChip` from the shared status color map — no custom chips
- Use `LoadingShimmer` instead of `CircularProgressIndicator` on list screens

### 6.3 BLoC patterns

```dart
// Standard BLoC shape — all screens follow this
Events: [Entity]Loaded, [Action]Requested, FilterChanged, etc.
States: [Entity]Initial → [Entity]Loading → [Entity]Loaded / [Entity]Failure

// Forms use this extended pattern
States: [Form]Initial → [Form]Valid / [Form]Invalid → [Form]Saving
      → [Form]Success / [Form]Failure
```

### 6.4 Data / state rules

- All SQLite reads happen in BLoC — never in widget `build()`
- Admin screens (`/settings/admin/*`) read from API only — no local cache (security)
- Splash screen uses only local SQLite + `flutter_secure_storage` — no network calls
- PIN hash stored in `flutter_secure_storage`, not SQLite
- Offline transactions enqueue to `sync_queue` SQLite table; `SyncStatusBLoC` surfaces status
- Optimistic UI updates for stock transactions — revert on API failure

### 6.5 Form rules

- All forms use `FormBLoC` for validation state
- Save Draft = upsert to SQLite; Submit = POST to API
- Line item forms must support dynamic add/remove rows
- Show running totals reactively as fields change

### 6.6 Approval flow pattern

Used in: Invoice (3.4), Purchase Request (4.3), Leave (7.6)

```
DetailBLoC   — loads the document
ActionBLoC   — handles approve/reject
  Events:    [Entity]Approved(id) / [Entity]Rejected(id, reason)
  States:    ActionLoading → ActionSuccess / ActionFailure

UI pattern:
  ActionRow (sticky bottom, visible only when status=PENDING + user has permission)
    RejectButton (OutlinedButton, error color, half width)
    ApproveButton (FilledButton, success color, half width)

  RejectBottomSheet (modal):
    drag handle · "Reason for rejection" headlineMedium
    ReasonTextField (multiline, 3 rows min) · character count
    ConfirmRejectButton (FilledButton, error, full width)
```

### 6.7 List screen pattern

Used universally across all list screens:

```
FilterChips row (horizontal scroll, if applicable)
SearchBar (surfaceVariant fill, AppRadius.md)
ListView
  LoadingShimmer while state = Loading
  EmptyState if state = Empty
  ListView.separated of [Entity]Tile (AppCard, AppSpacing.sm gap) if Loaded
FAB (create action, if user has create permission)
```

### 6.8 Detail screen pattern

Used universally across all detail screens:

```
AppBar: entity name/number · optional overflow menu
SingleChildScrollView
  [Entity]HeaderCard (AppCard) — key metadata in 2-column grid
  StatusChip (large, centered, pill) — if entity has status
  SectionHeader "[Section Name]"
  [Content] (AppCard)
  ...more sections...
  ActionRow (sticky bottom, conditional on status + permission)
```

---

## 7. Screen Specifications (as-built modules)

> Specs below cover the **live** modules only (0, 1, 2, 9, 10). The
> Finance/Procurement/Inventory/Sales/HR/Projects screen specs were removed
> with those modules.

> For each screen: **Feel** = design intent. **Layout** = widget tree. **BLoC** = state machine. **SQLite** = local tables used.

---

### Module 0 — App Entry

---

#### Screen 0.1 — Splash Screen
**Complexity: M** | **Route:** `/` (initial, always replaced)

**Feel:** Calm, minimal, centered. Brand moment before work begins.

**Layout:**
```
Full screen, surface bg
  ├── Center (flex 1)
  │     ├── Rounded square icon (96×96, AppRadius.xl, primary bg)
  │     │     fade + scale animation 900ms easeOutBack
  │     └── App name — displayLarge, AppSpacing.md below icon
  └── Bottom pinned, AppSpacing.xxl from bottom
        ├── CircularProgressIndicator (24×24, strokeWidth 2) while loading
        │     AnimatedSwitcher → invisible once routing done
        └── Version text — bodySmall, onSurfaceVariant
        │     If DB migration needed: "MigratingDatabaseText" replaces version text
```

**Do:** Logo + name + subtle spinner only.
**Don't:** No gradients, no marketing copy, no network calls.

**BLoC:** `AppInitBLoC`
```
Events: AppStarted
States: AppInitLoading → AppInitAuthenticated / AppInitUnauthenticated / AppInitLocked

On AppStarted:
  1. Check flutter_secure_storage for existing tokens
  2. Read cached_user from SQLite — if present and TTL valid, user is known
  3. Read biometric_on flag from SQLite
  4. Decide redirect:
     - No token            → /login
     - Token + biometric   → /biometric-unlock
     - Token + PIN policy  → /lock
     - Token valid         → /dashboard
```

**SQLite tables:** `cached_user` (read id, biometric_on, last_login_at, cached_at for TTL check)

**Notes:**
- Only screen with no back navigation — always replaced, never pushed
- Keep animation under 1.5s; do not block on network calls

---

### Module 1 — Authentication & Identity

---

#### Screen 1.1 — Login
**Complexity: M** | **Route:** `/login`

**Feel:** Professional, welcoming. Single column, no clutter.

**Layout:**
```
Scaffold, surface bg, SingleChildScrollView
  padding: horizontal AppSpacing.lg, vertical AppSpacing.xl
  ├── App icon (52×52, AppRadius.md, primaryContainer bg)
  ├── AppSpacing.lg
  ├── "Welcome back" — headlineLarge
  ├── "Sign in to your account" — bodyMedium, onSurfaceVariant
  ├── AppSpacing.xxl
  ├── EmailField (prefixIcon: email)
  ├── AppSpacing.md
  ├── PasswordField (suffixIcon: visibility toggle)
  ├── "Forgot password?" — Align.right TextButton, bodySmall
  ├── AppSpacing.xl
  ├── SignInButton — FilledButton, full width, 52px height
  │     loading: replace label with CircularProgressIndicator 20×20
  │     disabled: 38% opacity
  ├── AppSpacing.md
  ├── BiometricButton — OutlinedButton, full width (hidden if biometric_on=false)
  │     icon: fingerprint + "Sign in with Biometrics"
  └── ErrorCard (AnimatedSwitcher, errorContainer bg)
        error icon + message text, AppRadius.md
```

**Don't:** No card wrapping the whole form. No "create account" link.

**BLoC:** `AuthBLoC`
```
Event: LoginSubmitted(email, password)
States: AuthInitial → AuthLoading → AuthSuccess / AuthFailure
On success → go_router redirects to /dashboard
```

**SQLite tables:** `cached_user` (read biometric_on flag on init)

---

#### Screen 1.2 — Biometric Unlock
**Complexity: S** | **Route:** `/biometric-unlock`

**Feel:** Secure, reassuring. OS lock screen energy.

**Layout:**
```
Full screen, centered column
  ├── User avatar (64×64 circle, initials fallback)
  ├── User name — titleMedium
  ├── AppSpacing.xl
  ├── Biometric icon (72×72, primary color)
  │     soft pulse animation: scale 1.0→1.08→1.0, repeat, 1.5s
  ├── "Touch sensor to unlock" — bodyMedium, onSurfaceVariant
  ├── AppSpacing.xl
  └── "Use password instead" — TextButton → /login
```

**BLoC:** `BiometricBLoC`
```
Event: BiometricRequested
States: BiometricPrompting → BiometricSuccess / BiometricFailure
```

**SQLite tables:** `cached_user` (read biometric_on, last_login_at)

---

#### Screen 1.3 — OTP / MFA Verification
**Complexity: M** | **Route:** `/mfa`

**Feel:** Focused, single-task. Nothing distracting.

**Layout:**
```
Scaffold
  ├── Back arrow (top left)
  ├── padding AppSpacing.lg
  ├── Shield icon (48×48, primaryContainer bg circle)
  ├── "Verification code" — headlineLarge
  ├── "Sent to +66 *** 1234" — bodyMedium, onSurfaceVariant
  ├── AppSpacing.xl
  ├── OtpInputRow — 6 boxes, 48×56 each, AppRadius.md
  │     active: primary border · filled: surfaceVariant bg + titleMedium digit
  │     auto-advance on input, auto-retreat on delete
  ├── AppSpacing.lg
  ├── VerifyButton — FilledButton full width (enabled when 6 digits filled)
  └── "Resend code (29s)" — TextButton, disabled during cooldown timer
```

**BLoC:** `MfaBLoC`
```
Event: OtpSubmitted(code)
States: MfaInitial → MfaLoading → MfaSuccess / MfaFailure
```

**SQLite tables:** None — OTP is memory only (ephemeral)

---

#### Screen 1.4 — Forgot Password
**Complexity: S** | **Route:** `/forgot-password`

**Feel:** One job. Enter email, receive link.

**Layout:**
```
Scaffold
  ├── Back arrow
  ├── padding AppSpacing.lg
  ├── Email icon (48×48, primaryContainer bg)
  ├── "Reset password" — headlineLarge
  ├── "We'll send a reset link to your email" — bodyMedium, onSurfaceVariant
  ├── AppSpacing.xl
  ├── EmailField
  ├── AppSpacing.md
  └── SendResetButton — FilledButton, full width
        success state: swap to green checkmark + "Check your email"
```

**BLoC:** `ForgotPasswordBLoC`
```
Event: ResetRequested(email)
States: ForgotPasswordInitial → ForgotPasswordLoading
      → ForgotPasswordSent / ForgotPasswordFailure
```

**SQLite tables:** None

---

### Module 2 — Dashboard & Home

---

#### Screen 2.1 — Dashboard Home
**Complexity: L** | **Route:** `/dashboard`

**Feel:** Control room. Data-rich, breathing room. KPIs are the hero.

**Layout:**
```
Scaffold
  ├── AppBar: app logo (left) · search icon · NotificationBadge (right)
  ├── SyncStatusBanner (slide-in below AppBar, warningContainer bg)
  │     only visible on SyncPending or SyncFailed state
  └── SingleChildScrollView
        ├── GlobalSearchBar (surfaceVariant fill, AppRadius.md, search icon)
        ├── AppSpacing.md
        ├── SectionHeader "Overview"
        ├── KpiCardGrid — 2-column GridView, shrinkWrap
        │     Each KpiCard (AppCard):
        │       module icon circle (24×24, colored by module)
        │       KPI label — bodySmall, onSurfaceVariant
        │       Value — headlineMedium
        │       Trend row — arrow icon + % change (success/error color)
        │       Sparkline — fl_chart LineChart, 40px height, no axes
        ├── AppSpacing.md
        ├── SectionHeader "Quick Access"
        └── ModuleShortcutGrid — 3-column, permission-filtered
              Each tile: icon (40×40 circle) + module name (bodySmall)
  BottomNavigationBar (mobile) / NavigationRail (tablet)
```

**BLoC:**
- `KpiBLoC` — Event: `KpiRefreshRequested`; streams from `KpiRepository` (WebSocket + SQLite fallback)
- `SyncStatusBLoC` — listens to sync engine; emits `SyncIdle / SyncPending / SyncFailed`
- `NotificationBadgeBLoC` — reads unread count from SQLite

**SQLite tables:** `cached_kpi`, `cached_dashboard_layout`, `cached_notifications` (unread count)

---

#### Screen 2.2 — Global Search
**Complexity: M** | **Route:** `/search`

**Feel:** Fast, instant results as you type.

**Layout:**
```
Scaffold (no AppBar — search IS the top element)
  ├── padding AppSpacing.md
  ├── SearchRow: back arrow + SearchTextField (autofocus) + clear X
  ├── Divider
  ├── RecentSearchesRow — horizontal scroll chips (bodySmall, surfaceVariant)
  └── SearchResultList
        grouped by module with SectionHeader per group
        Each SearchResultTile (ListTile):
          leading: module color icon circle (40×40)
          title: titleMedium
          subtitle: bodySmall, onSurfaceVariant
          trailing: chevron right
        EmptyState if no results: magnifier illustration + "No results found"
```

**BLoC:** `GlobalSearchBLoC`
```
Event: SearchQueryChanged(query)
States: SearchInitial → SearchLoading → SearchResults(results) / SearchEmpty
```

**SQLite tables:** None (search hits remote API; results not cached)

---

#### Screen 2.3 — Notification Center
**Complexity: M** | **Route:** `/notifications`

**Feel:** Inbox. Clear read/unread hierarchy.

**Layout:**
```
Scaffold
  ├── AppBar: "Notifications" · "Mark all read" TextButton trailing
  └── Body
        EmptyState (bell illustration) if empty
        ListView of NotificationTile (AppCard, AppSpacing.sm gap):
          ├── Leading: module icon circle (40×40, color by notification type)
          ├── Unread indicator: 3px primary left border + primaryContainer bg tint
          ├── Title — titleMedium (w600 if unread, w400 if read)
          ├── Body — bodySmall, onSurfaceVariant, max 2 lines
          └── Timestamp — bodySmall, onSurfaceVariant, right-aligned
```

**BLoC:** `NotificationBLoC`
```
Events: NotificationsLoaded, NotificationMarkedRead(id), AllNotificationsMarkedRead
States: NotificationInitial → NotificationLoaded(list) / NotificationEmpty
```

**SQLite tables:** `cached_notifications` (read, update is_read)

---

### Module 9 — Settings & Administration

---

#### Screen 9.1 — Settings Home
**Complexity: S** | **Route:** `/settings`

**Feel:** Clean menu. User identity at top, grouped options below.

**Layout:**
```
Scaffold
  ├── AppBar: "Settings"
  └── SingleChildScrollView
        ├── UserProfileCard (AppCard, primaryContainer bg)
        │     avatar 56×56 · name titleMedium · role chip + email bodySmall
        ├── AppSpacing.md
        ├── SectionHeader "Preferences"
        ├── SettingsGroup (AppCard)
        │     ThemeRow · LanguageRow · NotificationsRow
        │     each row: leading icon · label titleMedium · trailing arrow or value
        ├── AppSpacing.md
        ├── SectionHeader "Security"
        ├── SettingsGroup (AppCard)
        │     SessionsRow · AuditLogRow · PinLockRow
        ├── AppSpacing.md
        ├── SectionHeader "Admin" (PermissionGuard — admin only)
        ├── SettingsGroup (AppCard)
        │     UsersRow · RolesRow · EnvironmentRow
        ├── AppSpacing.lg
        └── LogoutButton — OutlinedButton, error color, full width
```

**BLoC:** None (static navigation screen)

**SQLite tables:** `cached_user` (read name, avatar)

---

#### Screen 9.2 — User Preferences
**Complexity: S** | **Route:** `/settings/preferences`

**Feel:** Clean toggles. Theme change previews instantly.

**Layout:**
```
Scaffold
  ├── AppBar: "Preferences"
  └── SingleChildScrollView
        ├── SectionHeader "Appearance"
        ├── ThemeCard (AppCard)
        │     3-option segmented button:
        │     Light (sun icon) · Dark (moon icon) · System (phone icon)
        ├── AppSpacing.md
        ├── SectionHeader "Language"
        ├── LanguageCard (AppCard, ListTile)
        │     current language label + chevron
        │     tap → LanguagePickerBottomSheet (list of locales)
        ├── AppSpacing.md
        ├── SectionHeader "Notifications"
        └── NotificationCard (AppCard)
              Each NotificationPrefRow: icon · label · Switch (right)
              types: Approvals · Inventory alerts · Leave updates · System
```

**BLoC:** `PreferencesBLoC`
```
Events: ThemeChanged(mode), LanguageChanged(locale), NotificationPrefToggled(type)
States: PreferencesLoaded(prefs) → PreferencesUpdated
```

**SQLite tables:** `cached_user_preferences` (theme, locale, notif_prefs JSON)

---

#### Screen 9.3 — Active Sessions
**Complexity: M** | **Route:** `/settings/sessions`

**Feel:** Security panel. Current device highlighted, easy revoke.

**Layout:**
```
Scaffold
  ├── AppBar: "Active Sessions"
  ├── CurrentSessionBanner (infoContainer bg, AppSpacing.md padding)
  │     "This device" label · device name + OS
  └── ListView of SessionTile (AppCard, AppSpacing.sm gap)
        ├── Device icon circle (40×40, surfaceVariant): phone/tablet/desktop
        ├── Device name — titleMedium
        ├── OS + "Last active {time}" — bodySmall, onSurfaceVariant
        └── RevokeButton — TextButton, error color (hidden for current device)
  Bottom: "Revoke all other sessions" OutlinedButton, error, full width
```

**BLoC:** `SessionManagementBLoC`
```
Events: SessionsLoaded, SessionRevoked(sessionId), AllOtherSessionsRevoked
States: SessionsLoading → SessionsLoaded(list) / SessionsFailure
```

**SQLite tables:** None (reads from API only — no local cache for security)

---

#### Screen 9.4 — Audit Log Viewer
**Complexity: M** | **Route:** `/settings/audit`

**Feel:** Read-only record. Filterable, tappable for full detail.

**Layout:**
```
Scaffold
  ├── AppBar: "Audit Log"
  ├── FilterRow (horizontal scroll chips):
  │     User · Module · Action type · Date range
  └── ListView of AuditLogTile (AppCard, AppSpacing.xs gap)
        ├── Leading: action icon circle (40×40, color by action type)
        │     create=success · update=info · delete=error · approve=primary
        ├── Center: action label (titleMedium) · user + module (bodySmall)
        └── Trailing: timestamp (bodySmall, onSurfaceVariant)
        tap → AuditLogDetailBottomSheet (360px):
          full action description
          record reference (tappable deep link)
          raw payload (monospace bodySmall, scrollable)
```

**BLoC:** `AuditLogBLoC`
```
Event: AuditLogsLoaded(filters)
States: AuditLogLoading → AuditLogLoaded(entries) / AuditLogFailure
```

**SQLite tables:** `cached_audit_logs`

---

#### Screen 9.5 — User Management (Admin)
**Complexity: M** | **Route:** `/settings/admin/users`

**Feel:** Admin directory. Status badge is the key signal.

**Layout:**
```
Scaffold
  ├── AppBar: "Users" · invite icon button
  └── ListView of UserManagementTile (AppCard, AppSpacing.sm gap)
        ├── Avatar (40×40 circle)
        ├── Name — titleMedium
        ├── Role chip + email — bodySmall, onSurfaceVariant
        └── StatusBadge: Active (successContainer) / Inactive (surfaceVariant)
        trailing overflow menu: Edit role · Reset password · Deactivate
```

**BLoC:** `UserManagementBLoC`

**SQLite tables:** None (admin reads from API only)

**Permission:** `PermissionGuard(scope: 'admin.users')`

---

#### Screen 9.6 — Role & Permission Editor (Admin)
**Complexity: L** | **Route:** `/settings/admin/roles`

**Feel:** Admin matrix. Dense but readable. Switches over checkboxes.

**Layout:**
```
Scaffold
  ├── AppBar: "Roles & Permissions" · Save TextButton (top-right)
  └── Body
        ├── RoleFilterChips — horizontal scroll (filter visible roles)
        └── PermissionMatrix (2D scroll: horizontal roles, vertical scopes)
              Header row: role names (surfaceVariant bg, titleMedium, fixed height)
              Left column: scope labels (fixed 140px width, bodyMedium)
              Each cell: Switch widget (compact)
                on: primary color · off: surfaceVariant
              Save → PATCH full matrix → invalidate + re-fetch SQLite user_permissions
```

**BLoC:** `RoleEditorBLoC`
```
Events: RolesLoaded, PermissionToggled(role, scope), RolesSaved
States: RoleEditorLoading → RoleEditorLoaded(matrix) → RoleEditorSaving
      → RoleEditorSuccess
```

**SQLite tables:** `user_permissions` (invalidated and re-fetched after save)

---

#### Screen 9.7 — API / Environment Config (Admin)
**Complexity: S** | **Route:** `/settings/admin/config`

**Feel:** Developer settings. Functional, no decoration.

**Layout:**
```
Scaffold
  ├── AppBar: "Environment Config"
  └── SingleChildScrollView, padding AppSpacing.md
        ├── EnvironmentCard (AppCard)
        │     3-option segmented button:
        │     Production (lock icon) · Staging (flask icon) · Custom (edit icon)
        ├── AppSpacing.md
        ├── ConnectionCard (AppCard, visible for Custom only)
        │     BaseUrlTextField · TenantIdTextField
        ├── AppSpacing.md
        ├── TestConnectionButton — OutlinedButton, full width
        │     idle: "Test Connection"
        │     success: success color + checkmark + "Connected"
        │     failure: error color + "Connection failed · check URL"
        └── SaveButton — FilledButton, full width
```

**BLoC:** `EnvConfigBLoC`
```
Events: ConfigLoaded, ConfigSaved(env, baseUrl, tenantId), ConnectionTested
States: ConfigLoading → ConfigLoaded / ConfigSaving / ConfigTestSuccess / ConfigTestFailure
```

**SQLite tables:** `cached_env_config` (baseUrl, tenantId, environment, updated_at)

---

#### Screen 9.8 — PIN Lock / Biometric Re-Auth
**Complexity: M** | **Route:** `/lock`

**Feel:** Secure gate. Minimal UI. Phone lock screen energy.

**Layout:**
```
Full screen, surface bg, centered column
  ├── App icon (48×48, top area)
  ├── User name — titleMedium, onSurfaceVariant
  ├── "Enter your PIN to continue" — bodyMedium
  ├── AppSpacing.xl
  ├── PinDotsRow (4–6 dots)
  │     each dot 14×14 circle: primary=filled, surfaceVariant=empty
  │     failure: dots shake (horizontal 300ms) + momentary error color then clear
  ├── AppSpacing.lg
  ├── PinPad — 3-column grid
  │     each button: 72×72, surfaceVariant bg, AppRadius.xl, headlineMedium
  │     0–9 · backspace icon · biometric icon (if available)
  ├── "X attempts remaining" — error color bodySmall (after 3rd fail)
  └── "Log out instead" — TextButton, error color, bodySmall
```

**BLoC:** `AppLockBLoC`
```
Events: PinSubmitted(pin), BiometricRequested, LogoutRequested
States: AppLocked → AppUnlocking → AppUnlocked / AppLockFailure(attemptsRemaining)
```

**SQLite tables:** `cached_user` (read biometric_on); PIN hash in `flutter_secure_storage`

**SQLite tables:** `cached_user` (read biometric_on); PIN hash in `flutter_secure_storage`

---

#### Screen 9.9 — My Profile Info
**Complexity: M** | **Route:** `/settings/profile`

**Feel:** Personal card. Own identity. Editable but protected — sensitive fields require re-auth.

**Layout:**
```
Scaffold
  ├── AppBar: "My Profile" · "Edit" TextButton (top-right)
  └── SingleChildScrollView
        ├── ProfileHeroCard (AppCard, primaryContainer bg)
        │     AvatarEditRow:
        │       avatar 80×80 circle (photo or initials)
        │       camera overlay icon (bottom-right, primaryContainer bg)
        │       tap → image picker (camera or gallery)
        │     name — headlineLarge
        │     role chip + department chip (row)
        ├── AppSpacing.md
        ├── SectionHeader "Contact"
        ├── ContactCard (AppCard)
        │     Each InfoRow: leading icon · label (bodySmall, onSurfaceVariant) · value (bodyMedium)
        │       email · phone · employee ID · hire date
        ├── AppSpacing.md
        ├── SectionHeader "Personal"
        ├── PersonalCard (AppCard)
        │     Each InfoRow: birthdate · address · emergency contact · emergency phone
        ├── AppSpacing.md
        ├── SectionHeader "Account Security"
        └── SecurityCard (AppCard)
              ChangePasswordRow → re-auth + change password flow
              ChangePinRow → /lock re-auth → PIN setup
              BiometricToggle — Switch (re-auth required to enable)
              LastLoginRow — "Last login: {date} from {device}"

Edit mode (activated by "Edit" AppBar button):
  All InfoRow values become InputFields
  AppBar shows "Cancel" (left) + "Save" FilledButton (right)
  Sensitive fields (email, phone) show ⚠ "Requires verification" below field
  Save → PATCH /me → update cached_user in SQLite
```

**BLoC:** `ProfileBLoC`
```
Events: ProfileLoaded, ProfileEditing, FieldChanged(field, value),
        AvatarChanged(file), ProfileSaved
States: ProfileLoading → ProfileLoaded(user) → ProfileEditing(draftUser)
      → ProfileSaving → ProfileSaved / ProfileFailure
```

**SQLite tables:** `cached_user` (all fields: name, email, phone, avatar_url, birthdate, address, emergency_contact, last_login_at)

**Notes:**
- Avatar upload: POST multipart/form-data to `/me/avatar`
- Email change triggers a verification link to the new address before taking effect

---

#### Screen 9.10 — My Roles & Permissions
**Complexity: M** | **Route:** `/settings/roles`

**Feel:** Read-only transparency. Users see exactly what they can and cannot do.

**Layout:**
```
Scaffold
  ├── AppBar: "My Roles & Permissions"
  └── SingleChildScrollView
        ├── RoleSummaryCard (AppCard, primaryContainer bg)
        │     "Your assigned roles:" — bodySmall, onSurfaceVariant
        │     RoleChipRow — horizontal scroll of RoleChips
        │       each chip: shield icon + role name (labelLarge, primaryContainer)
        │     "Last updated: {date}" — bodySmall, onSurfaceVariant
        ├── AppSpacing.md
        ├── SearchBar — "Search permissions..." (surfaceVariant fill)
        ├── AppSpacing.md
        ├── SectionHeader "Granted Permissions"
        ├── GrantedList (AppCard)
        │     Each PermissionRow:
        │       checkmark icon (success color) · scope label (titleMedium)
        │       module tag (labelSmall chip, right)
        │       bodySmall description below label
        ├── AppSpacing.md
        ├── SectionHeader "Not Granted"
        └── DeniedList (AppCard)
              Each PermissionRow:
                lock icon (onSurfaceVariant) · scope label (bodyMedium, onSurfaceVariant)
                module tag (labelSmall chip, surfaceVariant, right)
```

**Do:** Keep it read-only. Users cannot modify their own roles here — that goes through 9.6 (admin only).
**Don't:** Don't show raw scope strings like `finance.approve` — render as "Approve invoices (Finance)".

**BLoC:** `MyRolesBLoC`
```
Events: RolesLoaded, PermissionSearchChanged(query)
States: RolesLoading → RolesLoaded(roles, granted, denied) / RolesFailure
```

**SQLite tables:** `user_permissions` (read-only; scope, module, description, granted)

---

### Module 10 — Chat & Voice / Video

> Real-time internal communication built on WebSocket + SQLite for offline message persistence.
> Voice and video calls use WebRTC peer-to-peer via `flutter_webrtc`.
> Package dependencies: `flutter_webrtc`, `record`, `just_audio`, `image_picker`, `file_picker`.

---

**SQLite schema for Module 10:**

```sql
chat_conversations (
  id, name, avatar_url, is_group, is_muted,
  last_message_body, last_message_sender_id, last_message_at,
  unread_count, created_at, updated_at
)

chat_participants (
  conversation_id, employee_id, is_admin, joined_at, last_read_at
)

chat_messages (
  id, conversation_id, sender_id,
  body,                        -- null for voice/file messages
  type,                        -- text | voice | image | file | system
  reply_to_id,                 -- null if not a reply
  edited_body,                 -- null if never edited
  edited_at,                   -- null if never edited
  is_deleted,                  -- soft delete; body replaced with "Message deleted"
  file_url, file_name, file_size_bytes,
  voice_url, voice_duration_seconds,
  sent_at, delivered_at, read_at,
  reactions                    -- JSON: [{emoji, employee_ids[]}]
)

chat_call_log (
  id, conversation_id, caller_id, call_type,  -- voice | video
  started_at, answered_at, ended_at,
  duration_seconds, status                    -- missed | answered | rejected | no_answer
)
```

---

**Shared Chat components — define once, reuse everywhere:**

```
── OnlineStatusDot ──────────────────────────────────────────────────────
8×8 circle, bottom-right of avatar
  success=online · warning=away · surfaceVariant=offline
  AnimatedSwitcher crossfade on status change

── ChatBubble ───────────────────────────────────────────────────────────
Own messages:  right-aligned, primaryContainer bg, AppRadius.lg (top-left sharp)
Other messages: left-aligned, surfaceVariant bg,  AppRadius.lg (top-right sharp)
System messages: centered, no bg, bodySmall onSurfaceVariant italic

Content variants:
  TextBubble:  bodyLarge text, selectable
  VoiceBubble: play/pause icon + waveform bars (40px) + duration (bodySmall)
               playing: waveform animates, primary color progress
  ImageBubble: rounded image (AppRadius.md), tap → full-screen viewer
  FileBubble:  file icon circle + filename (bodyMedium) + size (bodySmall)
               download progress bar if not yet cached

Bubble footer (always, bottom-right of bubble):
  timestamp — bodySmall, onSurfaceVariant
  Read receipt (own messages only):
    single grey check  = sent
    double grey checks = delivered
    double primary checks = read (seen by all)
  EditedLabel — "(edited)" bodySmall, onSurfaceVariant (if edited)

DeletedBubble: italic "Message deleted" bodyMedium onSurfaceVariant
  no footer, no reactions, no reply affordance

ReactionRow (below bubble, AnimatedSwitcher):
  Each EmojiChip: emoji + count (labelSmall)
    own reaction: primaryContainer bg, primary border
    others: surfaceVariant bg
    tap: toggle own reaction · long-press: see who reacted (bottom sheet)

ReplyQuote (above bubble content, if reply_to_id set):
  left accent bar (3px, primary color) · sender name (labelLarge, primary)
  quoted body preview (bodySmall, onSurfaceVariant, 1 line max)
  tap: scroll to quoted message + highlight 400ms

── MessageContextMenu ───────────────────────────────────────────────────
Long-press on any non-deleted bubble → modal bottom sheet (240px):
  EmojiQuickBar: 6 common emoji + "+" button (opens full picker)
  Divider
  ReplyRow     — reply icon + "Reply"
  CopyRow      — copy icon + "Copy text" (text messages only)
  EditRow      — edit icon + "Edit" (own messages, text only, ≤15min old)
  DeleteRow    — delete icon + "Delete" (error color)
                   own messages: always available → soft delete
                   others' messages: admin only → soft delete
  PinRow       — pin icon + "Pin" (group admin only)
  ForwardRow   — forward icon + "Forward" (future scope, show as disabled)

── TypingIndicator ──────────────────────────────────────────────────────
3 animated dots (scale pulse, staggered 150ms each)
"Name is typing..." bodySmall onSurfaceVariant
"Name1, Name2 are typing..." for multiple
AnimatedSwitcher: slides in/out from bottom
```

---

#### Screen 10.1 — Chat Inbox (Conversation List)
**Complexity: M** | **Route:** `/chat`

**Feel:** The entry point. Familiar messaging-app pattern. Unread conversations demand attention with bold text and badges. Seen conversations recede quietly.

**Layout:**
```
Scaffold
  ├── AppBar: "Messages"
  │     trailing: compose icon → /chat/new
  ├── TabBar: All · Unread · Groups (sticky below AppBar)
  ├── SearchBar (surfaceVariant fill, AppRadius.md, search icon)
  │     active: shows SearchResultList across all conversations
  │     inactive: shows ConversationList per active tab
  └── Body
        LoadingShimmer (3 shimmer tiles) while InboxLoading
        EmptyState if InboxEmpty:
          chat-bubble illustration + "No conversations yet"
          "Start a chat" FilledButton → /chat/new
        ListView of ConversationTile (no card wrapper, Divider separator)
          Each ConversationTile:
            ├── Leading:
            │     Direct: avatar 52×52 circle (photo or initials)
            │               OnlineStatusDot bottom-right
            │     Group:   3-avatar cluster
            │               front: 40×40 · back two: 28×28, offset -8px
            ├── Title row:
            │     name — titleMedium (w600 if unread, w400 if read)
            │     timestamp — bodySmall, onSurfaceVariant (right)
            │     MutedIcon — bell-off 14×14, onSurfaceVariant (if muted)
            ├── Subtitle row:
            │     last message preview — bodySmall, onSurfaceVariant, 1 line
            │       "You: ..." prefix for own last message
            │       "📎 Photo" / "📎 File: filename" / "🎤 Voice message"
            │       "📞 Voice call · 5:23" / "📹 Video call · 5:23" (call logs)
            │       "✏ Name edited a message" (system)
            │     UnreadBadge — right (warningContainer bg, labelSmall, min 20×20)
            │       "99+" if count > 99
            └── Swipe actions:
                  swipe right: MuteToggle (bell icon, infoContainer)
                  swipe left: DeleteConversation (trash icon, errorContainer)
                                confirmation dialog before delete
```

**BLoC:** `ChatInboxBLoC`
```
Events: InboxLoaded, TabChanged(tab), SearchChanged(query),
        ConversationMuted(id), ConversationDeleted(id),
        NewMessageReceived(conversationId, message) [WebSocket push]
States: InboxLoading → InboxLoaded(all, unread, groups) / InboxEmpty / InboxFailure
```

**SQLite tables:** `chat_conversations`, `chat_participants`

**WebSocket:** Subscribes to `/ws/inbox` on mount for real-time conversation list updates (new messages, read receipts, typing from any conversation).

---

#### Screen 10.2 — Chat Conversation
**Complexity: L** | **Route:** `/chat/:conversationId`

**Feel:** The core experience. Real-time, fluid, expressive. Every interaction is instant — optimistic updates, no waiting.

**Layout:**
```
Scaffold
  ├── AppBar (custom):
  │     Leading: avatar 36×36 + OnlineStatusDot (direct) /
  │               group avatar cluster (group)
  │     Title column:
  │       name — titleMedium
  │       status row — bodySmall, onSurfaceVariant:
  │         direct: "Online" / "Away" / "Last seen {relative time}"
  │         group:  "X members · Y online"
  │     Trailing:
  │       VoiceCallButton (phone icon)
  │       VideoCallButton (video icon) [direct only]
  │       overflow menu → conversation info (10.5)
  │
  ├── PinnedMessageBanner (AnimatedSwitcher, surfaceVariant bg, AppSpacing.sm)
  │     pin icon · truncated pinned message (bodySmall)
  │     tap: scroll to pinned message · × to dismiss banner (not unpin)
  │     visible only when a message is pinned
  │
  └── Body (Column, fills remaining height)
        ├── MessageList (Expanded)
        │     reverse: true (newest at bottom, scroll starts at bottom)
        │     physics: BouncingScrollPhysics
        │     LoadingShimmer while ConversationLoading
        │     Lazy-load older messages on scroll to top (PagedListView)
        │
        │     Per group of messages from same sender (≤5 min apart):
        │       sender avatar 28×28 (left side, group only, first message only)
        │       sender name bodySmall (above first bubble, group + others only)
        │
        │     DateSeparator — centered chip, surfaceVariant bg, bodySmall
        │       "Today" / "Yesterday" / "Mon 12 May 2025"
        │
        │     ChatBubble (per message — see shared components above)
        │
        │     SystemMessage — centered italic bodySmall, onSurfaceVariant
        │       "Name joined" / "Name left" / "Name changed the group name"
        │       "📞 Voice call ended · 5:23" / "📞 Missed voice call"
        │       "📹 Video call ended · 12:04" / "📹 Missed video call"
        │
        │     TypingIndicator (bottom of list, AnimatedSwitcher)
        │
        │     ScrollToBottomFAB (bottom-right, 40×40)
        │       shown when scrolled up > 200px
        │       UnreadBadge on FAB if new messages while scrolled up
        │
        ├── ReplyPreviewBar (surfaceVariant bg, 52px, AnimatedSwitcher)
        │     left accent (3px, primary)
        │     "Replying to Name" — labelLarge, primary
        │     quoted body preview — bodySmall, onSurfaceVariant, 1 line
        │     × close button (right, removes reply context)
        │
        ├── EditPreviewBar (infoContainer bg, 52px, AnimatedSwitcher)
        │     pencil icon · "Editing message" — labelLarge
        │     × cancel edit (right)
        │     only visible when editing an existing message
        │
        └── InputRow (surface bg, top border 0.5px surfaceVariant)
              padding: AppSpacing.sm horizontal, AppSpacing.xs vertical
              ├── AttachButton (paperclip icon, 40×40)
              │     tap → AttachmentBottomSheet
              ├── MessageTextField (Expanded)
              │     surfaceVariant fill, AppRadius.full
              │     padding: 10px horizontal, 8px vertical
              │     minLines: 1, maxLines: 6 (auto-expands)
              │     "Message..." placeholder
              │     onChanged: emit TypingStarted (debounced 2s → TypingStopped)
              │     Edit mode: pre-filled with message body
              └── SendButton / VoiceButton (40×40, primary color)
                    text not empty → SendButton (send icon, FilledButton circle)
                    text empty     → VoiceButton (mic icon, OutlinedButton circle)
                                     hold-to-record (see VoiceRecordingOverlay)
                    edit mode      → SaveEditButton (check icon, success color)

── AttachmentBottomSheet (300px) ────────────────────────────────────────
drag handle
2×2 grid of AttachOption tiles (AppCard, 80×80):
  Camera      — camera icon (primary)    → image_picker (camera)
  Gallery     — image icon (info)        → image_picker (gallery, multiple)
  File        — file icon (warning)      → file_picker (any type)
  Location    — pin icon (error)         → show map + send coordinates
each tile: icon 36×36 circle + label bodySmall below

── VoiceRecordingOverlay (replaces InputRow while recording) ────────────
surface bg, same height as InputRow
├── CancelZone (left half): "< Slide to cancel" bodySmall onSurfaceVariant
│     sliding left past threshold cancels recording (no send)
├── Center:
│     MicIcon (32×32, error color, pulse scale animation)
│     WaveformBars (80px wide, real-time amplitude bars, primary color)
│     RecordingTimer — "0:04" bodyMedium (counts up)
└── ReleaseHint (right): "Release to send" bodySmall onSurfaceVariant
Haptic feedback on recording start.

── MessageContextMenu (bottom sheet, 260px) ─────────────────────────────
drag handle · "Message options" labelLarge, centered
EmojiQuickBar (horizontal, 52px height):
  6 fixed emoji: 👍 ❤️ 😂 😮 😢 🙏
  + button → EmojiPickerFullSheet (320px, grid, searchable)
  tap emoji: toggle reaction · already reacted: removes reaction
Divider
MenuItems (each: icon + label, 48px height):
  Reply      (reply icon)   — always shown
  Copy text  (copy icon)    — text messages only
  Edit       (edit icon)    — own text messages ≤15 min old
  Pin        (pin icon)     — group admin only
  Delete     (trash, error) — own: always · others: admin only
    own message delete → ConfirmDeleteSheet:
      "Delete for everyone?" / "Delete for me only" / "Cancel"

── SeenBySheet (bottom sheet, 280px) ────────────────────────────────────
Shown on tap of read checkmarks on own messages
"Seen by" headlineMedium
ListView of SeenRow:
  avatar 36×36 · name (titleMedium) · "Seen at {time}" (bodySmall, right)
```

**BLoC:** `ConversationBLoC`
```
Events:
  ConversationLoaded(id)
  OlderMessagesRequested                  -- pagination
  MessageSent(body, replyToId?)
  VoiceMessageSent(filePath, durationSec)
  ImageSent(filePath)
  FileSent(filePath, fileName, sizeBytes)
  MessageEdited(messageId, newBody)
  MessageDeleted(messageId, deleteForEveryone)
  ReactionToggled(messageId, emoji)
  ReplyStarted(messageId)
  ReplyCancelled
  EditStarted(messageId)
  EditCancelled
  MessagePinned(messageId)
  MessageUnpinned
  TypingStarted                           -- local user typing
  TypingStopped
  NewMessageReceived(message)             -- from WebSocket
  TypingIndicatorReceived(senderId, isTyping)  -- from WebSocket
  MessagesSeenByRemote(messageIds)        -- from WebSocket
  ScrolledToBottom

States:
  ConversationLoading
  ConversationLoaded(
    messages,       -- paginated list, newest first
    participants,
    pinnedMessage?,
    replyingTo?,    -- message being replied to
    editingMessage? -- message being edited
  )
  ConversationPaginating   -- loading older messages
  ConversationFailure
```

**SQLite tables:** `chat_messages` (full schema), `chat_conversations` (update last_message, unread_count), `chat_participants` (update last_read_at on seen)

**WebSocket:** Subscribes to `/ws/chat/:conversationId`. Handles: `message.new`, `message.edited`, `message.deleted`, `message.reaction`, `typing.start`, `typing.stop`, `message.seen`.

**Optimistic updates:** MessageSent immediately appends bubble with `pending` state (single grey clock icon). Server ACK upgrades to `sent`. Failure shows retry button on bubble.

---

#### Screen 10.3 — New Conversation / Group Chat
**Complexity: M** | **Route:** `/chat/new`

**Feel:** Contact picker. Lightweight and fast. Two taps to start a direct chat, five taps to create a named group.

**Layout:**
```
Scaffold
  ├── AppBar: "New Message"
  │     trailing: "Create" TextButton (disabled until ≥1 selected + group name filled)
  ├── TypeToggle (AppCard, segmented row)
  │     Direct · Group (switches UI mode)
  ├── GroupSetupSection (AnimatedSwitcher, Group mode only)
  │     GroupNameField (InputField, "Group name..." required)
  │     GroupAvatarRow:
  │       camera-circle (56×56, surfaceVariant) + "Add group photo" bodySmall
  │       tap → image_picker
  ├── SearchBar — "Search employees..."
  └── Body
        SelectedChipsRow (surfaceVariant bg, 48px, horizontal scroll)
          visible when ≥1 selected
          Each chip: avatar 20×20 + name + × remove
        Divider
        LoadingShimmer while loading
        ListView of SelectableMemberTile (AppSpacing.xs gap)
          ├── Avatar 44×44 + OnlineStatusDot
          ├── Name — titleMedium
          ├── Role + department — bodySmall, onSurfaceVariant
          └── Trailing: Checkbox (primary color when checked)
          selected: primaryContainer bg row tint
        EmptyState if search returns nothing: "No employees found"
  Bottom: CreateButton — FilledButton, full width, 52px
    Direct: "Start Chat" (enabled when exactly 1 selected)
    Group:  "Create Group" (enabled when ≥2 selected + name non-empty)
```

**BLoC:** `NewConversationBLoC`
```
Events: ModeChanged(type), SearchChanged(query), MemberToggled(employeeId),
        GroupNameChanged(name), GroupAvatarChanged(file), ConversationCreateRequested
States: NewConversationLoading → NewConversationReady(employees, selected, mode)
      → ConversationCreating → ConversationCreated(conversationId) / ConversationCreateFailure
```

**SQLite tables:** `cached_employees`, `chat_conversations` (insert), `chat_participants` (insert)

**Post-create:** Push to Chat Conversation (10.2). New group shows system message "Name created this group".

---

#### Screen 10.4 — Message Search
**Complexity: M** | **Route:** `/chat/:conversationId/search`

**Feel:** Archive lookup. Find that file someone sent two months ago without infinite scroll.

**Layout:**
```
Scaffold
  ├── AppBar (no title): SearchTextField (autofocus, full width, AppRadius.md)
  │     clear × button · back arrow
  └── Body
        EmptyState (initial): magnifier illustration + "Search messages"
        LoadingShimmer while searching
        EmptyState (no results): "No messages found for '{query}'"
        ListView of MessageSearchResultTile (AppCard, AppSpacing.sm gap)
          ├── SenderAvatar 40×40 + sender name (titleMedium)
          ├── Timestamp — bodySmall, onSurfaceVariant, right
          ├── MessagePreview — bodyMedium, 2 lines max
          │     matched term highlighted (primary color, w600)
          └── MediaPreview (if file/image): file icon + filename
          tap → navigate to Conversation (10.2) + scroll to + highlight message
```

**BLoC:** `MessageSearchBLoC`
```
Events: SearchChanged(query)
States: SearchInitial → SearchLoading → SearchResults(messages) / SearchEmpty / SearchFailure
```

**SQLite tables:** `chat_messages` (FTS5 full-text search on body column)

---

#### Screen 10.5 — Voice Call
**Complexity: L** | **Route:** `/chat/:conversationId/voice-call` (full-screen route, no back gesture)

**Feel:** Telephone. Familiar controls. Dark, focused. Nothing competes with the call.

**Incoming Call sheet** (shown over any screen when a call arrives):
```
Modal bottom sheet, 280px, dark bg (Color(0xFF1A1D23)), AppRadius.xl top
  CallerAvatar 64×64 + name headlineMedium (white) + "Incoming voice call" bodyMedium
  Row (equal width, 96px height):
    DeclineButton — 64×64 circle, error bg, phone-down icon (white)
    AcceptButton  — 64×64 circle, success bg, phone icon (white)
  Labels below: "Decline" / "Accept" (bodySmall, white 70%)
```

**In-Call screen layout:**
```
Full screen, gradient bg (Color(0xFF0F1117) → Color(0xFF1A2035))
  ├── SafeArea top
  │     CallTypeLabel — "Voice Call" bodySmall white 60%, centered
  │
  ├── Center section (flex 1, verticalCenter)
  │     CallerAvatar — 112×112 circle
  │       Calling state: pulse glow ring (primary 30%), scale 1.0→1.08→1.0, 1.2s loop
  │       Connected state: static, glow stops
  │     AppSpacing.lg
  │     CallerName — headlineLarge, white
  │     AppSpacing.sm
  │     CallStatusRow:
  │       Calling:   "Calling..." bodyMedium white 70% + pulsing dots
  │       Ringing:   "Ringing..." bodyMedium white 70%
  │       Connected: live timer "00:04:23" bodyMedium white 70%
  │       Ended:     "Call ended" bodyMedium white 70% + duration
  │
  ├── WaveformRow (visible in Connected state only, 48px height)
  │     Animated waveform bars (20 bars, primary color 40% opacity)
  │     bars animate to voice amplitude (from WebRTC audio stats)
  │
  └── ControlsGrid (bottom, padding-bottom: 56px)
        Row 1 — secondary controls (64×64 circles, surfaceVariant 30% bg):
          MuteButton   (mic-off icon)    active=error bg    label "Mute"/"Unmuted"
          SpeakerButton (volume icon)   active=primary bg   label "Speaker"/"Earpiece"
          KeypadButton  (keypad icon)   → DTMF keypad sheet label "Keypad"
        AppSpacing.xl
        Row 2 — primary control (centered):
          EndCallButton — 72×72 circle, error bg, phone-down icon (white)
          label "End" bodySmall white below
```

**BLoC:** `VoiceCallBLoC`
```
Events:
  CallInitiated(conversationId)         -- outgoing
  IncomingCallReceived(callId, callerId) -- push notification triggers this
  CallAnswered
  CallDeclined
  CallEnded
  MuteToggled
  SpeakerToggled
  CallTimerTick                         -- every second, emitted internally

States:
  CallIdle
  CallCalling(conversationId)           -- outgoing, waiting for answer
  CallRinging(callId, caller)           -- incoming, waiting for local action
  CallConnected(duration, isMuted, isSpeaker)
  CallEnded(duration, endedBy)
  CallFailure(reason)                   -- network error, permission denied
```

**WebRTC:** `flutter_webrtc`. Signalling over WebSocket `/ws/voice/:callId`. ICE: STUN `stun:stun.l.google.com:19302` + TURN from `EnvConfig.turnServers`.

**SQLite tables:** `chat_call_log` (insert on call start, update on end)

**Permissions:** `Permission.microphone` — request before `CallInitiated`. If denied: show error snackbar "Microphone permission required", do not initiate.

**Background:** Use `flutter_background_service` + FCM `high-priority` for incoming calls when app is backgrounded.

---

#### Screen 10.6 — Video Call
**Complexity: L** | **Route:** `/chat/:conversationId/video-call` (full-screen route)

**Feel:** FaceTime-style. Remote video fills the screen. Local preview is a small PiP. Controls auto-hide after 3s of inactivity.

**Incoming Video Call sheet** (same pattern as voice but with video camera icon and "Incoming video call" label):
```
Same structure as Voice incoming sheet (Screen 10.5)
DeclineButton + AcceptVideoButton (video-camera icon, success bg)
```

**In-Call screen layout:**
```
Full screen, black bg
  ├── RemoteVideoView (full screen)
  │     RTCVideoRenderer — fills entire screen, objectFit: cover
  │     Placeholder when remote video off:
  │       dark bg + CallerAvatar 96×96 + name headlineMedium white
  │
  ├── LocalVideoPreview (PiP, draggable)
  │     Initial position: top-right, margin AppSpacing.md
  │     Size: 120×160, AppRadius.lg, white border 1.5px
  │     RTCVideoRenderer — mirrored (front camera)
  │     tap: switch PiP position (4 corners)
  │     Placeholder when camera off: surfaceVariant bg + person icon
  │
  ├── TopBar (auto-hide after 3s, AnimatedOpacity)
  │     SafeArea top
  │     Row:
  │       CallTypeLabel "Video Call" bodySmall white 70% (left)
  │       CallTimer "00:12:45" bodySmall white 70% (right)
  │
  └── ControlsBar (bottom, auto-hide after 3s, AnimatedOpacity)
        gradient overlay: transparent → black 60%
        padding-bottom: 48px (safe area)
        Row of control buttons (64×64 circles):
          MuteButton     (mic-off)     active=error bg     "Mute"
          CameraButton   (camera-off)  active=surfaceVar    "Camera"
          FlipButton     (flip-camera) no active state      "Flip"
          SpeakerButton  (volume)      active=primary       "Speaker"
          EndCallButton  (phone-down)  always error bg 72×72 "End"
        tap anywhere on screen: show/re-hide controls (3s timer reset)
```

**BLoC:** `VideoCallBLoC`
```
Events:
  VideoCallInitiated(conversationId)
  IncomingVideoCallReceived(callId, callerId)
  CallAnswered
  CallDeclined
  CallEnded
  MuteToggled
  CameraToggled          -- on/off
  CameraFlipped          -- front/back
  SpeakerToggled
  ControlsVisibilityToggled
  RemoteVideoStateChanged(isEnabled)
  CallTimerTick

States:
  VideoCallIdle
  VideoCallCalling(conversationId)
  VideoCallRinging(callId, caller)
  VideoCallConnected(
    duration, isMuted, isCameraOn, isFrontCamera,
    isSpeaker, isRemoteVideoOn, controlsVisible
  )
  VideoCallEnded(duration)
  VideoCallFailure(reason)
```

**WebRTC:** Same as Voice (10.5) but with both audio + video tracks. `RTCVideoRenderer` for local + remote. Negotiate `video/H264` codec preference in SDP.

**SQLite tables:** `chat_call_log` (call_type = 'video')

**Permissions:** `Permission.microphone` + `Permission.camera` — request both before initiating. Handle partial grant (e.g. camera denied but mic granted) gracefully: start call with camera off, show warning snackbar.

---

#### Screen 10.7 — Chat Settings / Conversation Info
**Complexity: M** | **Route:** `/chat/:conversationId/info`

**Feel:** Full context for the conversation. Members, media, actions.

**Layout:**
```
Scaffold
  ├── AppBar: "Conversation Info"
  └── SingleChildScrollView
        ── Direct conversation ──────────────────────────────────────────
        ├── ProfileCard (AppCard, primaryContainer bg)
        │     avatar 72×72 + OnlineStatusDot
        │     name headlineMedium · role chip
        │     "Online" / "Last seen {time}" bodySmall onSurfaceVariant
        ├── AppSpacing.md
        ├── QuickActionsCard (AppCard)
        │     VoiceCallRow → Screen 10.5
        │     VideoCallRow → Screen 10.6
        │     SearchMessagesRow → Screen 10.4
        ── Group conversation ───────────────────────────────────────────
        ├── GroupHeaderCard (AppCard, primaryContainer bg)
        │     GroupAvatarWidget 80×80 (editable, admin only)
        │     group name headlineMedium
        │     "X members · Y online" bodySmall onSurfaceVariant
        │     edit-name pencil icon (admin only) → inline rename field
        ├── AppSpacing.md
        ├── QuickActionsCard (AppCard)
        │     SearchMessagesRow → Screen 10.4
        │     AddMembersRow → member picker sheet (admin only)
        ── Shared ───────────────────────────────────────────────────────
        ├── AppSpacing.md
        ├── MediaCard (AppCard)
        │     SectionHeader "Shared Media" · "See all" trailing
        │     3-column photo grid (preview first 6 images, 80×80 each, AppRadius.sm)
        │     tap → MediaGalleryViewer
        ├── AppSpacing.md
        ├── SettingsCard (AppCard)
        │     MuteRow: "Mute notifications" · Switch
        │     PinnedMessageRow → scroll to pinned message in conversation
        ├── AppSpacing.md
        ├── (Group only) MembersCard (AppCard)
        │     SectionHeader "Members ({count})" · "Add" TextButton (admin)
        │     ListView of MemberRow (non-scrolling, shrinkWrap):
        │       avatar 40×40 + OnlineStatusDot
        │       name titleMedium + role bodySmall
        │       AdminBadge "Admin" (labelSmall, primaryContainer, if admin)
        │       long-press (admin only) → MemberOptionsSheet:
        │         "Make admin" / "Remove admin" / "Remove from group"
        │     "+ X more" TextButton if >5 members → full members sheet
        ├── AppSpacing.md
        └── DangerCard (AppCard)
              (Group) LeaveGroupRow — "Leave Group" OutlinedButton, error, full width
              ClearHistoryRow — "Clear Chat History" TextButton, error
                → confirmation dialog: "This clears history on your device only"
```

**BLoC:** `ChatInfoBLoC`
```
Events: InfoLoaded(conversationId), GroupRenamed(name), GroupAvatarChanged(file),
        MuteToggled, MemberAdded(employeeId), MemberRemoved(employeeId),
        AdminGranted(employeeId), AdminRevoked(employeeId), GroupLeft, HistoryCleared
States: InfoLoading → InfoLoaded(conversation, participants, pinnedMessage) / InfoFailure
```

**SQLite tables:** `chat_conversations`, `chat_participants`, `chat_messages` (media query)

---

## 8. Screen Complexity Summary

| Module | S | M | L | Total |
|---|---|---|---|---|
| Module 0 — App Entry | 0 | 1 | 0 | 1 |
| Module 1 — Auth & Identity | 2 | 2 | 0 | 4 |
| Module 2 — Dashboard & Home | 0 | 2 | 1 | 3 |
| Module 9 — Settings & Admin | 3 | 6 | 1 | **10** |
| Module 10 — Chat & Voice/Video | 0 | 3 | 4 | **7** |
| **Total (as-built)** | **5** | **14** | **6** | **25** |

> Note: Modules 3–8 (Finance, Procurement, Inventory, Sales, HR, Projects)
> were removed — see the "Removed from the original plan" table at the top.
> Their screen specs are no longer in this doc.

### Effort guide
- **S — Simple (10 screens):** 1–2 days each. Single BLoC, 1–3 widgets, straightforward read/display.
- **M — Medium (40 screens):** 3–5 days each. Multiple widgets, form validation or list+detail, 1–2 BLoCs.
- **L — Large (22 screens):** Full sprint per screen. Custom painters, multi-BLoC, offline sync, WebRTC, real-time state machines.

---

## 9. Claude Code Prompt Template

Place this file as `DESIGN_GUIDE.md` in your repo root.

Use this prompt for every screen:

```
Build [Screen X.X — Name] for the ERP Mobile Flutter app.

Context file in this repo:
- DESIGN_GUIDE.md — complete reference: design tokens, component patterns,
  coding rules, per-screen layout + BLoC + SQLite spec for all 72 screens

Rules:
- Use AppTheme, AppLabel, AppSpacing, AppRadius — no hardcoded values
- Split into small private widget classes, one per visual section
- buildWhen on every BlocBuilder to minimise rebuilds
- AppCard for every content block
- StatusChip from the shared status color map
- EmptyState widget when list is empty
- LoadingShimmer while data loads (not CircularProgressIndicator alone on lists)
- PermissionGuard wraps any action requiring a specific scope
- BLoC pattern: use the Events/States specified in DESIGN_GUIDE.md §7
- SQLite: read from the tables listed in the screen spec; never query SQLite in build()
- Chat screens: subscribe/unsubscribe WebSocket in BLoC, not in widget lifecycle
- Chat optimistic updates: append message immediately, upgrade state on server ACK
- Voice/Video calls: request permissions before initiating; handle denial gracefully
- Video call: use RTCVideoRenderer for both local (mirrored) and remote streams
- Auto-hide controls (video call): use Timer(3s) + AnimatedOpacity, reset on tap
- Form screens: show discard confirmation dialog if user navigates back with unsaved changes

Screen complexity: [S / M / L]
```

### Quick reference — common mistakes to avoid

| Wrong | Right |
|---|---|
| `Color(0xFF3B4FE8)` hardcoded | `AppTheme.primary` |
| `TextStyle(fontSize: 16)` | `AppLabel.bodyLarge` |
| `SizedBox(height: 16)` | `SizedBox(height: AppSpacing.md)` |
| `BorderRadius.circular(16)` | `BorderRadius.circular(AppRadius.lg)` |
| `Container()` as content block | `AppCard()` |
| `CircularProgressIndicator()` on list | `LoadingShimmer()` |
| Empty `SizedBox()` when list empty | `EmptyState()` |
| Admin button without guard | `PermissionGuard(scope: '...') { button }` |
| Reading SQLite in `build()` | Read in BLoC from SQLite, expose via stream |
| `BlocBuilder` without `buildWhen` | Always add `buildWhen` |
| WebSocket in widget `initState` | Subscribe in BLoC; dispose in BLoC's `close()` |
| Waiting for server before showing sent message | Optimistic insert → upgrade on ACK |
| Starting call without checking permissions | `await Permission.microphone.request()` first |
| Navigating back without checking unsaved form | Use `WillPopScope` / `PopScope` + discard dialog |
