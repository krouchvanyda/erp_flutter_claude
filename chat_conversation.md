# Chat Conversation — Sending Messages (text · image · file · location · voice)

Developer guide to the **send** side of Module 10's conversation screen: how a
message travels from a tap in the UI all the way to the backend and back, for
every message kind. Reflects the as-built code (not the aspirational design
guide).

> **TL;DR layering**
>
> ```
> ChatConversationPage  (UI: build the draft ChatMessage)
>        │  _msgRepo.send(draft, targetIds:)
>        ▼
> MessagesRepository    (optimistic insert → emit → swap temp id for real id)
>        │  _transport.sendMessage(stamped, targetIds:)
>        ▼
> ChatTransport         (map ChatMessageType → WireMessageType, self-echo guard)
>        │  _remote.sendMessage(convId, type:, body:, attachmentUrl:, …)
>        ▼
> ChatsRemoteDataSource (dio REST: POST /api/v1/chats/conversations/{id}/messages)
>        ▼
> Backend → fans the saved message back over STOMP /topic/conversations/{id}
> ```

Files referenced:

- UI — [lib/features/chat/views/chat_conversation_page.dart](lib/features/chat/views/chat_conversation_page.dart)
- Model — [lib/features/chat/models/chat_message.dart](lib/features/chat/models/chat_message.dart)
- Repo — [lib/features/chat/repositories/messages_repository.dart](lib/features/chat/repositories/messages_repository.dart)
- Transport — [lib/features/chat/repositories/chat_transport.dart](lib/features/chat/repositories/chat_transport.dart)
- REST — [lib/features/chat/repositories/chats_remote_data_source.dart](lib/features/chat/repositories/chats_remote_data_source.dart)
- Inbox tile sync — [lib/features/chat/repositories/conversations_repository.dart](lib/features/chat/repositories/conversations_repository.dart)

---

## 1. The data model

Every message — regardless of kind — is a single immutable
[`ChatMessage`](lib/features/chat/models/chat_message.dart). The `type` field
selects the bubble variant and which optional fields are populated:

```dart
enum ChatMessageType { text, voice, image, file, system }
```

