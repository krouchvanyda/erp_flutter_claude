# erp_mobile

Enterprise ERP Mobile — a Flutter app built on a lean, BLoC-centric stack.

> **Source of truth for the plan & architecture:** [`CLAUDE.md`](./CLAUDE.md)
> (project plan, guardrails) and [`ERP_MOBILE_DESIGN_GUIDE.md`](./ERP_MOBILE_DESIGN_GUIDE.md)
> (visual/UX spec). This README is the quick overview.

## Project Architecture — MVVM + BLoC

**Data flow:**

```
View (Flutter Widget)
   │  context.read<Bloc>().add(event)  /  BlocBuilder
   ▼
BLoC  (events → sealed states; acts as the ViewModel)
   │
   ▼
Repository  (concrete — business rules live here)
   │
   ▼
DataSource   Remote: dio (REST) / STOMP (WebSocket)
             Local:  shared_preferences DAOs
```

**Folder layout:**

```
lib/
├── core/                  # Shared infrastructure
│   ├── network/           # Dio client, interceptors, error handler
│   ├── realtime/          # STOMP/WebSocket channel + RealtimeMessage
│   ├── di/                # In-house service locator + manual registrations
│   │   ├── service_locator.dart    # GetIt-compatible locator (no package)
│   │   └── register_module.dart    # registerCoreDependencies(getIt)
│   ├── router/            # go_router config + guards
│   ├── push/              # FCM push + device registration
│   ├── error/             # Failure (sealed) + Either (dartz)
│   ├── shortcuts/ utils/ theme/
│
├── features/              # One folder per live module (flat MVVM)
│   └── [module]/
│       ├── data/          # datasources/ · models/ (json_serializable) · repositories/
│       ├── entities/      # hand-written immutable / Dart 3 sealed classes
│       └── presentation/  # bloc/ · pages/ · widgets/
│
└── shared/widgets/        # Reusable UI components
```

## Tech stack

| Layer | Choice |
|---|---|
| UI / state | Flutter + **flutter_bloc** (the only state/arch framework) |
| DI | **In-house service locator** (`core/di/service_locator.dart`) — no `get_it`/`injectable` |
| Models / state | **Hand-written** immutable classes + Dart 3 `sealed class` — no `freezed`/`equatable` |
| Networking | `dio` (REST) + `stomp_dart_client` (realtime) |
| Local storage | `shared_preferences` — **no** SQLite/drift, no offline sync engine |
| Secure storage | `flutter_secure_storage` (tokens only) |
| Calls / media | Stream Video (`stream_video_flutter`) + `erp_callkit` (Module 10) |
| Navigation | `go_router` · **JSON:** `json_serializable` |

### Removed from the original plan
`drift` + `sqlite3_flutter_libs`, the offline **sync engine**, `get_it` + `injectable`,
`freezed` + `freezed_annotation`, `equatable`, the LAN `tools/chat_relay` demo, and
**Modules 3–8** (Finance, Procurement, Inventory, Sales, HR, Projects). See the
"Removed from the original plan" table in [`CLAUDE.md`](./CLAUDE.md) for rationale.

## Live modules
0 — Core · 1 — Auth & Identity · 2 — Dashboard · 9 — Settings · 10 — Chat & Voice/Video
(plus `employees`, `notifications`, `search` support features).

## Conventions (see CLAUDE.md → Development Guardrails)
- BLoC events/states are immutable; unions are Dart 3 `sealed class` with `factory` redirects.
- Every value type gets explicit `==`/`hashCode`/`copyWith`; use `package:collection`
  equality for list/map fields so `BlocBuilder` dedupes correctly.
- Business rules live in the Repository; no `BuildContext` in BLoCs; no hardcoded strings (l10n).
- Resolve cross-cutting services from the in-house `getIt`; register in `register_module.dart`
  or the feature's `*_di.dart`.
- **Do not reintroduce** `drift`/`sqlite`, `get_it`/`injectable`, `freezed`, `equatable`, or the sync engine.

## Getting started
- Flutter `3.35.7` (Dart `^3.9.2`).
- `flutter pub get` → `flutter run` on a **real device** for call/push features
  (FCM push + the native incoming-call screen don't work on a simulator/emulator).
- Backend base URL lives in `lib/core/config/environments.dart`.
