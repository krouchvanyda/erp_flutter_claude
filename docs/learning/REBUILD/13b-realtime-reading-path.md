# Realtime (WebSocket + STOMP): a reading path

> Goes with: [13-chat-realtime.md](13-chat-realtime.md) · Roadmap: [README.md](README.md)

Read the stages **in order**. Each stage says what to read, what to look for,
and a ❓ question to answer before you move on.

Suggested pace: Stages 0–2 on day 1 · 3–5 on day 2 · 6–8 on day 3.

---

## Stage 0: the idea (no code)

**HTTP** = the phone asks, the server answers, done. The server can never
speak first.

```
phone ──GET /messages──► server
phone ◄────── 200 ────── server      (done, closed)
```

**WebSocket** = ONE connection that stays open. Both sides can send at any
time.

```
phone ══════════ one open pipe ══════════ server
       ◄── "new message!"  (server speaks first)
```

**STOMP** = small rules on top of a WebSocket: named frames and addresses
(destinations), like letters with an address. Spring speaks STOMP. You need
5 frames:

```
phone  ── CONNECT  (Authorization: Bearer <token>) ──►  server   "let me in"
phone  ◄─ CONNECTED ──────────────────────────────────  server   "you're in"
phone  ── SUBSCRIBE /user/queue/inbox ───────────────►  server   "send me this address"
phone  ◄─ MESSAGE  {"event":"message.send","payload":{…}}         (any time, many times)
both   ── \n (heartbeat every 10 s) ──────────────────            "I'm still alive"
```

❓ Why can't plain HTTP tell you about a new message?

---

## Stage 1: the server side

Backend repo: `erp_java_backend_claude/src/main/java/com/company/erp/features/chats/ws/`

| # | File | Look for |
|---|---|---|
| 1 | `WebSocketConfig.java` | The top comment lists every address. `addEndpoint("/ws")` = the URL. `enableSimpleBroker("/topic", "/queue")` = address prefixes. `HEARTBEAT_INTERVAL` = 10 s. |
| 2 | `StompAuthChannelInterceptor.java` | On CONNECT: reads `Authorization: Bearer …`, checks the token, remembers WHO you are (your user id) → that's why `/user/queue/inbox` reaches only you. |
| 3 | `ChatBroadcaster.java` | `toConversation` → `/topic/conversations/{id}` (everyone in the chat). `toUser` → `/user/queue/...` (one person). Every frame = `ChatEvent(event, payload)`. |
| 4 | `controller/MessageController.java` → `send()` | After saving: `broadcaster.toConversation(...)` AND `toUsers(..., "inbox", ...)`. That's where a live message is born. |

❓ `/topic/...` vs `/user/queue/...`: who receives each one?

---

## Stage 2: open one connection

[`lib/core/realtime/stomp_connection.dart`](../../../lib/core/realtime/stomp_connection.dart)

| Where | Look for |
|---|---|
| `StompConnection` | Only `subscribe` + `close`. Tiny on purpose, so tests can fake it. |
| `connectStomp()` | Builds the real `StompClient`. |
| `stompConnectHeaders` | The CONNECT frame with your token. |
| `onConnect` | CONNECTED arrived → the `Completer` finishes → "you're in". |
| `reconnectDelay: Duration.zero` | We switch OFF the package's own reconnect (why? Stage 3). |
| `onWebSocketError` / `onWebSocketDone` / `onDisconnect` | Before CONNECTED = "couldn't connect" (error). After = "lost it" (`onLost`). |

❓ What does the `Completer` turn into, and when does it finish?

---

## Stage 3: keep it alive (the heart)

[`lib/core/realtime/realtime_service.dart`](../../../lib/core/realtime/realtime_service.dart):
read in THIS order, not top to bottom.

1. `start()`: running = true → `_connect()`.
2. `_connect()`: the main path:
   ```
   status = connecting
   token  = await _accessToken()      ← a FRESH token every try
   conn   = await _connector(...)     ← Stage 2
   subscribe every remembered address ← _attach
   status = connected
   if it's a RE-connect → _reconnected.add(null)
   ```
3. `_onLost()` → `_scheduleRetry()`: wait, then `_connect` again.
4. `defaultBackoff`: 1, 2, 4, 8, 16, 30, 30 … seconds.
5. `subscribe()` + `_attach()`: a page asks for an address ONCE. The service
   remembers it and subscribes again after every reconnect. The last listener
   cancels → unsubscribe.