| Field | Used by | Notes |
|---|---|---|
| `body` | text, system | The text. `null` for media. |
| `replyToId` / `replyToSenderName` / `replyToPreview` | any reply | Quoted message context. |
| `fileUrl` / `fileName` / `fileSizeBytes` | image, file | `fileUrl` carries the **hosted URL** after upload (see [§8](#8-attachments-image-voice-file)); only falls back to a local path if the upload fails. |
| `voiceUrl` / `voiceDurationSeconds` | voice | Audio clip + length in seconds. |
| `deliveredAt` / `readAt` / `readByUserIds` | receipts | Drive the bubble's tick state. |
| `editedAt` | edited text | Renders the `(edited)` label. |
| `isDeleted` | soft delete | Bubble shows "Message deleted". |

There is **no `location` type** — see [§6](#6-location-stub) for how to add it.

---

## 2. The universal send path

All kinds build a `ChatMessage` draft and hand it to **one** repository method:

```dart
// MessagesRepository.send — messages_repository.dart
Future<ChatMessage> send(
  ChatMessage draft, {
  List<String> targetIds = const <String>[],
});
```

What `send()` does, in order:

1. **Optimistic insert.** If `draft.id` is empty it stamps a temp id
   `msg-<senderId>-<microseconds>` and `deliveredAt: now`, adds it to the
   in-memory list, and `_emit()`s so the bubble appears **instantly** — before
   any network round-trip.
2. **POST.** `await _transport.sendMessage(stamped, targetIds: targetIds)`.
3. **ID swap.** When the backend returns the canonical numeric id, it finds the
   optimistic row by temp id and rewrites the id in place, then `_emit()`s
   again. The real id is what makes the later STOMP echo dedupe correctly.

### `targetIds` — who receives it

Computed in the page by `_resolveTargetIds()`
([chat_conversation_page.dart](lib/features/chat/views/chat_conversation_page.dart)):

- **Direct** conversation → `[the other person]`
- **Group** conversation → `[every member except me]`

This rides the `message.send` envelope so the relay only delivers to the
intended recipients (Slice 10.1.8 — fixes cross-user leakage). An empty list
means "legacy broadcast".

### Wire type mapping

`ChatTransport.sendMessage` maps the app enum to the wire enum
([chat_transport.dart:912](lib/features/chat/repositories/chat_transport.dart#L912)):

```
image → WireMessageType.image
voice → WireMessageType.voice
file  → WireMessageType.file
system→ WireMessageType.system
_     → WireMessageType.text     // text + anything unknown
```

### Self-echo guard

After a successful POST the transport remembers the returned id in
`_ourRecentSends` (30 s TTL). When the backend fans the same message back over
`/topic/conversations/{id}`, the inbound decoder drops it so you don't see your
own message twice.

### REST endpoint (the actual HTTP call)

`ChatsRemoteDataSource.sendMessage`
([chats_remote_data_source.dart:314](lib/features/chat/repositories/chats_remote_data_source.dart#L314)):

```
POST /api/v1/chats/conversations/{conversationId}/messages
```

```jsonc
{
  "type": "TEXT|IMAGE|VOICE|FILE",
  "body": "hello",            // TEXT only
  "attachmentUrl": "…",       // IMAGE / VOICE / FILE
  "attachmentContentType": "image/jpeg",
  "attachmentSizeBytes": 12345,
  "durationSeconds": 3,       // VOICE only
  "replyToMessageId": 42      // optional, any reply
}
```

The backend responds with the full saved message (canonical `id`, timestamps).

---

## 3. Text

**Status: ✅ implemented.** Handler: `_send()` in the conversation page.

```dart
// inside _send()
final draft = ChatMessage(
  id: '',
  conversationId: widget.conversationId,
  senderId: _currentUserId,
  senderName: _currentUserName,
  type: ChatMessageType.text,
  body: body,                       // _inputCtrl.text.trim()
  sentAt: DateTime.now(),
  // when replying:
  replyToId: replyingTo?.id,
  replyToSenderName: replyingTo?.senderName,
  replyToPreview: replyingTo?.body,
);
await _msgRepo.send(draft, targetIds: await _resolveTargetIds());
await _convRepo.updateLastMessage(widget.conversationId, body, /*senderId*/ me);
```

- **Reply:** long-press a bubble → **Reply** sets `_replyingToId`; `_send()`
  resolves the quote and fills the three `replyTo*` fields.
- **Edit:** long-press → **Edit** (own text, recent) pre-fills the input and
  sets `_editing`. On send, `_send()` calls `_msgRepo.edit(id, newBody)` →
  `PATCH /api/v1/chats/messages/{id}` with `{ "body": "…" }`. Sets `editedAt`.
- **Delete:** context menu → **Delete** → `_msgRepo.softDelete(id)` →
  `DELETE /api/v1/chats/messages/{id}`. Renders "Message deleted".
- **Inbox preview:** send the **raw** body to `updateLastMessage` — the inbox
  tile adds the `You: ` prefix itself (Slice 10.1.8 fixed the double prefix).

---

## 4. Image

**Status: ✅ implemented (camera + gallery), cross-device.** Handler:
`_sendPickedImage(source)`.

Opened from the **attachment sheet** (`_showAttachSheet`, the paperclip button):
a 2×2 grid — **Camera**, **Gallery**, File, Location.

The image is **uploaded first**, then the message is sent with the **hosted
URL** — so the recipient loads the same file (a local device path would be
invisible on their phone). See [§8](#8-attachments-image-voice-file).

```dart
final picked = await ImagePicker().pickImage(
  source: source,                 // ImageSource.camera | .gallery
  maxWidth: 1920, maxHeight: 1920, imageQuality: 88,
);
final file = File(picked.path);
if (!await file.exists()) return;

// 1) upload → hosted absolute URL (null on failure / demo mode)
final hostedUrl =
    await _msgRepo.uploadAttachment(picked.path, fileName: picked.name);

// 2) send with the hosted URL; fall back to the local path only if upload failed
await _msgRepo.send(
  ChatMessage(
    id: '',
    conversationId: widget.conversationId,
    senderId: _currentUserId,
    senderName: _currentUserName,
    type: ChatMessageType.image,
    fileUrl: hostedUrl ?? picked.path,   // http(s) URL on success
    fileName: picked.name,
    fileSizeBytes: await file.length(),
    sentAt: DateTime.now(),
  ),
  targetIds: await _resolveTargetIds(),
);
await _convRepo.updateLastMessage(widget.conversationId, '📷 Photo', me, type: 'image');
```

- On success `fileUrl` is an absolute `http(s)://…/uploads/chat/<uuid>.jpg`.
  The bubble + [ImageViewerPage](lib/features/chat/views/image_viewer_page.dart)
  render `Image.network` for `http(s)://`, `Image.file` for a local path, and a
  placeholder for `demo://` seeds (Slice 10.1.5).
- If the upload fails, it falls back to the **local path** (sender-only preview)
  and shows a snackbar — the send still goes through, but the peer won't see it.

---

## 5. Voice

**Status: ⚠️ demo stub.** Handler: `_showVoiceRecording()` shows the
hold-to-record sheet, but **Send** currently ships a hardcoded clip:

```dart
await _msgRepo.send(
  ChatMessage(
    …,
    type: ChatMessageType.voice,
    voiceUrl: 'demo://voice/new-clip.m4a',   // hardcoded
    voiceDurationSeconds: 3,                  // hardcoded
    sentAt: DateTime.now(),
  ),
  targetIds: await _resolveTargetIds(),
);
await _convRepo.updateLastMessage(
  widget.conversationId, '🎤 Voice message · 0:03', me, type: 'voice');
```

**To make it real** (packages are already in the project plan: `record`,
`just_audio`):

1. On press-and-hold start: `await AudioRecorder().start(path: tmpM4a)`.
2. On release: `final path = await recorder.stop();` and measure the elapsed
   duration.
3. Upload the file (see [§8](#8-attachments-image-voice-file)) → hosted `voiceUrl`.
4. Send with `voiceUrl: hostedUrl, voiceDurationSeconds: realSeconds`.
5. Slide-to-cancel past the threshold → discard, no send.

---

## 6. File

**Status: 🔲 stub.** The attachment sheet's **File** tile calls
`_attachStub('File picker')` (a snackbar). To implement:

```dart
final res = await FilePicker.platform.pickFiles();   // file_picker
final f = res?.files.single;
if (f == null) return;
final url = await _msgRepo.uploadAttachment(f.path!, fileName: f.name); // §8
await _msgRepo.send(
  ChatMessage(
    …,
    type: ChatMessageType.file,
    fileUrl: url ?? f.path!,
    fileName: f.name,
    fileSizeBytes: f.size,
    sentAt: DateTime.now(),
  ),
  targetIds: await _resolveTargetIds(),
);
await _convRepo.updateLastMessage(
  widget.conversationId, '📎 ${f.name}', me, type: 'file');
```

The repo/transport/REST layers already support `ChatMessageType.file` →
`WireMessageType.file` end-to-end — only the picker + upload are missing.

---

## 7. Location

**Status: 🔲 stub.** The **Location** tile calls `_attachStub('Map share')`.
There is no `location` message type today. Two ways to add it:

- **Simplest (no model change):** send a **text** message whose body is a maps
  link, e.g. `body: 'https://maps.google.com/?q=$lat,$lng'`. Works immediately;
  renders as a tappable text bubble.
- **Proper:** add `location` to `ChatMessageType`, carry `lat`/`lng` (reuse
  `body` as `"$lat,$lng"` or add fields), add a `WireMessageType.location`
  mapping, and render a static-map thumbnail bubble. Pick the coordinates with
  `google_maps_flutter` or the device's current position.

---

## 8. Attachments (image · voice · file)

Media is a **two-step** flow: **upload the bytes → send the message with the
returned hosted URL.** Sending a local device path instead would be meaningless
on the recipient's phone (the bug this fixed for images).

### Upload call — `MessagesRepository.uploadAttachment`

```dart
// returns an absolute http(s) URL, or null on failure / demo mode
final String? hostedUrl =
    await _msgRepo.uploadAttachment(localPath, fileName: name);
```

It delegates to `ChatsRemoteDataSource.uploadAttachment`
([chats_remote_data_source.dart](lib/features/chat/repositories/chats_remote_data_source.dart)),
which:

1. POSTs `multipart/form-data` (field `file`) to **`POST /api/v1/chats/attachments`**.
2. Gets back `{ url, contentType, sizeBytes }` where `url` is **server-relative**
   (`/uploads/chat/<uuid>.jpg`).
3. **Resolves it to absolute** against the dio base origin →
   `http://host:port/uploads/chat/<uuid>.jpg`, so `Image.network` works on every
   device and the peer (who receives this exact string over STOMP) can load it.

`/uploads/**` is public on the backend, so no auth header is needed to fetch the
file. Backend contract: see `CHAT_MESSAGES_BACKEND.md` §8.

### Wiring per kind

- **Image** — ✅ done (see [§4](#4-image)): upload → send `fileUrl = hostedUrl`.
- **Voice** — switch the [§5](#5-voice) stub to: record → `uploadAttachment(clipPath)`
  → send `voiceUrl = hostedUrl, voiceDurationSeconds: realSeconds`.
- **File** — in the [§6](#6-file) handler: `uploadAttachment(f.path)` → send
  `fileUrl = hostedUrl`.

The transport sends `attachmentUrl: message.fileUrl ?? message.voiceUrl`, so
setting either field to the hosted URL is all that's required end-to-end.

---

## 9. Receipts & inbound updates

- **Optimistic / delivered:** `send()` stamps `deliveredAt: now` on insert, so
  the bubble shows the sent/delivered tick immediately.
- **Read:** opening the conversation calls
  `ConversationsRepository.markRead(conversationId)` →
  `POST /api/v1/chats/conversations/{id}/read`. The backend fans a
  `message.read` event; `MessagesRepository.applyInbound` adds the reader to
  each message's `readByUserIds`, flipping the tick to blue `done_all` once all
  expected readers are present.
- **Inbound from peers:** `message.send` / `message.edit` / `message.delete` /
  `reaction.toggle` events arrive on `/topic/conversations/{id}`; the transport
  decodes them to typed events and the repository applies them (deduping the
  self-echo via `_ourRecentSends`).
- **Inbox tile:** every send also calls
  `ConversationsRepository.updateLastMessage(...)` with a per-type preview
  (`📷 Photo`, `📎 name.pdf`, `🎤 Voice message · 0:03`, or raw text) so the
  inbox row matches the conversation.

---

## 10. Quick reference

| Kind | Handler (page) | `type` | Key fields | Status |
|---|---|---|---|---|
| Text | `_send()` | `text` | `body` | ✅ |
| Reply | `_send()` | `text` | `body` + `replyTo*` | ✅ |
| Edit | `_send()` → `_msgRepo.edit()` | — | `editedAt`, new `body` | ✅ |
| Delete | menu → `_msgRepo.softDelete()` | — | `isDeleted` | ✅ |
| Image | `_sendPickedImage()` | `image` | `fileUrl`(hosted URL), `fileName`, `fileSizeBytes` | ✅ (upload → send) |
| Voice | `_showVoiceRecording()` | `voice` | `voiceUrl`, `voiceDurationSeconds` | ⚠️ demo stub |
| File | `_attachStub('File picker')` | `file` | `fileUrl`, `fileName`, `fileSizeBytes` | 🔲 stub |
| Location | `_attachStub('Map share')` | (none yet) | — | 🔲 stub |

**Endpoints:** send `POST …/conversations/{id}/messages` · edit
`PATCH …/messages/{id}` · delete `DELETE …/messages/{id}` · react
`POST …/messages/{id}/reactions` · read `POST …/conversations/{id}/read` ·
**upload `POST …/attachments`** (multipart, returns hosted URL)
(all under `/api/v1/chats`).
