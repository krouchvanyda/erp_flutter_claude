# erp_mobile — Learning Rebuild

> 🧱 **Branch `feature/rebuild`**: rebuilding the app from zero, step by step,
> to learn. Started 2026-11-19 from `feature/call`, where the old working app
> still lives.

**Start here:** [`docs/learning/REBUILD/README.md`](docs/learning/REBUILD/README.md)
has the roadmap, progress and one lesson per step.
Project rules: [`CLAUDE.md`](./CLAUDE.md). Design spec:
[`ERP_MOBILE_DESIGN_GUIDE.md`](./ERP_MOBILE_DESIGN_GUIDE.md).

## The goal: 4 features

```
lib/
├── core/            config · theme · DI · router · network · realtime · push
└── features/
    ├── auth/        login, auto-login, logout
    ├── profile/     my profile, avatar
    ├── chat/        inbox, conversation, groups (STOMP)
    └── call/        voice / video (Stream Video + CallKit + push)
```

Architecture: **MVVM + BLoC**, flat.

```
View ─► BLoC ─► Repository ─► DataSource (dio / STOMP / shared_preferences)
```

Models are hand-written (no `freezed` / `equatable`). Every model writes its
own `==`, `hashCode`, `copyWith` and a safe `toString`, so two objects with
the same data count as equal. Why, and what breaks without them:
[`07-login.md`](docs/learning/REBUILD/07-login.md#-hashcode-tostring-line-by-line).

## Progress

| Step | Topic | Status |
|---|---|---|
| 0 | Clean slate | ✅ |
| 1.1 | Flavor (dev / uat / prod) | ✅ |
| 1.2 | Theme | ✅ |
| 1.3 | DI | ✅ |
| 1.4 | Navigation (ConfigRouter + AuthGate) | ✅ |
| 2.1 | Network: AppService (template style), envelope, NetworkErrorModel | ✅ |
| 2.2 | Network: tokens + auth interceptor | ✅ |
| 3.1 | Auth: login | ✅ |
| 3.2 | Auth: auto-login + logout | ⏳ |
| 4 | Profile | ⏳ |
| 5 – 7 | Chat, Call, Call when the app is killed | ⏳ |
| 8 | Translations, tests, polish | ⏳ |

The full table with lesson links is in
[`docs/learning/REBUILD/README.md`](docs/learning/REBUILD/README.md).

## Look at the old code

```bash
git show feature/call:lib/core/config/flavor.dart      # print one old file
git diff feature/call -- lib/core/config/               # compare old vs new
```

## Getting started

- Flutter stable, Dart `^3.9.2`.
- `flutter pub get`
- Use a **real device** for call and push features (they don't work on a
  simulator or emulator).
- Backend URLs: `lib/core/config/environments.dart`.
- Backend API: [`API_LIST_BACKEND.md`](./API_LIST_BACKEND.md). To try the
  server without the app, import the Postman collection and environment it
  names, then run **Auth → Login** (it saves the token for the other requests).

## Flavors

| Flavor | Backend | App name | Network logs |
|---|---|---|---|
| `dev` | `localApiBaseUrl` | ERP Dev | on |
| `uat` | `stagingApiBaseUrl` | ERP UAT | on |
| `prod` | `prodApiBaseUrl` | ERP | off |

- All flavors share **one app ID** (one Firebase / FCM / CallKit setup), so
  only one flavor is installed on a device at a time.
- A plain `flutter run` (no `--flavor`) uses **dev** (`default-flavor` in
  `pubspec.yaml`).
- Why it works this way: [`01-flavor.md`](docs/learning/REBUILD/01-flavor.md).

### Run

```bash
flutter run --flavor dev  -t lib/main_dev.dart
flutter run --flavor uat  -t lib/main_uat.dart
flutter run --flavor prod -t lib/main_prod.dart
# add --release for a release build (iOS: real iPhone only)
```

### Build

```bash
# Android
flutter build apk       --release --flavor <dev|uat|prod> -t lib/main_<flavor>.dart
flutter build appbundle --release --flavor prod -t lib/main_prod.dart  # Play Store

# iOS
flutter build ipa --release --flavor <dev|uat|prod> -t lib/main_<flavor>.dart
```

**prod release on Android needs `android/key.properties`** (the upload
keystore, git-ignored, never commit it). Without it the build stops with a
clear error. dev and uat release builds use the debug key.

```properties
storePassword=...
keyPassword=...
keyAlias=upload
storeFile=/absolute/path/to/upload-keystore.jks
```