6. `stop()` and `reconnectNow()`.
7. Last: `_generation`. Each try gets a number, so a late answer from an old
   try is ignored.

❓ Why does every retry get a NEW token? (Hint: the package's own reconnect
re-sends the old CONNECT headers.)

❓ Messages sent while you were offline are lost. Which line lets the app fix
that? (→ Stage 6)

---

## Stage 4: the token problem

[`lib/core/network/token_refresher.dart`](../../../lib/core/network/token_refresher.dart)

- `validTokens()`: "a token good for 60 s more; refresh first if not". The
  socket calls it before every connect (see `lib/core/di/injection.dart`).
- `refresh()`: **single flight**. `_inFlight ??= …` = a second caller gets
  the SAME running refresh.

❓ The refresh token can be used only once. What would happen if the socket
and a REST call refreshed at the same moment?

---

## Stage 5: when to connect

1. [`lib/core/realtime/realtime_lifecycle.dart`](../../../lib/core/realtime/realtime_lifecycle.dart):
   login → `start()`, logout → `stop()`, app back in front → `reconnectNow()`,
   network back → `reconnectNow()`.
2. `lib/main.dart`: `getIt<RealtimeLifecycle>().attach()`, called once at start.
3. `lib/core/di/injection.dart`: `TokenRefresher`, `RealtimeService`,
   `RealtimeLifecycle` wired together.
4. `lib/core/network/api_endpoints.dart`: `websocketUrl` (from the flavor,
   `/ws`), `inboxQueue`, `conversationTopic(id)`.

❓ Why reconnect at once when the app is opened, instead of waiting for the
backoff?

---

## Stage 6: from text to meaning (the chat feature)

Follow ONE frame as it changes shape:

```
'{"event":"message.send","payload":{…}}'   raw text
   ▼ RealtimeEvent.tryParse        core/realtime/realtime_event.dart   (only the envelope)
RealtimeEvent(event, payload)
   ▼ ChatUpdate.fromRealtime        chat/model/chat_update.dart         (what it MEANS)
MessageArrived(MessageModel)
   ▼ ChatRepository._updates        chat/repository/chat_repository.dart
Stream<ChatUpdate>
   ▼ bloc constructor .listen → add(On…LiveUpdateEvent)
   ▼ _onLiveUpdate                   inbox_view_model_bloc · conversation_view_model_bloc
new state → the screen redraws
```

| File | Look for |
|---|---|
| `realtime_event.dart` → `tryParse` | Bad JSON → `null`, never a crash. |
| `chat_update.dart` → `fromRealtime` | `switch` from event name to a sealed class. Unknown → `null`. |
| `chat_repository.dart` | `inboxUpdates`, `conversationUpdates`, `reconnected`. |
| `inbox_view_model_bloc.dart` constructor | Stream → events. `reconnected` → reload (catch-up). |
| `inbox_view_model_bloc.dart` → `_onLiveUpdate` | Move to the top, unread +1, `GET` an unknown chat. |
| `conversation_view_model_bloc.dart` → `_onLiveUpdate` | New bubble; your own **echo** replaces 🕓; `message.read` → ✓✓. |

❓ Why does the BLoC turn the stream into EVENTS instead of calling `emit`
straight from `.listen`?

---

## Stage 7: trace one real message (on paper)

> A sends "Hi" to B. Write every step and file until B's inbox moves and A
> sees ✓✓.

Check yourself with the sequence diagram in
[13-chat-realtime.md](13-chat-realtime.md) §2 "A message, end to end".

---

## Stage 8: learn by doing

1. **Tests as examples.** `test/core/realtime/realtime_service_test.dart`
   uses a fake connection: `connections.first.onLost()` = a drop.
   ```bash
   flutter test test/core/realtime/realtime_service_test.dart
   ```
   Change the backoff and see what breaks.
2. **See the frames.** In `stomp_connection.dart`, add to `StompConfig` for a
   moment:
   ```dart
   onDebugMessage: (m) => debugPrint('STOMP $m'),
   ```
   Run the app and watch CONNECT / CONNECTED / SUBSCRIBE / MESSAGE. Remove
   it afterwards (it can print message text).
3. **Break it on purpose.** App open → stop the backend → after ~20 s (two
   missed heartbeats) "Connecting…". Start it again → reconnect + reload.
4. **Two phones.** Do "Try it" in [13-chat-realtime.md](13-chat-realtime.md) §5.

When you finish a stage, write down your answers to its ❓ questions.
