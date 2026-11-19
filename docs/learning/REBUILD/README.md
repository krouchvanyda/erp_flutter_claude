# 🧱 Rebuild From Zero — START HERE

We deleted `lib/core`, `lib/features`, `lib/shared`, `lib/localization` and
`test/` on branch `feature/rebuild`, and we build the app again **step by step**.

The old, working app stays on branch `feature/call`. Use it as a reference:

```bash
git show feature/call:lib/core/config/flavor.dart
```

## 🎯 The goal: 4 features

```
lib/
├── core/            shared infrastructure (config, network, DI, router, theme…)
└── features/
    ├── auth/        login, splash auto-login, logout
    ├── profile/     view / edit my profile, avatar
    ├── chat/        inbox, conversation, groups (STOMP)
    └── call/        voice / video (Stream Video + CallKit)
```

## 🏛️ The big picture (where every step fits)

```
┌──────────────────────────── lib/features/ ─────────────────────────────┐
│                                                                        │
│   ┌────────┐    ┌──────────┐    ┌────────┐    ┌────────┐               │
│   │  auth  │    │ profile  │    │  chat  │    │  call  │   Steps 3–7   │
│   └───┬────┘    └────┬─────┘    └───┬────┘    └───┬────┘               │
│       │  each one:   View ─► BLoC ─► Repository ─► DataSource          │
└───────┼──────────────┼──────────────┼─────────────┼────────────────────┘
        │              │              │             │
        ▼              ▼              ▼             ▼
┌───────────────────────────── lib/core/ ────────────────────────────────┐
│  config/   theme/    di/     router/    network/    realtime/   push/  │
│  Step 1.1  1.2       1.3     1.4        Step 2      Step 5      Step 7 │
└────────────────────────────────────────────────────────────────────────┘
        ▲
        │ started by
┌───────┴────────────┐
│ main.dart          │  bootstrap(flavor) — the one start-up function
│ main_<flavor>.dart │
└────────────────────┘
```

**Rule:** `features/` may use `core/`, but `core/` never imports from
`features/`. Arrows only point **down**.

## 🗺️ Roadmap

```
 Step 0      Step 1 (setup)                      Step 2     Step 3   Step 4
 ┌─────┐   ┌────────┬───────┬──────┬────────┐   ┌───────┐   ┌──────┐ ┌─────────┐
 │clean│──►│ flavor │ theme │  DI  │ router │──►│network│──►│ auth │►│ profile │
 └─────┘   └────────┴───────┴──────┴────────┘   └───────┘   └──────┘ └────┬────┘
   ✅         ✅       ✅      ✅                                           │
                                                                          ▼
                       Step 8           Step 7              Step 6      Step 5
                    ┌──────────┐   ┌────────────────┐   ┌──────────┐ ┌──────┐
                    │ i18n +   │◄──│ call when app  │◄──│ call (in │◄│ chat │
                    │ tests    │   │ is killed (FCM)│   │   app)   │ └──────┘
                    └──────────┘   └────────────────┘   └──────────┘
```

Each step ends with an app that **runs**. Don't start the next step until the
current one works.

| Step | Topic | Lesson | Status |
|---|---|---|---|
| 0 | Clean slate | — | ✅ |
| 1.1 | Flavor (dev / uat / prod) | [01-flavor.md](01-flavor.md) | ✅ |
| 1.2 | Theme (design tokens) | [02-theme.md](02-theme.md) | ✅ |
| 1.3 | DI (service locator) | [03-di.md](03-di.md) | ✅ |
| 1.4 | Router (go_router) | 04-router.md | ⏳ |
| 2 | Network (dio, interceptors, errors) | — | ⏳ |
| 3 | Auth | — | ⏳ |
| 4 | Profile | — | ⏳ |
| 5 | Chat | — | ⏳ |
| 6 | Call (in app) | — | ⏳ |
| 7 | Call in background / killed app | see `../IOS_CALL`, `../ANDROID_CALL` | ⏳ |
| 8 | Translations, tests, polish | — | ⏳ |

## 📖 How each lesson is written

1. **Why**: what problem this step solves.
2. **Picture**: a small diagram.
3. **Code**: the files, explained line by line.
4. **🤔 Why like this?**: the other ways we could have written it, and why
   we didn't pick them.
5. **Try it**: commands to run and what you should see.
6. **Check yourself**: 2–3 questions.
