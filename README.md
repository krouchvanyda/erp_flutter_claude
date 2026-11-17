branch feature/call -> 17-11-2026 -> get data from branch chat_conversation
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

## Flutter flavors

Three flavors — **dev**, **uat**, **prod** — each with its own entry point
(`lib/main_dev.dart`, `lib/main_uat.dart`, `lib/main_prod.dart`).

| Flavor | Backend (`environments.dart`) | App name | Network logs |
|---|---|---|---|
| `dev` | `localApiBaseUrl` | ERP Dev | on |
| `uat` | `stagingApiBaseUrl` | ERP UAT | on |
| `prod` | `prodApiBaseUrl` | ERP (Android) / Erp Mobile (iOS) | off |

- All flavors share **one app ID** (one Firebase / FCM / CallKit setup), so only one
  flavor is installed on a device at a time.
- Plain `flutter run` (no `--flavor`) = **dev** (`default-flavor` in `pubspec.yaml`).
- Code reads the flavor via `Flavor.current` (`lib/core/config/flavor.dart`) — also
  works in background isolates (push / native call Reject).
- Android: product flavors in `android/app/build.gradle.kts`. iOS: schemes `dev` / `uat`
  / `prod` with configurations `Debug-<flavor>`, `Release-<flavor>`, `Profile-<flavor>`.
- **prod release (Android) needs `android/key.properties`** (upload keystore; git-ignored).
  Without it the build stops with a clear error. dev / uat release builds use the debug key.

### Android

**Run debug**
```bash
flutter run --flavor dev -t lib/main_dev.dart
flutter run --flavor uat -t lib/main_uat.dart
flutter run --flavor prod -t lib/main_prod.dart
```

**Run release**
```bash
flutter run --release --flavor dev -t lib/main_dev.dart
flutter run --release --flavor uat -t lib/main_uat.dart
flutter run --release --flavor prod -t lib/main_prod.dart   # needs android/key.properties
```

**Build APK debug**
```bash
flutter build apk --debug --flavor dev -t lib/main_dev.dart
flutter build apk --debug --flavor uat -t lib/main_uat.dart
flutter build apk --debug --flavor prod -t lib/main_prod.dart
```

**Build APK release**
```bash
flutter build apk --release --flavor dev -t lib/main_dev.dart
flutter build apk --release --flavor uat -t lib/main_uat.dart
flutter build apk --release --flavor prod -t lib/main_prod.dart   # needs android/key.properties
```

**Build app bundle**
```bash
flutter build appbundle --release --flavor dev -t lib/main_dev.dart    # debug key: not for Play Store
flutter build appbundle --release --flavor uat -t lib/main_uat.dart    # debug key: not for Play Store
flutter build appbundle --release --flavor prod -t lib/main_prod.dart  # Play Store, needs android/key.properties
```

`android/key.properties` (never commit it):
```properties
storePassword=...
keyPassword=...
keyAlias=upload
storeFile=/absolute/path/to/upload-keystore.jks
```

### iOS

**Run debug**
```bash
flutter run --flavor dev -t lib/main_dev.dart
flutter run --flavor uat -t lib/main_uat.dart
flutter run --flavor prod -t lib/main_prod.dart
```

**Run release** — real iPhone only (the Simulator can't run release).
```bash
flutter run --release --flavor dev -t lib/main_dev.dart
flutter run --release --flavor uat -t lib/main_uat.dart
flutter run --release --flavor prod -t lib/main_prod.dart
```

**Archive** — run the Flutter build first, then in Xcode: Product → Archive with the
matching scheme (`dev` / `uat` / `prod`).
```bash
flutter build ios --release --flavor dev -t lib/main_dev.dart
flutter build ios --release --flavor uat -t lib/main_uat.dart
flutter build ios --release --flavor prod -t lib/main_prod.dart
```

**Build IPA**
```bash
flutter build ipa --release --flavor dev -t lib/main_dev.dart
flutter build ipa --release --flavor uat -t lib/main_uat.dart
flutter build ipa --release --flavor prod -t lib/main_prod.dart   # App Store
```
