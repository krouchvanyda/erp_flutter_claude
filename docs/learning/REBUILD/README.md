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

```mermaid
flowchart TD
    M["▶ main.dart · main_dev / uat / prod<br/>bootstrap(flavor) — the one start-up function"]
    subgraph APP["lib/app/ — top layer, may import features"]
        A["App (MaterialApp) + AuthGate"]
    end
    subgraph FEAT["lib/features/ — Steps 3–7"]
        direction LR
        F1["auth"] ~~~ F2["profile"] ~~~ F3["chat"] ~~~ F4["call"]
    end
    subgraph CORE["lib/core/ — shared, never imports features"]
        direction LR
        C1["config<br/>1.1"] ~~~ C2["theme<br/>1.2"] ~~~ C3["di<br/>1.3"] ~~~ C4["router<br/>1.4"] ~~~ C5["network<br/>2"] ~~~ C6["realtime<br/>5"] ~~~ C7["push<br/>7"]
    end
    M --> APP
    APP -->|"imports"| FEAT
    FEAT -->|"imports"| CORE
    APP -->|"imports"| CORE
    class M none
    class A app
    class F1,F2,F3,F4 wait
    class C1,C2,C3,C4,C5,C6,C7 ok
    classDef app fill:#dbe9ff,stroke:#3b6fd8,color:#123
    classDef ok fill:#d9f7e6,stroke:#00a86b,color:#063
    classDef wait fill:#fff4d6,stroke:#d4a017,color:#5a4300
    classDef none fill:#eeeeee,stroke:#999,color:#555
    classDef err fill:#fde2e2,stroke:#d64545,color:#611
```

Inside **each** feature, the same 4 layers:

```mermaid
flowchart LR
    V["View<br/>(page)"] --> B["BLoC<br/>(ViewModel)"] --> R["Repository"] --> D["DataSource<br/>AppService · STOMP · storage"]
    class V,B,R,D app
    classDef app fill:#dbe9ff,stroke:#3b6fd8,color:#123
    classDef ok fill:#d9f7e6,stroke:#00a86b,color:#063
    classDef wait fill:#fff4d6,stroke:#d4a017,color:#5a4300
    classDef none fill:#eeeeee,stroke:#999,color:#555
    classDef err fill:#fde2e2,stroke:#d64545,color:#611
```

**Rule:** `features/` may use `core/`, but `core/` never imports from
`features/`. Arrows only point **down**.

## 🗺️ Roadmap

```mermaid
flowchart TD
    S0["0 · clean slate"] --> STEP1
    subgraph STEP1["Step 1 — setup"]
        direction LR
        S11["1.1 flavor"] --> S12["1.2 theme"] --> S13["1.3 DI"] --> S14["1.4 navigation"]
    end
    STEP1 --> STEP2
    subgraph STEP2["Step 2 — network"]
        direction LR
        S21["2.1 AppService"] --> S22["2.2 tokens +<br/>auth interceptor"]
    end
    STEP2 --> FEATS
    subgraph FEATS["Steps 3–6 — features"]
        direction LR
        S3["3 auth<br/>3.1 login ✅<br/>3.2 auto-login + logout ✅"] --> S4["4 profile<br/>4.1 view ✅<br/>4.2 avatar ✅"] --> S5["5 chat<br/>5.1 inbox ✅<br/>5.2 conversation ✅<br/>5.3 realtime ✅<br/>5.4 groups ✅<br/>5.5 attachments ✅<br/>5.6 typing · actions · presence · search ✅<br/>5.7 notifications ⏳"] --> S6["6 call (in app)<br/>6.1 signalling ✅<br/>6.2 voice + video ✅<br/>6.3a sounds ✅<br/>6.3b reconnecting ✅<br/>6.3c groups ✅<br/>6.3d call line ✅"]
    end
    FEATS --> S7["7 call when the app is killed<br/>(FCM / CallKit)"] --> S8["8 translations + tests + polish"]
    class S0,S11,S12,S13,S14,S21,S22 ok
    class S3,S4,S5,S6 ok
    class S7,S8 wait
    classDef app fill:#dbe9ff,stroke:#3b6fd8,color:#123
    classDef ok fill:#d9f7e6,stroke:#00a86b,color:#063
    classDef wait fill:#fff4d6,stroke:#d4a017,color:#5a4300
    classDef none fill:#eeeeee,stroke:#999,color:#555
    classDef err fill:#fde2e2,stroke:#d64545,color:#611
```

🟩 done · 🟨 to do

Each step ends with an app that **runs**. Don't start the next step until the
current one works.

| Step | Topic | Lesson | Status |
|---|---|---|---|
| 0 | Clean slate | — | ✅ |
| 1.1 | Flavor (dev / uat / prod) | [01-flavor.md](01-flavor.md) | ✅ |
| 1.2 | Theme (design tokens) | [02-theme.md](02-theme.md) | ✅ |
| 1.3 | DI (service locator) | [03-di.md](03-di.md) | ✅ |
| 1.4 | Navigation (ConfigRouter + AuthGate) | [04-router.md](04-router.md) | ✅ |
| 2.1 | Network: AppService (template style), envelope, NetworkErrorModel | [05-network.md](05-network.md) | ✅ |
| 2.2 | Network: tokens + auth interceptor (refresh) | [06-auth-interceptor.md](06-auth-interceptor.md) | ✅ |
| 3.1 | Auth: login (model · repository · ViewModel BLoC · form) | [07-login.md](07-login.md) | ✅ |
| 3.2 | Auth: splash auto-login + real logout | [08-auto-login-logout.md](08-auto-login-logout.md) | ✅ |
| 4.1 | Profile: view (`/users/me` + `/employees/me`), logout moves here | [09-profile-view.md](09-profile-view.md) | ✅ |
| 4.2 | Profile: avatar (camera / gallery / remove, multipart upload) | [10-profile-avatar.md](10-profile-avatar.md) | ✅ |
| 4.3 | Profile: edit name / phone (needs backend `PATCH /users/me`) | — | ⏸ |
| 5.1 | Chat: inbox (paged list, my id from the JWT, replaces the demo Home) | [11-chat-inbox.md](11-chat-inbox.md) | ✅ |
| 5.2 | Chat: conversation (paged history, optimistic send text, mark read) | [12-chat-conversation.md](12-chat-conversation.md) | ✅ |
| 5.3 | Chat: realtime (STOMP: live inbox + messages + ✓✓, reconnect, shared token refresh) | [13-chat-realtime.md](13-chat-realtime.md) | ✅ |
| 5.4 | Chat: new chat + groups (member picker, create, rename, add / remove, leave, delete) | [14-chat-groups.md](14-chat-groups.md) | ✅ |
| 5.5 | Chat: attachments (photo · PDF · voice: upload with progress, smart retry, player) | [15-chat-attachments.md](15-chat-attachments.md) | ✅ |
| 5.6 | Chat: typing (backend `TypingController` + app) | [16-chat-typing.md](16-chat-typing.md) | ✅ |
| 5.6 | Chat: message actions (edit / delete / reactions / seen by) · presence (online, last seen, beacons) · search | [17-chat-extras.md](17-chat-extras.md) | ✅ |
| 5.7 | Chat: notifications — a VISIBLE push to OFFLINE members (backend), tap → that chat opens (branch `feature/chat-notifications`) | [17b-chat-notifications.md](17b-chat-notifications.md) | ⏳ |
| 6.1 | Call: signalling (📞 / 🎥 → Calling… / Ringing… → Accept / Decline → in call → ended; busy, cancel, timeouts) — no sound yet | [18-call-signalling.md](18-call-signalling.md) | ✅ |
| 6.2 | Call: voice + video (Stream Video: token, join, mute, speaker, camera, video view) | [19-call-media.md](19-call-media.md) | ✅ |
| 6.3a | Call: sounds (silent "Calling…", ringback, ringtone, connected / ended beeps) | [20-call-sounds.md](20-call-sounds.md) | ✅ |
| 6.3b | Call: "Reconnecting…" (mine / theirs, give up after 30 s) | [21-call-reconnecting.md](21-call-reconnecting.md) | ✅ |
| 6.3c | Call: group calls (who is calling, faces row, video grid) | [22-call-groups.md](22-call-groups.md) | ✅ |
| 6.3d | Call: call line in the chat (backend `CALL` message + app) | [23-call-line.md](23-call-line.md) | ✅ |
| 7.1 | Push: Firebase + this phone's FCM token (`POST /me/devices`, `DELETE` on logout) | [24-push-setup.md](24-push-setup.md) | ✅ |
| 7.2 | Call: Android rings when minimized / killed (our FCM `call.invite` → full-screen notification, Decline in the background) | [25-android-ring.md](25-android-ring.md) | ✅ |
| 7.3 | Call: iOS rings when minimized / killed (Stream VoIP push + CallKit; Accept / Decline / End → our backend) | [26-ios-ring.md](26-ios-ring.md) · [handbook](26b-ios-ring-handbook.md) | ✅ |
| 7.4 | Call: Android "Answer" → straight into the call (`autoAnswer`; iOS already does it in 7.3) | [27-answer-from-ring.md](27-answer-from-ring.md) | ✅ |
| 7.5 | Call: switch a voice call to video (tap 🎥; the layout follows whoever has a camera on) | [28-voice-to-video.md](28-voice-to-video.md) | ✅ |
| 8 | Translations, tests, polish | — | ⏳ |

### 🔀 Track B: realtime over a plain WebSocket (branch `feature/raw-websocket`)

Replace STOMP with our own small JSON protocol on a plain WebSocket. Same
addresses and method names, so BLoCs and screens don't change. The STOMP door
`/ws` stays next to the new `/realtime` until the end.

📑 **All of Track B on one page, in build order (contents with links):**
[30b-raw-websocket-from-zero.md](30b-raw-websocket-from-zero.md): set it up
from zero, backend ↔ phone.

| Step | What you build | Lesson | Status |
|---|---|---|---|
| R1 | Backend: the phone book `RealtimeSessions` (line → user, line → addresses, private `/user/...` sends) | [30-raw-websocket-r1-sessions.md](30-raw-websocket-r1-sessions.md) | ✅ |
| R2 | Backend: the door `/realtime` (auth first, subscribe with membership check, ping/pong, 10 s / 25 s sweep) | [31-raw-websocket-r2-door.md](31-raw-websocket-r2-door.md) | ✅ |
| R3 | Backend: `ChatBroadcaster` sends through BOTH doors (+ `toPresence`) · typing over `send` → the same `TypingController` | [32-raw-websocket-r3-broadcast.md](32-raw-websocket-r3-broadcast.md) | ✅ |
| R4 | Backend: ONE rule `UserConnections` for both doors → presence (counts all connections) + `CallDisconnectHandler` | [33-raw-websocket-r4-connections.md](33-raw-websocket-r4-connections.md) | ✅ |
| R5 | App: `RealtimeConnection` + `ws_connection.dart` (`WsLine`: our letters, ping 10 s, 25 s watchdog) + `realtimeUrl` → `/realtime` | [34-raw-websocket-r5-app.md](34-raw-websocket-r5-app.md) | ✅ |
| R6 | Two phones: chat, typing, presence, ✓✓, calls ringing | — | ⏳ |

## 📖 How each lesson is written

1. **Why**: what problem this step solves.
2. **Picture**: a small diagram.
3. **Code**: the files, explained line by line.
4. **🤔 Why like this?**: the other ways we could have written it, and why
   we didn't pick them.
5. **Try it**: commands to run and what you should see.
6. **Check yourself**: 2–3 questions.
